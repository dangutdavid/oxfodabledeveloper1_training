/**
 * Grants a student their portal login once an invoice is Paid.
 *
 * Called from the Grant_Portal_Access_On_Payment flow. The actual work runs
 * in a Queueable for two reasons: creating a User is SETUP-object DML, which
 * Salesforce forbids in the same transaction as the invoice/enrolment updates
 * (the mixed-DML rule), and a gateway payment should never wait on email.
 *
 * New students get: a portal User on the Customer Community User profile,
 * the Student_Portal_User permission set, Salesforce's set-your-password
 * email, and a welcome email with their username and the login page.
 * Students who already hold a login just get the welcome email again.
 */
public without sharing class PortalAccessService {

    private static final String PORTAL_PROFILE  = 'Customer Community User';
    private static final String PORTAL_PERM_SET = 'Student_Portal_User';
    private static final String USERNAME_DOMAIN = '@careerlaunch.portal';
    private static final String SITE_NAME       = 'CareerLaunch Portal';

    public class Request {
        @InvocableVariable(label='Invoice Id' required=true)
        public Id invoiceId;
    }

    @InvocableMethod(
        label='Grant Portal Access'
        description='Creates the paying student\'s portal login (if missing) and emails them their access details.'
        category='Oxfordable CareerLaunch')
    public static void grantAccess(List<Request> requests) {
        Set<Id> invoiceIds = new Set<Id>();
        for (Request req : requests) {
            invoiceIds.add(req.invoiceId);
        }
        if (!invoiceIds.isEmpty()
            && Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
            System.enqueueJob(new ProvisionJob(invoiceIds));
        }
    }

    public class ProvisionJob implements Queueable {

        private Set<Id> invoiceIds;

        public ProvisionJob(Set<Id> invoiceIds) {
            this.invoiceIds = invoiceIds;
        }

        public void execute(QueueableContext context) {
            try {
                provision();
            } catch (Exception e) {
                // Async has no user watching - the log is the alarm.
                ErrorLogger.log(e, 'PortalAccessService.ProvisionJob');
            }
        }

        private void provision() {

            Map<Id, Contact> studentsById = new Map<Id, Contact>();
            for (Invoice__c inv : [
                SELECT Enrolment__r.Student__c, Enrolment__r.Student__r.FirstName,
                       Enrolment__r.Student__r.LastName, Enrolment__r.Student__r.Email,
                       Enrolment__r.Student__r.AccountId
                FROM Invoice__c
                WHERE Id IN :invoiceIds AND Status__c = 'Paid'
            ]) {
                Contact student = inv.Enrolment__r.Student__r;
                if (student.Email != null && student.AccountId != null) {
                    studentsById.put(student.Id, student);
                }
            }
            if (studentsById.isEmpty()) {
                return;
            }

            // Who already holds a login? Keyed by Contact, never by username.
            Map<Id, User> existingByContact = new Map<Id, User>();
            for (User u : [
                SELECT Id, ContactId, Username, IsActive
                FROM User
                WHERE ContactId IN :studentsById.keySet() AND IsActive = true
            ]) {
                existingByContact.put(u.ContactId, u);
            }

            Profile portalProfile = [
                SELECT Id FROM Profile WHERE Name = :PORTAL_PROFILE LIMIT 1];

            List<User> newUsers = new List<User>();
            for (Contact student : studentsById.values()) {
                if (existingByContact.containsKey(student.Id)) {
                    continue;
                }
                String contactKey = String.valueOf(student.Id);
                newUsers.add(new User(
                    Username          = student.Email.replace('@', '.') + USERNAME_DOMAIN,
                    Email             = student.Email,
                    FirstName         = student.FirstName,
                    LastName          = student.LastName,
                    Alias             = ('s' + contactKey.right(7)).left(8),
                    CommunityNickname = 'stu.' + contactKey.right(12),
                    ContactId         = student.Id,
                    ProfileId         = portalProfile.Id,
                    TimeZoneSidKey    = 'Europe/London',
                    LocaleSidKey      = 'en_GB',
                    EmailEncodingKey  = 'UTF-8',
                    LanguageLocaleKey = 'en_US'
                ));
            }
            insert newUsers;

            // Permission set + Salesforce's own set-your-password email.
            if (!newUsers.isEmpty()) {
                Id permSetId = [
                    SELECT Id FROM PermissionSet WHERE Name = :PORTAL_PERM_SET LIMIT 1].Id;
                List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
                for (User u : newUsers) {
                    assignments.add(new PermissionSetAssignment(
                        AssigneeId = u.Id, PermissionSetId = permSetId));
                    existingByContact.put(u.ContactId, u);
                }
                insert assignments;

                if (!Test.isRunningTest()) {
                    for (User u : newUsers) {
                        System.resetPassword(u.Id, true);   // emails the set-password link
                    }
                }
            }

            sendWelcomeEmails(studentsById, existingByContact);
        }

        private void sendWelcomeEmails(Map<Id, Contact> studentsById,
                                       Map<Id, User> userByContact) {
            String loginUrl = resolveLoginUrl();

            List<Messaging.SingleEmailMessage> emails =
                new List<Messaging.SingleEmailMessage>();
            for (Contact student : studentsById.values()) {
                User portalUser = userByContact.get(student.Id);
                if (portalUser == null) {
                    continue;
                }
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setTargetObjectId(student.Id);   // sends to the contact's email
                mail.setSaveAsActivity(false);
                mail.setSubject('Your CareerLaunch student portal access');
                mail.setPlainTextBody(
                    'Hi ' + student.FirstName + ',\n\n'
                  + 'Thank you - your payment has been received, and your CareerLaunch '
                  + 'student portal access is ready.\n\n'
                  + 'Login page: ' + loginUrl + '\n'
                  + 'Username:   ' + portalUser.Username + '\n\n'
                  + 'First time here? We have also sent you a separate email with a link '
                  + 'to set your password (check your spam folder). Already have a '
                  + 'password? Just log in as usual.\n\n'
                  + 'In the portal you can track your enrolments and invoices, and '
                  + 'download your certificate once you complete your course.\n\n'
                  + 'The Oxfordable Careers team');
                emails.add(mail);
            }
            if (!emails.isEmpty()) {
                Messaging.sendEmail(emails, false);
            }
        }

        private String resolveLoginUrl() {
            try {
                Network site = [SELECT Id FROM Network WHERE Name = :SITE_NAME LIMIT 1];
                return Network.getLoginUrl(site.Id);
            } catch (Exception e) {
                return 'the CareerLaunch portal (link provided by our team)';
            }
        }
    }
}
