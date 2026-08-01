public with sharing class CohortAvailabilityService {

    public class Request {
        @InvocableVariable(
            label='Course Name'
            description='All or part of the course name, for example "Advanced" or "Salesforce Developer".'
            required=true)
        public String courseName;
    }

    public class Result {
        @InvocableVariable(
            label='Answer'
            description='A short, human-readable summary of the cohorts that still have seats.')
        public String answer;

        @InvocableVariable(
            label='Available Cohorts'
            description='The matching cohort records that still have seats available.')
        public List<Cohort__c> cohorts;

        @InvocableVariable(label='Seats Available' description='True if at least one seat was found.')
        public Boolean seatsAvailable;
    }

    @InvocableMethod(
        label='Find Available Cohorts'
        description='Returns open cohorts that still have seats for a given course name.'
        category='Oxfordable CareerLaunch')
    public static List<Result> findAvailableCohorts(List<Request> requests) {

        List<Result> results = new List<Result>();

        for (Request req : requests) {
            String searchTerm = '%' + (String.isBlank(req.courseName) ? '' : req.courseName.trim()) + '%';

            List<Cohort__c> candidates = [
                SELECT Id, Name, Cohort_Label__c, Course__r.Name, Start_Date__c,
                       Delivery_Mode__c, Capacity__c, Enrolled_Count__c, Seats_Remaining__c
                FROM Cohort__c
                WHERE Status__c = 'Open'
                  AND Start_Date__c >= TODAY
                  AND Course__r.Name LIKE :searchTerm
                ORDER BY Start_Date__c ASC
                LIMIT 20
            ];

            List<Cohort__c> withSeats = new List<Cohort__c>();
            for (Cohort__c c : candidates) {
                if (c.Seats_Remaining__c != null && c.Seats_Remaining__c > 0) {
                    withSeats.add(c);
                }
            }

            Result res         = new Result();
            res.cohorts        = withSeats;
            res.seatsAvailable = !withSeats.isEmpty();
            res.answer         = buildAnswer(req.courseName, withSeats);
            results.add(res);
        }
        return results;
    }

    private static String buildAnswer(String courseName, List<Cohort__c> cohorts) {
        if (cohorts.isEmpty()) {
            return 'There are currently no cohorts with available seats matching "'
                 + courseName + '". Please ask about another course or a later date.';
        }
        List<String> lines = new List<String>();
        for (Cohort__c c : cohorts) {
            lines.add(c.Course__r.Name + ' starting ' + c.Start_Date__c.format()
                    + ' (' + c.Delivery_Mode__c + ') - '
                    + String.valueOf(c.Seats_Remaining__c.intValue()) + ' seat(s) remaining');
        }
        return 'Cohorts with availability: ' + String.join(lines, '; ') + '.';
    }
}
