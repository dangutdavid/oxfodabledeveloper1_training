public with sharing class StudentSummaryQueueable implements Queueable {

    private final Set<Id> studentIds;

    public StudentSummaryQueueable(Set<Id> studentIds) {
        this.studentIds = studentIds;
    }

    public void execute(QueueableContext context) {
        Map<Id, Contact> contactsToUpdate = new Map<Id, Contact>();

        // Start everyone at zero so cancellations are reflected too.
        for (Id studentId : studentIds) {
            contactsToUpdate.put(studentId, new Contact(Id = studentId, Total_Enrolments__c = 0));
        }

        for (AggregateResult ar : [
            SELECT Student__c studentId, COUNT(Id) total
            FROM Enrolment__c
            WHERE Student__c IN :studentIds
              AND Status__c != 'Cancelled'
            GROUP BY Student__c
        ]) {
            Id studentId  = (Id) ar.get('studentId');
            Integer total = (Integer) ar.get('total');
            contactsToUpdate.put(studentId, new Contact(Id = studentId, Total_Enrolments__c = total));
        }

        if (!contactsToUpdate.isEmpty()) {
            try {
                update contactsToUpdate.values();
            } catch (DmlException e) {
                System.debug(LoggingLevel.ERROR, 'Student summary update failed: ' + e.getMessage());
            }
        }
    }
}
