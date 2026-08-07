public with sharing class EnrolmentTriggerHandler {

    @TestVisible
    private static final String ERR_FULL =
        'This cohort is full. Please choose another cohort or add the student to the waiting list.';

    // ---------- Entry points ----------
    public static void onBeforeInsert(List<Enrolment__c> newEnrolments) {
        setDefaults(newEnrolments);
        buildUniqueKey(newEnrolments);
        preventOverbooking(newEnrolments, null);
    }

    public static void onBeforeUpdate(List<Enrolment__c> newEnrolments,
                                      Map<Id, Enrolment__c> oldMap) {
        buildUniqueKey(newEnrolments);
        preventOverbooking(newEnrolments, oldMap);
    }

    public static void onAfterChange(List<Enrolment__c> newEnrolments) {
        enqueueStudentSummary(newEnrolments);
        // Confirmed enrolments get an invoice; the service skips any that
        // already hold a live one, so re-fires on unrelated edits are no-ops.
        InvoiceService.createForConfirmedEnrolments(newEnrolments);
    }

    // ---------- US-02: sensible defaults ----------
    private static void setDefaults(List<Enrolment__c> newEnrolments) {
        for (Enrolment__c enr : newEnrolments) {
            if (enr.Enrolment_Date__c == null) {
                enr.Enrolment_Date__c = Date.today();
            }
            if (String.isBlank(enr.Status__c)) {
                enr.Status__c = 'Applied';
            }
            if (enr.Amount_Paid__c == null) {
                enr.Amount_Paid__c = 0;
            }
        }
    }

    // ---------- US-05: duplicate prevention via a unique External ID ----------
    private static void buildUniqueKey(List<Enrolment__c> newEnrolments) {
        for (Enrolment__c enr : newEnrolments) {
            if (enr.Cohort__c != null && enr.Student__c != null) {
                enr.Enrolment_Key__c =
                    String.valueOf(enr.Cohort__c).left(15) + '-' +
                    String.valueOf(enr.Student__c).left(15);
            }
        }
    }

    // ---------- US-04: capacity enforcement, bulk safe ----------
    private static void preventOverbooking(List<Enrolment__c> newEnrolments,
                                           Map<Id, Enrolment__c> oldMap) {

        // 1. Work out which enrolments newly consume a seat, and how many per cohort.
        Map<Id, Integer> incomingSeatsByCohort = new Map<Id, Integer>();

        for (Enrolment__c enr : newEnrolments) {
            if (enr.Cohort__c == null) {
                continue;
            }
            Boolean consumesSeat = enr.Status__c != 'Cancelled';
            Boolean isNewlyConsuming;

            if (oldMap == null) {
                isNewlyConsuming = consumesSeat;                       // insert
            } else {
                Enrolment__c older = oldMap.get(enr.Id);
                Boolean wasConsuming = older.Status__c != 'Cancelled'
                                    && older.Cohort__c == enr.Cohort__c;
                isNewlyConsuming = consumesSeat && !wasConsuming;      // update
            }

            if (isNewlyConsuming) {
                Integer running = incomingSeatsByCohort.containsKey(enr.Cohort__c)
                    ? incomingSeatsByCohort.get(enr.Cohort__c) : 0;
                incomingSeatsByCohort.put(enr.Cohort__c, running + 1);
            }
        }

        if (incomingSeatsByCohort.isEmpty()) {
            return;
        }

        // 2. ONE query for every cohort involved - never inside the loop.
        Map<Id, Cohort__c> cohortsById = new Map<Id, Cohort__c>([
            SELECT Id, Name, Capacity__c, Enrolled_Count__c
            FROM Cohort__c
            WHERE Id IN :incomingSeatsByCohort.keySet()
        ]);

        // 3. Allocate seats in order and error on the ones that do not fit.
        Map<Id, Integer> allocated = new Map<Id, Integer>();

        for (Enrolment__c enr : newEnrolments) {
            if (enr.Cohort__c == null || !incomingSeatsByCohort.containsKey(enr.Cohort__c)) {
                continue;
            }
            Cohort__c cohort = cohortsById.get(enr.Cohort__c);
            if (cohort == null) {
                continue;
            }

            Decimal capacity  = cohort.Capacity__c == null ? 0 : cohort.Capacity__c;
            Decimal committed = cohort.Enrolled_Count__c == null ? 0 : cohort.Enrolled_Count__c;
            Integer used      = allocated.containsKey(enr.Cohort__c)
                                ? allocated.get(enr.Cohort__c) : 0;

            if (committed + used + 1 > capacity) {
                enr.addError(ERR_FULL);
            } else {
                allocated.put(enr.Cohort__c, used + 1);
            }
        }
    }

    // ---------- US-13: asynchronous aggregation onto the Contact ----------
    private static void enqueueStudentSummary(List<Enrolment__c> newEnrolments) {
        Set<Id> studentIds = new Set<Id>();
        for (Enrolment__c enr : newEnrolments) {
            if (enr.Student__c != null) {
                studentIds.add(enr.Student__c);
            }
        }
        if (studentIds.isEmpty()) {
            return;
        }
        // Respect the asynchronous job limit for the transaction.
        if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
            System.enqueueJob(new StudentSummaryQueueable(studentIds));
        }
    }
}
