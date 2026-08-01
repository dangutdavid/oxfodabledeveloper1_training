trigger EnrolmentTrigger on Enrolment__c (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            EnrolmentTriggerHandler.onBeforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            EnrolmentTriggerHandler.onBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        EnrolmentTriggerHandler.onAfterChange(Trigger.new);
    }
}
