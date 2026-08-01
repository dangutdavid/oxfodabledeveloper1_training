public with sharing class CohortController {

    @AuraEnabled(cacheable=true)
    public static List<Course__c> getActiveCourses() {
        return [
            SELECT Id, Name, Course_Level__c, Fee__c
            FROM Course__c
            WHERE Active__c = true
            WITH SECURITY_ENFORCED
            ORDER BY Name ASC
            LIMIT 200
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Cohort__c> getOpenCohorts(Id courseId) {
        String status = 'Open';
        List<Cohort__c> cohorts = (courseId == null)
            ? [SELECT Id, Name, Cohort_Label__c, Course__r.Name, Start_Date__c, Delivery_Mode__c,
                      Capacity__c, Enrolled_Count__c, Seats_Remaining__c, Status__c
               FROM Cohort__c
               WHERE Status__c = :status AND Start_Date__c >= TODAY
               WITH SECURITY_ENFORCED
               ORDER BY Start_Date__c ASC LIMIT 100]
            : [SELECT Id, Name, Cohort_Label__c, Course__r.Name, Start_Date__c, Delivery_Mode__c,
                      Capacity__c, Enrolled_Count__c, Seats_Remaining__c, Status__c
               FROM Cohort__c
               WHERE Status__c = :status AND Start_Date__c >= TODAY AND Course__c = :courseId
               WITH SECURITY_ENFORCED
               ORDER BY Start_Date__c ASC LIMIT 100];
        return cohorts;
    }
}
