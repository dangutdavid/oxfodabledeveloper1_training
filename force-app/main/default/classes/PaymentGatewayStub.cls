/**
 * The training-org implementation: behaves like a gateway, calls nothing.
 *
 * Deterministic on purpose so exercises are repeatable:
 *  - amounts <= 0 are rejected (mirrors real gateway validation)
 *  - an email containing "declined" simulates a failed card
 *  - everything else succeeds with a reference derived from the invoice number
 */
public with sharing class PaymentGatewayStub implements IPaymentGateway {

    public PaymentResult charge(PaymentRequest request) {

        if (request.amount == null || request.amount <= 0) {
            return PaymentResult.fail('Amount must be greater than zero.');
        }

        if (request.studentEmail != null
            && request.studentEmail.containsIgnoreCase('declined')) {
            return PaymentResult.fail('Card declined by issuer (simulated).');
        }

        return PaymentResult.ok('STUB-' + request.invoiceNumber + '-'
            + request.currencyCode);
    }
}
