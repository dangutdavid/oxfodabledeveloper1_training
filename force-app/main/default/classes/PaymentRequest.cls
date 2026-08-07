/**
 * Plain data carrier handed to any IPaymentGateway implementation.
 * Deliberately contains no SObjects: the gateway layer must not know
 * about the Salesforce data model, only about "charge this much".
 */
public with sharing class PaymentRequest {
    public Id      invoiceId;
    public String  invoiceNumber;
    public Decimal amount;            // in the invoice currency, not GBP
    public String  currencyCode;
    public String  studentEmail;
    public String  idempotencyKey;    // same key twice must never charge twice
}
