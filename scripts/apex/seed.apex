// Oxfordable CareerLaunch - sample data (Lab 2 step 9)
// Run with: sf apex run --file scripts/apex/seed.apex --target-org lse-demo

Course__c intro = new Course__c(Name='Salesforce Developer - Introductory',
    Course_Level__c='Introductory', Duration_Weeks__c=3, Fee__c=500, Active__c=true,
    Description__c='Three-week introductory programme covering the platform, data model, automation and code.');
Course__c adv = new Course__c(Name='Salesforce Developer - Advanced',
    Course_Level__c='Advanced', Duration_Weeks__c=10, Fee__c=1500, Active__c=true,
    Description__c='Advanced course preparing for the Platform Developer I certification.');
insert new List<Course__c>{ intro, adv };

Cohort__c c1 = new Cohort__c(Course__c=intro.Id, Start_Date__c=Date.today().addDays(14),
    End_Date__c=Date.today().addDays(35), Delivery_Mode__c='Online', Capacity__c=3, Status__c='Open');
Cohort__c c2 = new Cohort__c(Course__c=adv.Id, Start_Date__c=Date.today().addDays(30),
    End_Date__c=Date.today().addDays(100), Delivery_Mode__c='Hybrid', Capacity__c=10, Status__c='Open');
insert new List<Cohort__c>{ c1, c2 };

List<Contact> students = new List<Contact>{
    new Contact(FirstName='Amina', LastName='Bello',  Email='amina.bello@oxfordable.test'),
    new Contact(FirstName='James', LastName='Okafor', Email='james.okafor@oxfordable.test'),
    new Contact(FirstName='Grace', LastName='Musa',   Email='grace.musa@oxfordable.test')
};
insert students;

System.debug('Seed complete: 2 courses, 2 cohorts (CO capacity 3 and 10), 3 student contacts.');
