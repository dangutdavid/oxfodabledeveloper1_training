# Oxfordable CareerLaunch

A Salesforce Cohort Enrolment & Student Success application, built end to end as the
Oxfordable Careers **Salesforce Developer Introductory Programme** (3-week intensive) project.

## What is in here

| Layer | Components |
|---|---|
| Data model | `Course__c`, `Cohort__c`, `Enrolment__c` (+ `Contact.Total_Enrolments__c`), roll-up summary, formulas, 2 validation rules |
| Automation | `Enrolment_Confirmed_Actions` (record-triggered flow), `Quick_Enrol_Student` (screen flow), `Cohort_Start_Reminder` (scheduled flow) |
| Apex | `EnrolmentTrigger` + `EnrolmentTriggerHandler` (capacity + duplicate rules, bulk-safe), `StudentSummaryQueueable`, `CohortAvailabilityService` + `EnrolmentStatusService` (invocable, used by Flow & Agentforce), `CohortController` + `EnrolmentController` (LWC) |
| UI | `cohortExplorer`, `enrolmentPanel`, `enrolmentConsole` LWCs on the **Enrolment Console** app page |
| AI | Two invocable Apex actions ready to be wired to an Agentforce agent (see docs) |
| Quality | `TestDataFactory`, `EnrolmentTriggerTest`, `CohortServicesTest` (bulk, negative and async tests) |
| Delivery | `Enrolment_Console_User` permission set, `manifest/package.xml`, `scripts/apex/seed.apex` |

## Deploy

```bash
sf org login web --alias devorg
sf project deploy start --source-dir force-app --target-org devorg --test-level RunLocalTests
sf org assign permset --name Enrolment_Console_User --target-org devorg
sf apex run --file scripts/apex/seed.apex --target-org devorg
```

Post-deploy: activate the **Enrolment Console** app page in Lightning App Builder, check
email deliverability is *All Email*, and build the Agentforce agent from the build sheet
in the step-by-step guide (`docs/`).

## User stories delivered

US-01 to US-14 of the CareerLaunch backlog - data model, seat-capacity enforcement,
duplicate prevention, welcome automation, auto-Full status, Quick Enrol wizard,
pre-start reminders, Enrolment Console, agent actions, async contact roll-up, tests
at 75%+ coverage and a CLI deployment.
