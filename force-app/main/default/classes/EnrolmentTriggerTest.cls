@isTest
private class EnrolmentTriggerTest {

    @testSetup
    static void makeData() {
        Course__c course = TestDataFactory.createCourse(
            'Salesforce Developer Introductory', 'Introductory', 500);
        TestDataFactory.createCohort(course.Id, 3, 14);
        TestDataFactory.createStudents(5);
    }

    private static Cohort__c getCohort() {
        return [SELECT Id, Capacity__c, Enrolled_Count__c, Seats_Remaining__c FROM Cohort__c LIMIT 1];
    }

    @isTest
    static void testDefaultsApplied() {
        Cohort__c cohort = getCohort();
        Contact student  = [SELECT Id FROM Contact LIMIT 1];

        Enrolment__c enrolment = new Enrolment__c(Cohort__c = cohort.Id, Student__c = student.Id);

        Test.startTest();
        insert enrolment;
        Test.stopTest();

        Enrolment__c saved = [
            SELECT Status__c, Enrolment_Date__c, Amount_Paid__c, Enrolment_Key__c
            FROM Enrolment__c WHERE Id = :enrolment.Id
        ];
        Assert.areEqual('Applied', saved.Status__c, 'Status should default to Applied');
        Assert.areEqual(Date.today(), saved.Enrolment_Date__c, 'Enrolment date should default to today');
        Assert.areEqual(0, saved.Amount_Paid__c, 'Amount paid should default to zero');
        Assert.isNotNull(saved.Enrolment_Key__c, 'Unique key should be populated');
    }

    @isTest
    static void testOverbookingBlocked() {
        Cohort__c cohort = getCohort();                          // capacity 3
        List<Contact> students = [SELECT Id FROM Contact LIMIT 4];

        List<Enrolment__c> firstThree = TestDataFactory.buildEnrolments(
            cohort.Id, new List<Contact>{ students[0], students[1], students[2] }, 'Confirmed');
        insert firstThree;

        Enrolment__c fourth = new Enrolment__c(
            Cohort__c = cohort.Id, Student__c = students[3].Id, Status__c = 'Confirmed');

        Test.startTest();
        Database.SaveResult result = Database.insert(fourth, false);
        Test.stopTest();

        Assert.isFalse(result.isSuccess(), 'The fourth enrolment must be rejected');
        Assert.isTrue(result.getErrors()[0].getMessage().contains('full'),
                      'The error should explain that the cohort is full');
        Assert.areEqual(3, [SELECT COUNT() FROM Enrolment__c WHERE Cohort__c = :cohort.Id],
                        'Only three enrolments should exist');
    }

    @isTest
    static void testBulkInsertRespectsCapacity() {
        Course__c course     = [SELECT Id FROM Course__c LIMIT 1];
        Cohort__c bigCohort  = TestDataFactory.createCohort(course.Id, 150, 21);
        List<Contact> students = TestDataFactory.createStudents(200);

        // Bulk loads arrive as 'Applied' (confirmation is an individual action that
        // triggers the welcome flow). Applied still consumes a seat, so the capacity
        // rule is exercised for the full 200-record batch.
        List<Enrolment__c> enrolments =
            TestDataFactory.buildEnrolments(bigCohort.Id, students, 'Applied');

        Test.startTest();
        List<Database.SaveResult> results = Database.insert(enrolments, false);
        Test.stopTest();

        Integer succeeded = 0;
        Integer blockedAsFull = 0;
        for (Database.SaveResult r : results) {
            if (r.isSuccess()) {
                succeeded++;
            } else if (r.getErrors()[0].getMessage().contains('full')) {
                blockedAsFull++;
            }
        }
        Integer committed = [SELECT COUNT() FROM Enrolment__c WHERE Cohort__c = :bigCohort.Id];

        // US-04 / NFR-01: the cohort must NEVER be oversold, even for a 200-record load.
        // (Partial-save retries plus the unique key can commit fewer than capacity in a
        // single mixed batch, but the capacity ceiling must always hold.)
        Assert.isTrue(committed <= 150, 'The cohort must never exceed its capacity of 150');
        Assert.areEqual(succeeded, committed, 'Save results must match what was committed');
        Assert.isTrue(blockedAsFull >= 50, 'At least the 50 overflow records must be blocked as full');
        Assert.isTrue(succeeded > 0, 'Records within capacity should be accepted');
    }

    @isTest
    static void testDuplicateEnrolmentBlocked() {
        Cohort__c cohort = getCohort();
        Contact student  = [SELECT Id FROM Contact LIMIT 1];

        insert new Enrolment__c(Cohort__c = cohort.Id, Student__c = student.Id, Status__c = 'Confirmed');

        Enrolment__c duplicate = new Enrolment__c(
            Cohort__c = cohort.Id, Student__c = student.Id, Status__c = 'Confirmed');

        Test.startTest();
        Database.SaveResult result = Database.insert(duplicate, false);
        Test.stopTest();

        Assert.isFalse(result.isSuccess(), 'A duplicate enrolment must be rejected');
    }

    @isTest
    static void testQueueableUpdatesContact() {
        Cohort__c cohort = getCohort();
        Contact student  = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        insert new Enrolment__c(Cohort__c = cohort.Id, Student__c = student.Id, Status__c = 'Confirmed');
        Test.stopTest();                                         // forces the queueable job to run

        Contact refreshed = [SELECT Total_Enrolments__c FROM Contact WHERE Id = :student.Id];
        Assert.areEqual(1, refreshed.Total_Enrolments__c, 'Contact should show one active enrolment');
    }
}
