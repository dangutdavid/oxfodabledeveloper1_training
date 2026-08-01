public with sharing class EnrolmentStatusService {

    public class Request {
        @InvocableVariable(
            label='Student Email'
            description='The email address the student used when booking.'
            required=true)
        public String studentEmail;
    }

    public class Result {
        @InvocableVariable(label='Answer' description='A summary of the student current enrolments.')
        public String answer;

        @InvocableVariable(label='Found' description='True if any enrolment was found for that email.')
        public Boolean found;
    }

    @InvocableMethod(
        label='Check Enrolment Status'
        description='Returns the cohorts and enrolment statuses held by the student with the given email address.'
        category='Oxfordable CareerLaunch')
    public static List<Result> checkStatus(List<Request> requests) {

        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result res   = new Result();
            String email = String.isBlank(req.studentEmail) ? '' : req.studentEmail.trim();

            List<Enrolment__c> enrolments = [
                SELECT Id, Name, Status__c, Enrolment_Date__c,
                       Cohort__r.Cohort_Label__c, Cohort__r.Start_Date__c,
                       Cohort__r.Delivery_Mode__c, Student__r.FirstName
                FROM Enrolment__c
                WHERE Student__r.Email = :email
                ORDER BY Cohort__r.Start_Date__c ASC
                LIMIT 10
            ];

            res.found = !enrolments.isEmpty();

            if (enrolments.isEmpty()) {
                res.answer = 'I could not find an enrolment for ' + email
                    + '. Please check the address used at booking, or I can pass this to the team.';
            } else {
                List<String> lines = new List<String>();
                for (Enrolment__c e : enrolments) {
                    lines.add(e.Cohort__r.Cohort_Label__c
                            + ' starting ' + e.Cohort__r.Start_Date__c.format()
                            + ' - status: ' + e.Status__c);
                }
                res.answer = 'Enrolments found: ' + String.join(lines, '; ') + '.';
            }
            results.add(res);
        }
        return results;
    }
}
