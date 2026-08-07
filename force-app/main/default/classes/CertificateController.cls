/**
 * Controller for the CertificatePdf Visualforce page.
 * Reads ?id=<enrolmentId> and exposes exactly what the certificate prints.
 */
public with sharing class CertificateController {

    public Enrolment__c enrolment { get; private set; }
    public String issuedOn        { get; private set; }

    public CertificateController() {
        Id enrolmentId = (Id) ApexPages.currentPage().getParameters().get('id');
        enrolment = [
            SELECT Id, Name, Student__r.Name,
                   Cohort__r.Cohort_Label__c, Cohort__r.End_Date__c,
                   Cohort__r.Course__r.Name, Cohort__r.Course__r.Course_Level__c
            FROM Enrolment__c
            WHERE Id = :enrolmentId
            LIMIT 1
        ];
        issuedOn = Date.today().format();
    }
}
