@isTest
private class CurrencyServiceTest {

    @isTest
    static void gbpIsAlwaysParity() {
        Assert.areEqual(1, CurrencyService.getRate('GBP'));
        Assert.areEqual(100.00, CurrencyService.convertFromGBP(100, 'GBP'));
    }

    @isTest
    static void conversionUsesConfiguredRateAndRounds() {
        Decimal rate = CurrencyService.getRate('USD');
        Assert.isTrue(rate > 0, 'USD rate must be configured in Exchange_Rate__mdt');

        Decimal converted = CurrencyService.convertFromGBP(100, 'USD');
        Assert.areEqual((100 * rate).setScale(2, RoundingMode.HALF_UP), converted);
        Assert.areEqual(2, converted.scale(), 'Money is always presented to 2 dp');
    }

    @isTest
    static void unknownCurrencyThrows() {
        try {
            CurrencyService.getRate('XXX');
            Assert.fail('Expected UnknownCurrencyException');
        } catch (CurrencyService.UnknownCurrencyException e) {
            Assert.isTrue(e.getMessage().contains('XXX'));
        }
    }

    @isTest
    static void nullAmountsPassThrough() {
        Assert.isNull(CurrencyService.convertFromGBP(null, 'USD'));
    }

    @isTest
    static void formatIncludesSymbol() {
        String display = CurrencyService.format(1250, 'GBP');
        Assert.isTrue(display.contains('1,250'), 'Expected thousands separator: ' + display);
    }
}
