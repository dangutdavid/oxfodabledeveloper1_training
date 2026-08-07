@isTest
private class InvoicePaymentServicesTest {

    private static final Decimal FEE = 500;

    private static Enrolment__c confirmEnrolment(String email) {
        Course__c course = TestDataFactory.createCourse('Salesforce Developer', 'Introductory', FEE);
        Cohort__c cohort = TestDataFactory.createCohort(course.Id, 10, 14);
        Contact student  = TestDataFactory.createStudent(email);

        Enrolment__c enrolment = new Enrolment__c(
            Cohort__c  = cohort.Id,
            Student__c = student.Id,
            Status__c  = 'Confirmed'
        );
        insert enrolment;
        return enrolment;
    }

    private static Invoice__c invoiceFor(Id enrolmentId) {
        return [
            SELECT Id, Name, Amount__c, Amount_In_Currency__c, Currency_Code__c,
                   Exchange_Rate__c, Status__c, Due_Date__c, Payment_Reference__c,
                   Enrolment__c
            FROM Invoice__c
            WHERE Enrolment__c = :enrolmentId
        ];
    }

    // ---------- Invoicing ----------

    @isTest
    static void confirmedEnrolmentGetsOneInvoice() {
        Enrolment__c enrolment = confirmEnrolment('billing@oxfordable.test');

        Invoice__c invoice = invoiceFor(enrolment.Id);
        Assert.areEqual(FEE, invoice.Amount__c, 'Invoice should carry the course fee');
        Assert.areEqual('Sent', invoice.Status__c);
        Assert.areEqual('GBP', invoice.Currency_Code__c);
        Assert.areEqual(1, invoice.Exchange_Rate__c);
        Assert.areEqual(Date.today().addDays(14), invoice.Due_Date__c);
    }

    @isTest
    static void unrelatedEditDoesNotDuplicateInvoice() {
        Enrolment__c enrolment = confirmEnrolment('billing@oxfordable.test');

        enrolment.Attendance_Percent__c = 50;
        update enrolment;

        Assert.areEqual(1, [SELECT COUNT() FROM Invoice__c WHERE Enrolment__c = :enrolment.Id],
            'Re-saving a confirmed enrolment must not raise a second invoice');
    }

    @isTest
    static void appliedEnrolmentGetsNoInvoice() {
        Course__c course = TestDataFactory.createCourse('Salesforce Developer', 'Introductory', FEE);
        Cohort__c cohort = TestDataFactory.createCohort(course.Id, 10, 14);
        Contact student  = TestDataFactory.createStudent('applied@oxfordable.test');

        insert new Enrolment__c(
            Cohort__c = cohort.Id, Student__c = student.Id, Status__c = 'Applied');

        Assert.areEqual(0, [SELECT COUNT() FROM Invoice__c],
            'Only Confirmed enrolments are invoiced');
    }

    // ---------- Payment via the stub gateway ----------

    @isTest
    static void payInvoiceMarksPaidAndUpdatesEnrolment() {
        Enrolment__c enrolment = confirmEnrolment('payer@oxfordable.test');
        Invoice__c invoice     = invoiceFor(enrolment.Id);

        Test.startTest();
        PaymentResult result = PaymentService.payInvoice(invoice.Id);
        Test.stopTest();

        Assert.isTrue(result.success);
        Assert.isTrue(result.transactionId.startsWith('STUB-'),
            'Default org config should route to the stub gateway');

        invoice = invoiceFor(enrolment.Id);
        Assert.areEqual('Paid', invoice.Status__c);
        Assert.areEqual(result.transactionId, invoice.Payment_Reference__c);

        Assert.areEqual(FEE,
            [SELECT Amount_Paid__c FROM Enrolment__c WHERE Id = :enrolment.Id].Amount_Paid__c,
            'The enrolment should now show the fee as paid, in GBP');
    }

    @isTest
    static void declinedCardLeavesInvoiceUnpaid() {
        // The stub treats any email containing "declined" as a failed card.
        Enrolment__c enrolment = confirmEnrolment('declined@oxfordable.test');
        Invoice__c invoice     = invoiceFor(enrolment.Id);

        PaymentResult result = PaymentService.payInvoice(invoice.Id);

        Assert.isFalse(result.success);
        Assert.areEqual('Sent', invoiceFor(enrolment.Id).Status__c);
        Assert.areEqual(0,
            [SELECT Amount_Paid__c FROM Enrolment__c WHERE Id = :enrolment.Id].Amount_Paid__c);
    }

    @isTest
    static void payingTwiceThrows() {
        Enrolment__c enrolment = confirmEnrolment('payer@oxfordable.test');
        Invoice__c invoice     = invoiceFor(enrolment.Id);
        PaymentService.payInvoice(invoice.Id);

        try {
            PaymentService.payInvoice(invoice.Id);
            Assert.fail('Expected PaymentStateException on double payment');
        } catch (PaymentService.PaymentStateException e) {
            Assert.isTrue(e.getMessage().contains('already paid'));
        }
    }

    // ---------- The real HTTP client, with a callout mock ----------

    private class GatewayCalloutMock implements HttpCalloutMock {
        Integer statusCode;
        String  body;
        GatewayCalloutMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body       = body;
        }
        public HttpResponse respond(HttpRequest req) {
            Assert.isTrue(req.getEndpoint().contains('callout:Payment_Gateway'),
                'The client must address the Named Credential, never a raw URL');
            Assert.isNotNull(req.getHeader('Idempotency-Key'));
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }

    private static PaymentRequest sampleRequest() {
        PaymentRequest request = new PaymentRequest();
        request.invoiceNumber  = 'INV-00001';
        request.amount         = 635.00;
        request.currencyCode   = 'USD';
        request.studentEmail   = 'payer@oxfordable.test';
        request.idempotencyKey = 'INV-00001-key';
        return request;
    }

    @isTest
    static void httpClientParsesSuccessResponse() {
        Test.setMock(HttpCalloutMock.class,
            new GatewayCalloutMock(201, '{"transactionId":"TX-12345"}'));

        Test.startTest();
        PaymentResult result = new PaymentGatewayHttpClient().charge(sampleRequest());
        Test.stopTest();

        Assert.isTrue(result.success);
        Assert.areEqual('TX-12345', result.transactionId);
    }

    @isTest
    static void httpClientReportsGatewayError() {
        Test.setMock(HttpCalloutMock.class,
            new GatewayCalloutMock(402, '{"error":"insufficient_funds"}'));

        Test.startTest();
        PaymentResult result = new PaymentGatewayHttpClient().charge(sampleRequest());
        Test.stopTest();

        Assert.isFalse(result.success);
        Assert.isTrue(result.errorMessage.contains('402'));
    }

    // ---------- Factory wiring ----------

    @isTest
    static void factoryReturnsConfiguredGateway() {
        Assert.isNotNull(PaymentGatewayFactory.getGateway(),
            'Factory must always resolve an implementation');
    }

    @isTest
    static void factoryHonoursTestOverride() {
        PaymentGatewayFactory.gatewayOverride = new PaymentGatewayStub();
        Assert.isTrue(PaymentGatewayFactory.getGateway() instanceof PaymentGatewayStub);
    }
}
