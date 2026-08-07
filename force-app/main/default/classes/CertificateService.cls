/**
 * Turns the CertificatePdf page into a stored PDF file on the enrolment.
 *
 * PageReference.getContent() counts as a callout, so the render is done in a
 * Queueable (Database.AllowsCallouts) - never synchronously from a trigger.
 * Files are stored as ContentVersion with FirstPublishLocationId, which links
 * the document to the enrolment in the same insert.
 */
public with sharing class CertificateService {

    public class Request {
        @InvocableVariable(label='Enrolment Id' required=true)
        public Id enrolmentId;
    }

    @InvocableMethod(
        label='Issue Completion Certificate'
        description='Renders the certificate PDF for each enrolment and attaches it as a File.'
        category='Oxfordable CareerLaunch')
    public static void issueCertificates(List<Request> requests) {
        Set<Id> enrolmentIds = new Set<Id>();
        for (Request req : requests) {
            enrolmentIds.add(req.enrolmentId);
        }
        issue(enrolmentIds);
    }

    public static void issue(Set<Id> enrolmentIds) {
        if (enrolmentIds.isEmpty()) {
            return;
        }
        if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
            System.enqueueJob(new IssueJob(enrolmentIds));
        }
    }

    public class IssueJob implements Queueable, Database.AllowsCallouts {

        private Set<Id> enrolmentIds;

        public IssueJob(Set<Id> enrolmentIds) {
            this.enrolmentIds = enrolmentIds;
        }

        public void execute(QueueableContext context) {
            try {
                issueAll();
            } catch (Exception e) {
                // Async failures have no user watching - the log is the alarm.
                ErrorLogger.log(e, 'CertificateService.IssueJob');
            }
        }

        private void issueAll() {

            List<ContentVersion> certificates = new List<ContentVersion>();
            List<Enrolment__c>   toFlag       = new List<Enrolment__c>();

            for (Enrolment__c enr : [
                SELECT Id, Name, Certificate_Issued__c
                FROM Enrolment__c
                WHERE Id IN :enrolmentIds
                  AND Certificate_Issued__c = false
            ]) {
                certificates.add(new ContentVersion(
                    Title                  = 'Certificate ' + enr.Name,
                    PathOnClient           = 'certificate-' + enr.Name + '.pdf',
                    VersionData            = renderPdf(enr.Id),
                    FirstPublishLocationId = enr.Id
                ));
                toFlag.add(new Enrolment__c(Id = enr.Id, Certificate_Issued__c = true));
            }

            insert certificates;
            update toFlag;
        }

        private Blob renderPdf(Id enrolmentId) {
            PageReference page = Page.CertificatePdf;
            page.getParameters().put('id', enrolmentId);
            // getContent() is blocked inside unit tests, so tests receive a
            // placeholder blob and assert on the ContentVersion plumbing.
            return Test.isRunningTest()
                ? Blob.valueOf('TEST-PDF ' + enrolmentId)
                : page.getContent();
        }
    }
}
