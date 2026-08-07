/**
 * Decides WHICH IPaymentGateway implementation runs in this org.
 *
 * The class name lives in Integration_Setting__mdt (record: Payment_Gateway),
 * so promoting from stub to the real client is a metadata change, not a code
 * change: training orgs point at PaymentGatewayStub, production points at
 * PaymentGatewayHttpClient.
 */
public with sharing class PaymentGatewayFactory {

    public class GatewayConfigException extends Exception {}

    // Tests inject a mock here instead of going through custom metadata.
    @TestVisible
    private static IPaymentGateway gatewayOverride;

    public static IPaymentGateway getGateway() {
        if (gatewayOverride != null) {
            return gatewayOverride;
        }

        Integration_Setting__mdt setting =
            Integration_Setting__mdt.getInstance('Payment_Gateway');

        String className = setting == null
            ? 'PaymentGatewayStub'
            : setting.Implementation_Class__c;

        Type implementation = Type.forName(className);
        if (implementation == null) {
            throw new GatewayConfigException(
                'Integration_Setting__mdt.Payment_Gateway names a class that '
                + 'does not exist: ' + className);
        }

        Object instance = implementation.newInstance();
        if (!(instance instanceof IPaymentGateway)) {
            throw new GatewayConfigException(
                className + ' does not implement IPaymentGateway.');
        }
        return (IPaymentGateway) instance;
    }
}
