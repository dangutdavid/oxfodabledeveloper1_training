// E2E-07: capacity must hold under a 200-record bulk load (US-04 / NFR-01).
// Inserts 205 confirmed enrolments against the capacity-200 "big cohort";
// expected outcome: exactly 200 succeed, 5 fail with the capacity message.

Cohort__c bigCohort = [
    SELECT Id, Capacity__c FROM Cohort__c
    WHERE Course__r.Name = 'E2E Developer Course' AND Capacity__c = 200
    LIMIT 1];

List<Contact> bulkStudents = new List<Contact>();
for (Integer i = 0; i < 205; i++) {
    bulkStudents.add(new Contact(FirstName = 'Bulk', LastName = 'Student ' + i,
        Email = 'e2e.bulk' + i + '@oxfordable.test'));
}
Database.DMLOptions dml = new Database.DMLOptions();
dml.DuplicateRuleHeader.allowSave = true;
Database.insert(bulkStudents, dml);

List<Enrolment__c> enrolments = new List<Enrolment__c>();
for (Contact c : bulkStudents) {
    enrolments.add(new Enrolment__c(
        Cohort__c = bigCohort.Id, Student__c = c.Id, Status__c = 'Confirmed'));
}
List<Database.SaveResult> results = Database.insert(enrolments, false);

Integer ok = 0, failed = 0;
String firstError;
for (Database.SaveResult r : results) {
    if (r.isSuccess()) { ok++; }
    else { failed++; if (firstError == null) firstError = r.getErrors()[0].getMessage(); }
}
System.debug('BULK RESULT: succeeded=' + ok + ' failed=' + failed
    + ' firstError="' + firstError + '"');
// Expected: succeeded=200 failed=5, firstError contains "full".
