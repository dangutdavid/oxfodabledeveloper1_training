@isTest
private class CohortServicesTest {

    @testSetup
    static void makeData() {
        Course__c course = TestDataFactory.createCourse(
            'Salesforce Developer Advanced', 'Advanced', 1500);
        TestDataFactory.createCohort(course.Id, 10, 30);
        TestDataFactory.createStudents(2);
    }

    @isTest
    static void testGetActiveCoursesAndOpenCohorts() {
        Test.startTest();
        List<Course__c> courses = CohortController.getActiveCourses();
        List<Cohort__c> cohorts = CohortController.getOpenCohorts(courses[0].Id);
        List<Cohort__c> all     = CohortController.getOpenCohorts(null);
        Test.stopTest();

        Assert.areEqual(1, courses.size(), 'One active course expected');
        Assert.areEqual(1, cohorts.size(), 'One open cohort expected for that course');
        Assert.isFalse(all.isEmpty(), 'Unfiltered query should also return cohorts');
    }

    @isTest
    static void testFindAvailableCohorts() {
        CohortAvailabilityService.Request req = new CohortAvailabilityService.Request();
        req.courseName = 'Advanced';

        Test.startTest();
        List<CohortAvailabilityService.Result> results =
            CohortAvailabilityService.findAvailableCohorts(
                new List<CohortAvailabilityService.Request>{ req });
        Test.stopTest();

        Assert.isTrue(results[0].seatsAvailable, 'Seats should be available');
        Assert.areEqual(1, results[0].cohorts.size(), 'One matching cohort expected');
        Assert.isTrue(results[0].answer.contains('Advanced'), 'Answer should name the course');
    }

    @isTest
    static void testFindAvailableCohortsNoMatch() {
        CohortAvailabilityService.Request req = new CohortAvailabilityService.Request();
        req.courseName = 'Nonexistent Course';

        Test.startTest();
        List<CohortAvailabilityService.Result> results =
            CohortAvailabilityService.findAvailableCohorts(
                new List<CohortAvailabilityService.Request>{ req });
        Test.stopTest();

        Assert.isFalse(results[0].seatsAvailable, 'No seats should be reported');
        Assert.isTrue(results[0].answer.contains('no cohorts'), 'Answer should say none were found');
    }

    @isTest
    static void testCreateEnrolmentAndDuplicateError() {
        Cohort__c cohort = [SELECT Id FROM Cohort__c LIMIT 1];
        Contact student  = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        Enrolment__c created = EnrolmentController.createEnrolment(cohort.Id, student.Id, 'Confirmed');

        Boolean secondAttemptFailed = false;
        try {
            EnrolmentController.createEnrolment(cohort.Id, student.Id, 'Confirmed');
        } catch (Exception e) {
            secondAttemptFailed = true;
        }
        Test.stopTest();

        Assert.isNotNull(created.Id, 'The enrolment should be created');
        Assert.isTrue(secondAttemptFailed, 'A duplicate enrolment should raise a handled exception');
    }

    @isTest
    static void testEnrolmentStatusService() {
        Cohort__c cohort = [SELECT Id FROM Cohort__c LIMIT 1];
        Contact student  = [SELECT Id, Email FROM Contact LIMIT 1];
        insert new Enrolment__c(Cohort__c = cohort.Id, Student__c = student.Id, Status__c = 'Confirmed');

        EnrolmentStatusService.Request found = new EnrolmentStatusService.Request();
        found.studentEmail = student.Email;

        EnrolmentStatusService.Request missing = new EnrolmentStatusService.Request();
        missing.studentEmail = 'nobody@oxfordable.test';

        Test.startTest();
        List<EnrolmentStatusService.Result> results = EnrolmentStatusService.checkStatus(
            new List<EnrolmentStatusService.Request>{ found, missing });
        Test.stopTest();

        Assert.isTrue(results[0].found,  'The known student should be found');
        Assert.isFalse(results[1].found, 'The unknown email should not be found');
    }
}
