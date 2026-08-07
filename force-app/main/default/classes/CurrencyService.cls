/**
 * Multi-currency for a single-currency org.
 *
 * The org's corporate currency stays GBP; every price is stored in GBP and
 * presented in the student's currency using rates held in Exchange_Rate__mdt.
 * The rate used is FROZEN onto each invoice at issue time, so later rate
 * edits never change what an existing invoice is worth.
 *
 * (Orgs with native multi-currency enabled would use CurrencyIsoCode and
 * dated conversion rates instead - see docs/PATTERNS.md.)
 */
public with sharing class CurrencyService {

    public class UnknownCurrencyException extends Exception {}

    /** How many units of isoCode one GBP buys, e.g. getRate('USD') -> 1.27 */
    public static Decimal getRate(String isoCode) {
        Exchange_Rate__mdt rate = Exchange_Rate__mdt.getInstance(isoCode);
        if (rate == null) {
            throw new UnknownCurrencyException(
                'No Exchange_Rate__mdt record for currency: ' + isoCode);
        }
        return rate.Rate_From_GBP__c;
    }

    public static String getSymbol(String isoCode) {
        Exchange_Rate__mdt rate = Exchange_Rate__mdt.getInstance(isoCode);
        return (rate == null || String.isBlank(rate.Symbol__c))
            ? isoCode + ' ' : rate.Symbol__c;
    }

    /** Converts a GBP amount into isoCode, rounded to 2 dp half-up. */
    public static Decimal convertFromGBP(Decimal gbpAmount, String isoCode) {
        if (gbpAmount == null) {
            return null;
        }
        return (gbpAmount * getRate(isoCode)).setScale(2, RoundingMode.HALF_UP);
    }

    /** '£1,250.00' / '$1,587.50' style display string for UI and PDFs. */
    public static String format(Decimal gbpAmount, String isoCode) {
        Decimal converted = convertFromGBP(gbpAmount, isoCode);
        return getSymbol(isoCode) + converted.format();
    }
}
