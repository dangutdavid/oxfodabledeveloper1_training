/**
 * Persists Error_Log_Event__e platform events as Error_Log__c records.
 * Runs in its own transaction (as the Automated Process user), so the log
 * survives even when the transaction that raised the error rolled back.
 */
trigger ErrorLogEventTrigger on Error_Log_Event__e (after insert) {

    List<Error_Log__c> logs = new List<Error_Log__c>();
    for (Error_Log_Event__e event : Trigger.new) {
        logs.add(new Error_Log__c(
            Source_Type__c   = event.Source_Type__c,
            Source_Name__c   = event.Source_Name__c,
            Error_Message__c = event.Error_Message__c,
            Stack_Trace__c   = event.Stack_Trace__c,
            Record_Id__c     = event.Record_Id__c,
            Severity__c      = event.Severity__c
        ));
    }
    insert logs;
}
