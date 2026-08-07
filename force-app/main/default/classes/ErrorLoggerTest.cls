@isTest
private class ErrorLoggerTest {

    @isTest
    static void apexExceptionBecomesLogRecord() {
        Test.startTest();
        try {
            Integer boom = 1 / 0;
        } catch (Exception e) {
            ErrorLogger.log(e, 'ErrorLoggerTest');
        }
        Test.getEventBus().deliver();
        Test.stopTest();

        Error_Log__c log = [
            SELECT Source_Type__c, Source_Name__c, Error_Message__c,
                   Stack_Trace__c, Severity__c
            FROM Error_Log__c
        ];
        Assert.areEqual('Apex', log.Source_Type__c);
        Assert.areEqual('ErrorLoggerTest', log.Source_Name__c);
        Assert.isTrue(log.Error_Message__c.contains('Divide by 0'));
        Assert.isNotNull(log.Stack_Trace__c, 'Stack trace should be captured');
        Assert.areEqual('Error', log.Severity__c);
    }

    @isTest
    static void flowFaultPathBecomesLogRecord() {
        ErrorLogger.FlowError fault = new ErrorLogger.FlowError();
        fault.flowName     = 'Quick_Enrol_Student';
        fault.errorMessage = 'Element Create_Enrolment failed.';

        Test.startTest();
        ErrorLogger.logFlowErrors(new List<ErrorLogger.FlowError>{ fault });
        Test.getEventBus().deliver();
        Test.stopTest();

        Error_Log__c log = [
            SELECT Source_Type__c, Source_Name__c, Error_Message__c FROM Error_Log__c
        ];
        Assert.areEqual('Flow', log.Source_Type__c);
        Assert.areEqual('Quick_Enrol_Student', log.Source_Name__c);
    }

    @isTest
    static void customSourceTypeAndSeverityAreKept() {
        Test.startTest();
        ErrorLogger.log('Integration', 'PaymentGatewayHttpClient',
            'Gateway returned HTTP 500', null, null, 'Critical');
        Test.getEventBus().deliver();
        Test.stopTest();

        Error_Log__c log = [SELECT Source_Type__c, Severity__c FROM Error_Log__c];
        Assert.areEqual('Integration', log.Source_Type__c);
        Assert.areEqual('Critical', log.Severity__c);
    }
}
