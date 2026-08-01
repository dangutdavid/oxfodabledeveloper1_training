@isTest
public class TestDataFactory {

    public static Course__c createCourse(String name, String level, Decimal fee) {
        Course__c course = new Course__c(
            Name              = name,
            Course_Level__c   = level,
            Duration_Weeks__c = 5,
            Fee__c            = fee,
            Active__c         = true
        );
        insert course;
        return course;
    }

    public static Cohort__c createCohort(Id courseId, Integer capacity, Integer daysFromToday) {
        Cohort__c cohort = new Cohort__c(
            Course__c        = courseId,
            Start_Date__c    = Date.today().addDays(daysFromToday),
            End_Date__c      = Date.today().addDays(daysFromToday + 35),
            Delivery_Mode__c = 'Online',
            Capacity__c      = capacity,
            Status__c        = 'Open'
        );
        insert cohort;
        return cohort;
    }

    public static List<Contact> createStudents(Integer howMany) {
        List<Contact> students = new List<Contact>();
        for (Integer i = 0; i < howMany; i++) {
            students.add(new Contact(
                FirstName = 'Test',
                LastName  = 'Student ' + i,
                Email     = 'student' + i + '@oxfordable.test'
            ));
        }
        // Bypass any active duplicate rules in the org so bulk tests are deterministic.
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.allowSave = true;
        dml.optAllOrNone = true;
        Database.insert(students, dml);
        return students;
    }

    public static List<Enrolment__c> buildEnrolments(Id cohortId, List<Contact> students, String status) {
        List<Enrolment__c> enrolments = new List<Enrolment__c>();
        for (Contact student : students) {
            enrolments.add(new Enrolment__c(
                Cohort__c  = cohortId,
                Student__c = student.Id,
                Status__c  = status
            ));
        }
        return enrolments;   // deliberately NOT inserted - the caller decides
    }
}
