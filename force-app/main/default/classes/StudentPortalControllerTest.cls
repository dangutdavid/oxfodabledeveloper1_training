@isTest
private class StudentPortalControllerTest {

    private static Contact setUpStudentWithConfirmedEnrolment(String email) {
        Course__c course = TestDataFactory.createCourse('Salesforce Developer', 'Introductory', 500);
        Cohort__c cohort = TestDataFactory.createCohort(course.Id, 10, 14);
        Contact student  = TestDataFactory.createStudent(email);

        insert new Enrolment__c(
            Cohort__c  = cohort.Id,
            Student__c = student.Id,
            Status__c  = 'Confirmed'
        );
        return student;
    }

    @isTest
    static void studentSeesOnlyTheirOwnEnrolments() {
        Contact mine  = setUpStudentWithConfirmedEnrolment('me@oxfordable.test');
        setUpStudentWithConfirmedEnrolment('someone.else@oxfordable.test');

        StudentPortalController.contactIdOverride = mine.Id;
        List<StudentPortalController.EnrolmentView> views =
            StudentPortalController.getMyEnrolments();

        Assert.areEqual(1, views.size(), 'Only the logged-in student\'s enrolments');
        Assert.areEqual('Salesforce Developer', views[0].courseName);
        Assert.areEqual('Confirmed', views[0].status);
    }

    @isTest
    static void invoicesRenderWithCurrencyDisplay() {
        Contact mine = setUpStudentWithConfirmedEnrolment('me@oxfordable.test');

        StudentPortalController.contactIdOverride = mine.Id;
        List<StudentPortalController.InvoiceView> views =
            StudentPortalController.getMyInvoices();

        Assert.areEqual(1, views.size());
        Assert.isTrue(views[0].payable, 'A Sent invoice is payable');
        Assert.isTrue(views[0].amountDisplay.contains('GBP'),
            'Display amount should carry the currency: ' + views[0].amountDisplay);
    }

    @isTest
    static void payInvoiceSucceedsForOwnInvoice() {
        Contact mine = setUpStudentWithConfirmedEnrolment('me@oxfordable.test');
        Invoice__c invoice = [
            SELECT Id FROM Invoice__c WHERE Enrolment__r.Student__c = :mine.Id
        ];

        StudentPortalController.contactIdOverride = mine.Id;
        Test.startTest();
        PaymentResult result = StudentPortalController.payInvoice(invoice.Id);
        Test.stopTest();

        Assert.isTrue(result.success);
        Assert.areEqual('Paid',
            [SELECT Status__c FROM Invoice__c WHERE Id = :invoice.Id].Status__c);
    }

    @isTest
    static void payInvoiceRejectsSomeoneElsesInvoice() {
        Contact mine  = setUpStudentWithConfirmedEnrolment('me@oxfordable.test');
        Contact other = setUpStudentWithConfirmedEnrolment('someone.else@oxfordable.test');
        Invoice__c othersInvoice = [
            SELECT Id FROM Invoice__c WHERE Enrolment__r.Student__c = :other.Id
        ];

        StudentPortalController.contactIdOverride = mine.Id;
        try {
            StudentPortalController.payInvoice(othersInvoice.Id);
            Assert.fail('Expected AuraHandledException for another student\'s invoice');
        } catch (AuraHandledException e) {
            // The ownership gate must hold even with a valid record id.
        }

        Assert.areEqual('Sent',
            [SELECT Status__c FROM Invoice__c WHERE Id = :othersInvoice.Id].Status__c,
            'The other student\'s invoice must be untouched');
    }
}
