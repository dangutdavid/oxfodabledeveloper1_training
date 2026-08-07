/**
 * The real-world implementation: POSTs a charge to the provider named by
 * the Payment_Gateway Named Credential.
 *
 * The Named Credential owns the URL and the authentication; this class never
 * sees a password or a token, only "callout:Payment_Gateway". Swap providers
 * by repointing the credential and, if the JSON shape differs, writing one
 * new class that implements IPaymentGateway.
 */
public with sharing class PaymentGatewayHttpClient implements IPaymentGateway {

    private static final Integer TIMEOUT_MS = 20000;

    public PaymentResult charge(PaymentRequest request) {

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Payment_Gateway/v1/charges');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        // Real gateways honour this header: retrying after a timeout with the
        // same key can never charge the student twice.
        req.setHeader('Idempotency-Key', request.idempotencyKey);
        req.setTimeout(TIMEOUT_MS);
        req.setBody(JSON.serialize(new ChargePayload(request)));

        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (CalloutException e) {
            // Timeout or DNS failure: we do NOT know whether the charge went
            // through, so report failure and rely on the idempotency key when
            // the user retries.
            ErrorLogger.log('Integration', 'PaymentGatewayHttpClient',
                e.getMessage(), e.getStackTraceString(), request.invoiceId, 'Critical');
            return PaymentResult.fail('Payment provider unreachable: ' + e.getMessage());
        }

        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            ChargeResponse parsed =
                (ChargeResponse) JSON.deserialize(res.getBody(), ChargeResponse.class);
            return PaymentResult.ok(parsed.transactionId);
        }

        return PaymentResult.fail(
            'Gateway returned HTTP ' + res.getStatusCode() + ': ' + res.getBody());
    }

    // The provider's wire format, kept private: nobody outside this class
    // should ever depend on it.
    private class ChargePayload {
        public Decimal amount;
        public String currencyCode;
        public String reference;
        public String customerEmail;
        ChargePayload(PaymentRequest request) {
            amount        = request.amount;
            currencyCode  = request.currencyCode;
            reference     = request.invoiceNumber;
            customerEmail = request.studentEmail;
        }
    }

    @TestVisible
    private class ChargeResponse {
        public String transactionId;
    }
}
