/**
 * Orchestrates a payment: load invoice -> call gateway -> record outcome.
 *
 * without sharing, deliberately: the portal student only has READ access to
 * their invoice, but once the gateway confirms the charge the system must be
 * able to write the result regardless of the student's own permissions.
 * The class never trusts caller input for the amount - it always charges
 * exactly what the invoice says.
 */
public without sharing class PaymentService {

    public class PaymentStateException extends Exception {}

    public static PaymentResult payInvoice(Id invoiceId) {

        Invoice__c invoice = [
            SELECT Id, Name, Amount__c, Amount_In_Currency__c, Currency_Code__c,
                   Status__c, Enrolment__c, Enrolment__r.Amount_Paid__c,
                   Enrolment__r.Student__r.Email
            FROM Invoice__c
            WHERE Id = :invoiceId
            LIMIT 1
        ];

        if (invoice.Status__c == 'Paid') {
            throw new PaymentStateException('Invoice ' + invoice.Name + ' is already paid.');
        }
        if (invoice.Status__c == 'Cancelled') {
            throw new PaymentStateException('Invoice ' + invoice.Name + ' was cancelled.');
        }

        PaymentRequest request = new PaymentRequest();
        request.invoiceId      = invoice.Id;
        request.invoiceNumber  = invoice.Name;
        request.amount         = invoice.Amount_In_Currency__c;
        request.currencyCode   = invoice.Currency_Code__c;
        request.studentEmail   = invoice.Enrolment__r.Student__r.Email;
        // Invoice id + number never changes, so a retry after a timeout
        // presents the same key and cannot double-charge.
        request.idempotencyKey = invoice.Id + '-' + invoice.Name;

        // Callout happens BEFORE any DML: Salesforce forbids the reverse order.
        PaymentResult result = PaymentGatewayFactory.getGateway().charge(request);

        if (result.success) {
            invoice.Status__c            = 'Paid';
            invoice.Paid_Date__c         = Date.today();
            invoice.Payment_Reference__c = result.transactionId;
            update invoice;

            // The enrolment tracks what has been paid in GBP (org currency).
            Decimal paidSoFar = invoice.Enrolment__r.Amount_Paid__c == null
                ? 0 : invoice.Enrolment__r.Amount_Paid__c;
            update new Enrolment__c(
                Id             = invoice.Enrolment__c,
                Amount_Paid__c = paidSoFar + invoice.Amount__c
            );
        }

        return result;
    }
}
