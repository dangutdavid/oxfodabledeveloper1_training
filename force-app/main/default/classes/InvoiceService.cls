/**
 * Creates and manages invoices for enrolments.
 *
 * inherited sharing: when called from the trigger it runs in the caller's
 * context; when called from PaymentService it inherits that class's choice.
 */
public inherited sharing class InvoiceService {

    private static final Integer PAYMENT_TERMS_DAYS = 14;

    /**
     * Issues one Sent invoice per Confirmed enrolment that does not already
     * have a live (non-cancelled) invoice. Bulk-safe: called from the
     * Enrolment trigger with the full Trigger.new list.
     */
    public static List<Invoice__c> createForConfirmedEnrolments(List<Enrolment__c> enrolments) {
        return createForConfirmedEnrolments(enrolments, 'GBP');
    }

    public static List<Invoice__c> createForConfirmedEnrolments(List<Enrolment__c> enrolments,
                                                                String currencyCode) {
        Set<Id> confirmedIds = new Set<Id>();
        for (Enrolment__c enr : enrolments) {
            if (enr.Status__c == 'Confirmed') {
                confirmedIds.add(enr.Id);
            }
        }
        if (confirmedIds.isEmpty()) {
            return new List<Invoice__c>();
        }

        // One query finds enrolments that already hold a live invoice.
        Set<Id> alreadyInvoiced = new Set<Id>();
        for (Invoice__c existing : [
            SELECT Enrolment__c
            FROM Invoice__c
            WHERE Enrolment__c IN :confirmedIds
              AND Status__c != 'Cancelled'
        ]) {
            alreadyInvoiced.add(existing.Enrolment__c);
        }

        Decimal rate = CurrencyService.getRate(currencyCode);

        List<Invoice__c> invoices = new List<Invoice__c>();
        for (Enrolment__c enr : [
            SELECT Id, Cohort__r.Course__r.Fee__c
            FROM Enrolment__c
            WHERE Id IN :confirmedIds
              AND Id NOT IN :alreadyInvoiced
        ]) {
            Decimal fee = enr.Cohort__r.Course__r.Fee__c;
            if (fee == null || fee <= 0) {
                continue;   // free courses never produce an invoice
            }
            invoices.add(new Invoice__c(
                Enrolment__c      = enr.Id,
                Amount__c         = fee,
                Currency_Code__c  = currencyCode,
                Exchange_Rate__c  = rate,
                Status__c         = 'Sent',
                Due_Date__c       = Date.today().addDays(PAYMENT_TERMS_DAYS)
            ));
        }

        insert invoices;
        return invoices;
    }
}
