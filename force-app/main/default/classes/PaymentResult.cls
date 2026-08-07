/**
 * What every gateway implementation returns, real or stubbed.
 * The caller never sees an HttpResponse - by the time a result reaches
 * PaymentService the transport details have been translated away.
 */
public with sharing class PaymentResult {
    @AuraEnabled public Boolean success       { get; set; }
    @AuraEnabled public String  transactionId { get; set; }
    @AuraEnabled public String  errorMessage  { get; set; }

    public static PaymentResult ok(String transactionId) {
        PaymentResult r = new PaymentResult();
        r.success       = true;
        r.transactionId = transactionId;
        return r;
    }

    public static PaymentResult fail(String message) {
        PaymentResult r = new PaymentResult();
        r.success      = false;
        r.errorMessage = message;
        return r;
    }
}
