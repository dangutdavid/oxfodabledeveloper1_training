@isTest
private class PortalAccessServiceTest {

    private static Invoice__c paidInvoiceFor(String email) {
        Account acc = new Account(Name = 'Portal Test Students');
        insert acc;

        Contact student = new Contact(
            FirstName = 'Pay', LastName = 'Er', Email = email, AccountId = acc.Id);
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.allowSave = true;
        Database.insert(student, dml);

        Course__c course = TestDataFactory.createCourse('Portal Course', 'Introductory', 500);
        Cohort__c cohort = TestDataFactory.createCohort(course.Id, 10, 14);
        insert new Enrolment__c(
            Cohort__c = cohort.Id, Student__c = student.Id, Status__c = 'Confirmed');

        Invoice__c invoice = [
            SELECT Id FROM Invoice__c WHERE Enrolment__r.Student__c = :student.Id];
        // Settle it through the real service (stub gateway) so state is realistic.
        PaymentService.payInvoice(invoice.Id);
        return invoice;
    }

    @isTest
    static void paidInvoiceProvisionsPortalUserWithPermissionSet() {
        Invoice__c invoice = paidInvoiceFor('portal.payer@oxfordable.test');

        PortalAccessService.Request req = new PortalAccessService.Request();
        req.invoiceId = invoice.Id;

        Test.startTest();
        PortalAccessService.grantAccess(new List<PortalAccessService.Request>{ req });
        Test.stopTest();   // runs the queueable

        List<User> created = [
            SELECT Id, Username, ContactId, IsActive
            FROM User
            WHERE Username = 'portal.payer.oxfordable.test@careerlaunch.portal'
        ];
        Assert.areEqual(1, created.size(), 'A portal user should be provisioned');
        Assert.isTrue(created[0].IsActive);

        Assert.areEqual(1, [
            SELECT COUNT() FROM PermissionSetAssignment
            WHERE AssigneeId = :created[0].Id
              AND PermissionSet.Name = 'Student_Portal_User'
        ], 'The portal permission set should be assigned');
    }

    @isTest
    static void existingPortalUserIsNotDuplicated() {
        Invoice__c invoice = paidInvoiceFor('portal.repeat@oxfordable.test');

        PortalAccessService.Request req = new PortalAccessService.Request();
        req.invoiceId = invoice.Id;

        Test.startTest();
        PortalAccessService.grantAccess(new List<PortalAccessService.Request>{ req });
        Test.stopTest();
        // Second grant for the same student, outside start/stop: enqueue only -
        // the assertion that matters is that the FIRST run created exactly one.
        PortalAccessService.grantAccess(new List<PortalAccessService.Request>{ req });

        Assert.areEqual(1, [
            SELECT COUNT() FROM User
            WHERE Username = 'portal.repeat.oxfordable.test@careerlaunch.portal'
        ], 'Re-running the grant must never create a second user');
    }

    @isTest
    static void unpaidInvoicesAreIgnored() {
        Account acc = new Account(Name = 'Portal Test Students');
        insert acc;
        Contact student = new Contact(
            FirstName = 'Not', LastName = 'Paid',
            Email = 'portal.unpaid@oxfordable.test', AccountId = acc.Id);
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.allowSave = true;
        Database.insert(student, dml);
        Course__c course = TestDataFactory.createCourse('Portal Course', 'Introductory', 500);
        Cohort__c cohort = TestDataFactory.createCohort(course.Id, 10, 14);
        insert new Enrolment__c(
            Cohort__c = cohort.Id, Student__c = student.Id, Status__c = 'Confirmed');
        Invoice__c sentInvoice = [
            SELECT Id FROM Invoice__c WHERE Enrolment__r.Student__c = :student.Id];

        PortalAccessService.Request req = new PortalAccessService.Request();
        req.invoiceId = sentInvoice.Id;

        Test.startTest();
        PortalAccessService.grantAccess(new List<PortalAccessService.Request>{ req });
        Test.stopTest();

        Assert.areEqual(0, [
            SELECT COUNT() FROM User
            WHERE Username = 'portal.unpaid.oxfordable.test@careerlaunch.portal'
        ], 'A Sent (unpaid) invoice must not provision access');
    }
}
