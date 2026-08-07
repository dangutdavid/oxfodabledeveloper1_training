/**
 * Single Apex entry point for the Experience Cloud student portal.
 *
 * Every method starts from the LOGGED-IN user's Contact - the client never
 * passes "whose data" as a parameter, so one student can never request
 * another student's enrolments or pay against another student's invoice.
 */
public with sharing class StudentPortalController {

    // Tests set this instead of creating a full Experience Cloud user.
    @TestVisible
    private static Id contactIdOverride;

    public class EnrolmentView {
        @AuraEnabled public Id      id                { get; set; }
        @AuraEnabled public String  courseName        { get; set; }
        @AuraEnabled public String  cohortLabel       { get; set; }
        @AuraEnabled public String  status            { get; set; }
        @AuraEnabled public Date    startDate         { get; set; }
        @AuraEnabled public Boolean certificateIssued { get; set; }
        @AuraEnabled public String  certificateUrl    { get; set; }
    }

    public class InvoiceView {
        @AuraEnabled public Id     id            { get; set; }
        @AuraEnabled public String invoiceNumber { get; set; }
        @AuraEnabled public String courseName    { get; set; }
        @AuraEnabled public String amountDisplay { get; set; }
        @AuraEnabled public String status        { get; set; }
        @AuraEnabled public Date   dueDate       { get; set; }
        @AuraEnabled public Boolean payable      { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static List<EnrolmentView> getMyEnrolments() {
        Id contactId = resolveContactId();

        List<Enrolment__c> enrolments = [
            SELECT Id, Status__c, Certificate_Issued__c,
                   Cohort__r.Cohort_Label__c, Cohort__r.Start_Date__c,
                   Cohort__r.Course__r.Name
            FROM Enrolment__c
            WHERE Student__c = :contactId
            ORDER BY Cohort__r.Start_Date__c DESC
        ];

        Map<Id, Id> certificateDocByEnrolment = findCertificates(enrolments);

        List<EnrolmentView> views = new List<EnrolmentView>();
        for (Enrolment__c enr : enrolments) {
            EnrolmentView view     = new EnrolmentView();
            view.id                = enr.Id;
            view.courseName        = enr.Cohort__r.Course__r.Name;
            view.cohortLabel       = enr.Cohort__r.Cohort_Label__c;
            view.status            = enr.Status__c;
            view.startDate         = enr.Cohort__r.Start_Date__c;
            view.certificateIssued = enr.Certificate_Issued__c;
            if (certificateDocByEnrolment.containsKey(enr.Id)) {
                view.certificateUrl = '/sfc/servlet.shepherd/document/download/'
                    + certificateDocByEnrolment.get(enr.Id);
            }
            views.add(view);
        }
        return views;
    }

    @AuraEnabled(cacheable=true)
    public static List<InvoiceView> getMyInvoices() {
        Id contactId = resolveContactId();

        List<InvoiceView> views = new List<InvoiceView>();
        for (Invoice__c inv : [
            SELECT Id, Name, Status__c, Due_Date__c, Currency_Code__c,
                   Amount_In_Currency__c, Enrolment__r.Cohort__r.Course__r.Name
            FROM Invoice__c
            WHERE Enrolment__r.Student__c = :contactId
            ORDER BY Due_Date__c ASC NULLS LAST
        ]) {
            InvoiceView view   = new InvoiceView();
            view.id            = inv.Id;
            view.invoiceNumber = inv.Name;
            view.courseName    = inv.Enrolment__r.Cohort__r.Course__r.Name;
            view.status        = inv.Status__c;
            view.dueDate       = inv.Due_Date__c;
            view.payable       = inv.Status__c == 'Sent' || inv.Status__c == 'Draft';
            view.amountDisplay = CurrencyService.getSymbol(inv.Currency_Code__c)
                + inv.Amount_In_Currency__c.format()
                + ' ' + inv.Currency_Code__c;
            views.add(view);
        }
        return views;
    }

    @AuraEnabled
    public static PaymentResult payInvoice(Id invoiceId) {
        Id contactId = resolveContactId();

        // Ownership check BEFORE any money moves: the invoice must belong to
        // the student who is logged in, whatever id the browser sent us.
        Integer owned = [
            SELECT COUNT()
            FROM Invoice__c
            WHERE Id = :invoiceId
              AND Enrolment__r.Student__c = :contactId
        ];
        if (owned == 0) {
            throw new AuraHandledException('That invoice does not belong to you.');
        }

        try {
            return PaymentService.payInvoice(invoiceId);
        } catch (PaymentService.PaymentStateException e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static Id resolveContactId() {
        if (contactIdOverride != null) {
            return contactIdOverride;
        }
        Id contactId = [
            SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()
        ].ContactId;

        if (contactId == null) {
            throw new AuraHandledException(
                'Your user is not linked to a student record. '
                + 'Please contact the CareerLaunch team.');
        }
        return contactId;
    }

    private static Map<Id, Id> findCertificates(List<Enrolment__c> enrolments) {
        Map<Id, Id> docByEnrolment = new Map<Id, Id>();
        if (enrolments.isEmpty()) {
            return docByEnrolment;
        }
        for (ContentDocumentLink link : [
            SELECT LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :new Map<Id, Enrolment__c>(enrolments).keySet()
              AND ContentDocument.Title LIKE 'Certificate%'
        ]) {
            docByEnrolment.put(link.LinkedEntityId, link.ContentDocumentId);
        }
        return docByEnrolment;
    }
}
