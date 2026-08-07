@isTest
private class CertificateServiceTest {

    private static Enrolment__c completedEnrolment() {
        Course__c course = TestDataFactory.createCourse('Salesforce Developer', 'Introductory', 500);
        Cohort__c cohort = TestDataFactory.createCohort(course.Id, 10, 14);
        Contact student  = TestDataFactory.createStudent('graduate@oxfordable.test');

        Enrolment__c enrolment = new Enrolment__c(
            Cohort__c  = cohort.Id,
            Student__c = student.Id,
            Status__c  = 'Completed'
        );
        insert enrolment;
        return enrolment;
    }

    @isTest
    static void issueAttachesPdfAndFlagsEnrolment() {
        Enrolment__c enrolment = completedEnrolment();

        Test.startTest();
        CertificateService.issue(new Set<Id>{ enrolment.Id });
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT ContentDocument.Title
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :enrolment.Id
        ];
        Assert.areEqual(1, links.size(), 'The certificate file should be linked to the enrolment');
        Assert.isTrue(links[0].ContentDocument.Title.startsWith('Certificate'));

        Assert.isTrue(
            [SELECT Certificate_Issued__c FROM Enrolment__c WHERE Id = :enrolment.Id]
                .Certificate_Issued__c,
            'The enrolment should be flagged once the file exists');
    }

    @isTest
    static void issueSkipsAlreadyCertifiedEnrolments() {
        Enrolment__c enrolment = completedEnrolment();
        enrolment.Certificate_Issued__c = true;
        update enrolment;

        Test.startTest();
        CertificateService.issue(new Set<Id>{ enrolment.Id });
        Test.stopTest();

        Assert.areEqual(0, [
            SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :enrolment.Id
        ], 'No second certificate for an enrolment already marked issued');
    }

    @isTest
    static void invocableAcceptsFlowRequests() {
        Enrolment__c enrolment = completedEnrolment();

        CertificateService.Request request = new CertificateService.Request();
        request.enrolmentId = enrolment.Id;

        Test.startTest();
        CertificateService.issueCertificates(new List<CertificateService.Request>{ request });
        Test.stopTest();

        Assert.areEqual(1, [
            SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :enrolment.Id
        ]);
    }
}
