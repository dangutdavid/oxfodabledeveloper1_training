// E2E Test Document - seed data TD-01 .. TD-06 (idempotent: safe to re-run).
// TD-08: deliberately creates NO enrolments/invoices - the suites create those.

// ---- TD-01 / TD-02: courses ----
Map<String, Course__c> coursesByName = new Map<String, Course__c>();
for (Course__c c : [SELECT Id, Name FROM Course__c WHERE Name LIKE 'E2E %']) {
    coursesByName.put(c.Name, c);
}
List<Course__c> newCourses = new List<Course__c>();
if (!coursesByName.containsKey('E2E Developer Course')) {
    newCourses.add(new Course__c(Name = 'E2E Developer Course', Course_Level__c = 'Introductory',
        Duration_Weeks__c = 5, Fee__c = 500, Active__c = true));
}
if (!coursesByName.containsKey('E2E Free Taster')) {
    newCourses.add(new Course__c(Name = 'E2E Free Taster', Course_Level__c = 'Introductory',
        Duration_Weeks__c = 1, Fee__c = 0, Active__c = true));
}
insert newCourses;
for (Course__c c : newCourses) { coursesByName.put(c.Name, c); }
Id devCourseId  = coursesByName.get('E2E Developer Course').Id;
Id freeCourseId = coursesByName.get('E2E Free Taster').Id;

// ---- TD-03 / TD-04 / TD-05: cohorts (keyed by capacity + course) ----
List<Cohort__c> existingCohorts = [
    SELECT Id, Course__c, Capacity__c FROM Cohort__c
    WHERE Course__c = :devCourseId OR Course__c = :freeCourseId];
Boolean hasSmall = false, hasBig = false, hasFree = false;
for (Cohort__c c : existingCohorts) {
    if (c.Course__c == devCourseId  && c.Capacity__c == 3)   hasSmall = true;
    if (c.Course__c == devCourseId  && c.Capacity__c == 200) hasBig   = true;
    if (c.Course__c == freeCourseId && c.Capacity__c == 10)  hasFree  = true;
}
List<Cohort__c> newCohorts = new List<Cohort__c>();
if (!hasSmall) newCohorts.add(new Cohort__c(Course__c = devCourseId,
    Start_Date__c = Date.today().addDays(14), End_Date__c = Date.today().addDays(49),
    Delivery_Mode__c = 'Online', Capacity__c = 3, Status__c = 'Open'));
if (!hasBig) newCohorts.add(new Cohort__c(Course__c = devCourseId,
    Start_Date__c = Date.today().addDays(30), End_Date__c = Date.today().addDays(65),
    Delivery_Mode__c = 'Online', Capacity__c = 200, Status__c = 'Open'));
if (!hasFree) newCohorts.add(new Cohort__c(Course__c = freeCourseId,
    Start_Date__c = Date.today().addDays(14), End_Date__c = Date.today().addDays(21),
    Delivery_Mode__c = 'Online', Capacity__c = 10, Status__c = 'Open'));
insert newCohorts;

// ---- TD-06: account + five student contacts ----
List<Account> accs = [SELECT Id FROM Account WHERE Name = 'E2E Students' LIMIT 1];
Account acc = accs.isEmpty() ? new Account(Name = 'E2E Students') : accs[0];
if (acc.Id == null) insert acc;

Map<String, String> emailByLastName = new Map<String, String>{
    'A' => 'e2e.student.a@oxfordable.test',
    'B' => 'e2e.student.b@oxfordable.test',
    'C' => 'e2e.declined@oxfordable.test',   // "declined" drives the gateway stub failure path
    'D' => 'e2e.student.d@oxfordable.test',
    'E' => 'e2e.student.e@oxfordable.test'
};
Set<String> existingEmails = new Set<String>();
for (Contact c : [SELECT Email FROM Contact WHERE Email LIKE 'e2e.%@oxfordable.test']) {
    existingEmails.add(c.Email);
}
List<Contact> newContacts = new List<Contact>();
for (String lastName : emailByLastName.keySet()) {
    if (!existingEmails.contains(emailByLastName.get(lastName))) {
        newContacts.add(new Contact(FirstName = 'Student', LastName = lastName,
            Email = emailByLastName.get(lastName), AccountId = acc.Id));
    }
}
Database.DMLOptions dml = new Database.DMLOptions();
dml.DuplicateRuleHeader.allowSave = true;
Database.insert(newContacts, dml);

System.debug('SEED OK. Courses=' + [SELECT COUNT() FROM Course__c WHERE Name LIKE 'E2E %']
    + ' Cohorts=' + [SELECT COUNT() FROM Cohort__c WHERE Course__r.Name LIKE 'E2E %']
    + ' Contacts=' + [SELECT COUNT() FROM Contact WHERE Email LIKE 'e2e.%@oxfordable.test']);
