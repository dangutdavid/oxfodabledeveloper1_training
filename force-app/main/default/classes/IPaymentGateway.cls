/**
 * The seam between CareerLaunch and any real payment provider.
 *
 * Everything above this interface (PaymentService, the portal, tests)
 * depends only on charge(); everything below it (HTTP, auth, JSON shapes)
 * is swappable per org via Integration_Setting__mdt without touching callers.
 */
public interface IPaymentGateway {
    PaymentResult charge(PaymentRequest request);
}
