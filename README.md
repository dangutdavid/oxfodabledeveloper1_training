# Oxfordable CareerLaunch

A Salesforce Cohort Enrolment & Student Success application, built end to end as the
Oxfordable Careers **Salesforce Developer Introductory Programme** (3-week intensive) project.

## What is in here

| Layer | Components |
|---|---|
| Data model | `Course__c`, `Cohort__c`, `Enrolment__c` (+ `Contact.Total_Enrolments__c`), `Invoice__c`, `Error_Log__c` (+ `Error_Log_Event__e` platform event), roll-up summary, formulas, validation rules |
| Automation | `Enrolment_Confirmed_Actions` (record-triggered flow), `Quick_Enrol_Student` (screen flow), `Cohort_Start_Reminder` (scheduled flow), auto-invoicing on confirmation |
| Apex | `EnrolmentTrigger` + `EnrolmentTriggerHandler` (capacity + duplicate rules, bulk-safe), `StudentSummaryQueueable`, `CohortAvailabilityService` + `EnrolmentStatusService` (invocable, used by Flow & Agentforce), `CohortController` + `EnrolmentController` (LWC) |
| Payments | `IPaymentGateway` → `PaymentGatewayFactory` (custom-metadata driven) → `PaymentGatewayStub` (training) / `PaymentGatewayHttpClient` (real, via Named Credential), `InvoiceService`, `PaymentService` |
| Portal | Experience Cloud components `studentEnrolments` + `studentInvoices` (Pay now), `StudentPortalController` (contact-scoped, ownership-checked) |
| Certificates | `CertificatePdf` Visualforce (renderAs=pdf) + `CertificateService` queueable → File on the enrolment, Flow action included |
| i18n | `Exchange_Rate__mdt` + `CurrencyService` (GBP base, rate frozen per invoice); Custom Labels with French translations |
| Error logging | `ErrorLogger` (Apex overloads + "Log Flow Error" invocable) → publish-immediately platform event → `Error_Log__c`, rollback-proof |
| UI | `cohortExplorer`, `enrolmentPanel`, `enrolmentConsole` LWCs on the **Enrolment Console** app page |
| AI | Two invocable Apex actions ready to be wired to an Agentforce agent (see docs) |
| Quality | `TestDataFactory` + 7 test classes (37 tests: bulk, negative, async, callout-mock, event-bus) |
| Delivery | `Enrolment_Console_User` + `Student_Portal_User` permission sets, `manifest/package.xml`, `scripts/apex/seed.apex` |

## Documentation

- [docs/TECHNICAL_GUIDE.md](docs/TECHNICAL_GUIDE.md) — architecture, data model, class inventory, security, tests, deployment
- [docs/USER_GUIDE.md](docs/USER_GUIDE.md) — staff, student-portal and administrator guides
- [docs/PATTERNS.md](docs/PATTERNS.md) — the *why*: integration seam (stub → real), multi-currency, error-event pattern
- `docs/CareerLaunch_Step_by_Step_Guide.*` — the 3-week build guide

## Deploy

```bash
sf org login web --alias devorg
sf project deploy start --source-dir force-app --target-org devorg --test-level RunLocalTests
sf org assign permset --name Enrolment_Console_User --name Student_Portal_User --target-org devorg
sf apex run --file scripts/apex/seed.apex --target-org devorg
```

Post-deploy: activate the **Enrolment Console** app page in Lightning App Builder, check
email deliverability is *All Email*, create the Experience Cloud portal site
(clicks-only — steps in the user guide §3), and build the Agentforce agent from the
build sheet in the step-by-step guide (`docs/`).

## User stories delivered

US-01 to US-14 of the CareerLaunch backlog - data model, seat-capacity enforcement,
duplicate prevention, welcome automation, auto-Full status, Quick Enrol wizard,
pre-start reminders, Enrolment Console, agent actions, async contact roll-up, tests
at 75%+ coverage and a CLI deployment — plus the extension pack: payment gateway &
invoicing, student portal, certificate PDFs, multi-currency/multi-language, and
org-wide error logging.
