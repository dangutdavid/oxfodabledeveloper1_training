/**
 * One front door for every error in the org - Apex, triggers, flows.
 *
 * Errors are NOT inserted straight into Error_Log__c: if the failing
 * transaction rolls back, a plain insert would roll back with it and the
 * evidence would vanish. Instead we publish Error_Log_Event__e (publish
 * behaviour: immediately), which survives the rollback; the event trigger
 * then writes the durable Error_Log__c record.
 *
 * Apex:    try { ... } catch (Exception e) { ErrorLogger.log(e, 'MyClass', recordId); }
 * Flows:   Fault path -> Action "Log Flow Error".
 */
public without sharing class ErrorLogger {

    // ---------- Apex & trigger entry points ----------

    public static void log(Exception e, String sourceName) {
        log(e, sourceName, null);
    }

    public static void log(Exception e, String sourceName, Id recordId) {
        publish('Apex', sourceName, e.getMessage(), e.getStackTraceString(),
                recordId, 'Error');
    }

    public static void log(String sourceType, String sourceName, String message,
                           String stackTrace, Id recordId, String severity) {
        publish(sourceType, sourceName, message, stackTrace, recordId, severity);
    }

    // ---------- Flow entry point ----------

    public class FlowError {
        @InvocableVariable(label='Flow Name' required=true)
        public String flowName;

        @InvocableVariable(label='Error Message' required=true)
        public String errorMessage;

        @InvocableVariable(label='Record Id')
        public String recordId;
    }

    @InvocableMethod(
        label='Log Flow Error'
        description='Call from a fault path to record the failure in Error Logs.'
        category='Oxfordable CareerLaunch')
    public static void logFlowErrors(List<FlowError> errors) {
        List<Error_Log_Event__e> events = new List<Error_Log_Event__e>();
        for (FlowError err : errors) {
            events.add(new Error_Log_Event__e(
                Source_Type__c   = 'Flow',
                Source_Name__c   = err.flowName,
                Error_Message__c = err.errorMessage,
                Record_Id__c     = err.recordId,
                Severity__c      = 'Error'
            ));
        }
        EventBus.publish(events);
    }

    // ---------- Shared publisher ----------

    private static void publish(String sourceType, String sourceName, String message,
                                String stackTrace, Id recordId, String severity) {
        EventBus.publish(new Error_Log_Event__e(
            Source_Type__c   = sourceType,
            Source_Name__c   = sourceName,
            Error_Message__c = message == null ? '' : message.abbreviate(32000),
            Stack_Trace__c   = stackTrace == null ? null : stackTrace.abbreviate(32000),
            Record_Id__c     = recordId == null ? null : String.valueOf(recordId),
            Severity__c      = severity
        ));
    }
}
