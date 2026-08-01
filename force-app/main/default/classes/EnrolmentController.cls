public with sharing class EnrolmentController {

    @AuraEnabled
    public static Enrolment__c createEnrolment(Id cohortId, Id studentId, String status) {

        if (cohortId == null || studentId == null) {
            throw new AuraHandledException('Please choose both a cohort and a student.');
        }

        Enrolment__c enrolment = new Enrolment__c(
            Cohort__c  = cohortId,
            Student__c = studentId,
            Status__c  = String.isBlank(status) ? 'Confirmed' : status
        );

        try {
            insert enrolment;
        } catch (DmlException e) {
            // Surfaces the trigger message (capacity) or the unique-key message (duplicate)
            // as a readable sentence rather than a stack trace. See NFR-04.
            throw new AuraHandledException(friendlyMessage(e));
        }

        return [
            SELECT Id, Name, Status__c, Cohort__r.Cohort_Label__c, Student__r.Name
            FROM Enrolment__c
            WHERE Id = :enrolment.Id
            LIMIT 1
        ];
    }

    @TestVisible
    private static String friendlyMessage(DmlException e) {
        String raw = e.getDmlMessage(0);
        if (raw != null && raw.containsIgnoreCase('duplicate value found')) {
            return 'That student is already enrolled on this cohort.';
        }
        return String.isBlank(raw) ? e.getMessage() : raw;
    }
}
