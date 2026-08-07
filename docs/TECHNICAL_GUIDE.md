# CareerLaunch — Technical Guide

Audience: developers and admins maintaining the org. For the *why* behind the
integration and currency patterns, see [PATTERNS.md](PATTERNS.md). For how to
use the system day to day, see [USER_GUIDE.md](USER_GUIDE.md).

---

## 1. Architecture at a glance

```
┌────────────────────────  Experience Cloud (students)  ───────────────────────┐
│  studentEnrolments LWC        studentInvoices LWC (Pay now)                  │
│              └──────────────┬───────────────┘                                │
│                   StudentPortalController  (without sharing, contact-scoped) │
└─────────────────────────────┼────────────────────────────────────────────────┘
                              │
┌───────────  Internal app (staff)  ───────────┐        ┌──── async ──────────┐
│ cohortExplorer / enrolmentPanel /            │        │ StudentSummary       │
│ enrolmentConsole LWCs                        │        │ Queueable            │
│      └── CohortController / EnrolmentController       │ CertificateService.  │
│                                              │        │ IssueJob (queueable) │
└───────────────┬──────────────────────────────┘        └──────────┬───────────┘
                │                                                  │
        Enrolment__c DML                                 CertificatePdf.page
                │                                        (renderAs="pdf")
        EnrolmentTrigger → EnrolmentTriggerHandler
                ├─ defaults, unique key, capacity check (before)
                ├─ StudentSummaryQueueable (after)
                └─ InvoiceService.createForConfirmedEnrolments (after)
                              │
                        Invoice__c
                              │
                     PaymentService.payInvoice
                              │ (callout BEFORE DML)
                    PaymentGatewayFactory ── Integration_Setting__mdt
                       ├── PaymentGatewayStub          (training orgs)
                       └── PaymentGatewayHttpClient ── Named Credential
                                                       "Payment_Gateway"

Errors from anywhere ──► ErrorLogger ──► Error_Log_Event__e (publish immediately)
                                              └─► ErrorLogEventTrigger ─► Error_Log__c
```

---

## 2. Data model

### Core objects (pre-existing)

| Object | Notes |
|---|---|
| `Course__c` | Name, `Course_Level__c` (**Introductory / Advanced** — restricted), `Fee__c`, `Duration_Weeks__c`, `Active__c` |
| `Cohort__c` | Master of Enrolment. `Capacity__c`, `Enrolled_Count__c` (roll-up), `Seats_Remaining__c` (formula), `Status__c`, dates |
| `Enrolment__c` | Detail of Cohort (auto-number `ENR-{00000}`). `Student__c` → Contact, `Status__c` (Applied/Confirmed/Waitlisted/Cancelled/Completed), `Amount_Paid__c`, `Certificate_Issued__c`, `Enrolment_Key__c` (unique, duplicate guard) |

### Invoice__c (new)

Master-detail child of `Enrolment__c` (sharing: controlled by parent). Auto-number `INV-{00000}`.

| Field | Type | Meaning |
|---|---|---|
| `Amount__c` | Currency (required) | Fee in GBP, the org currency |
| `Currency_Code__c` | Picklist GBP/USD/EUR | Invoice display currency |
| `Exchange_Rate__c` | Number(12,6), default 1 | Rate **frozen at issue time** (1 GBP = X units) |
| `Amount_In_Currency__c` | Formula | `Amount__c * Exchange_Rate__c` — what the student pays |
| `Status__c` | Draft / Sent / Paid / Cancelled | Lifecycle |
| `Due_Date__c`, `Paid_Date__c` | Date | Issue +14 days; set on payment |
| `Payment_Reference__c` | Text(100) | Gateway transaction id — proof of payment |

Validation: `Paid_Requires_Reference` — an invoice cannot be Paid without a gateway reference.

### Error_Log__c + Error_Log_Event__e (new)

`Error_Log__c` (auto-number `ERR-{00000}`): `Source_Type__c` (Apex/Trigger/Flow/Integration),
`Source_Name__c`, `Error_Message__c`, `Stack_Trace__c`, `Record_Id__c`, `Severity__c`
(Info/Warning/Error/Critical). `Error_Log_Event__e` mirrors these fields as a
**publish-immediately** platform event — the event escapes transaction rollback,
then `ErrorLogEventTrigger` persists it.

### Custom metadata (new)

| Type | Records | Purpose |
|---|---|---|
| `Exchange_Rate__mdt` | GBP=1.0, USD=1.27, EUR=1.17 (+ `Symbol__c`) | Display-currency rates, editable by admins |
| `Integration_Setting__mdt` | `Payment_Gateway` → `PaymentGatewayStub` | Which `IPaymentGateway` class the factory instantiates |

---

## 3. Apex inventory

### Services

| Class | Sharing | Responsibility |
|---|---|---|
| `InvoiceService` | inherited | Issues one Sent invoice per newly Confirmed enrolment (skips free courses and enrolments that already hold a live invoice). Called from the trigger |
| `PaymentService` | **without** | `payInvoice(id)`: load → validate state → gateway callout → mark Paid + roll into `Amount_Paid__c`. Deliberately system-mode: portal students are read-only; the amount always comes from the invoice, never the caller |
| `CurrencyService` | with | `getRate / convertFromGBP / format` over `Exchange_Rate__mdt`; throws `UnknownCurrencyException` |
| `CertificateService` | with | Invocable ("Issue Completion Certificate") + `issue(Set<Id>)`; inner `IssueJob` queueable (`Database.AllowsCallouts`) renders the VF page, stores `ContentVersion` with `FirstPublishLocationId`, flags `Certificate_Issued__c` |
| `ErrorLogger` | without | `log(e, source[, recordId])`, `log(type, source, msg, stack, recordId, severity)`, invocable "Log Flow Error". All paths publish `Error_Log_Event__e` |

### Payment gateway layer

| Class | Role |
|---|---|
| `IPaymentGateway` | Contract: `PaymentResult charge(PaymentRequest)` |
| `PaymentRequest` / `PaymentResult` | Plain DTOs — no SObjects, no HttpResponse leak |
| `PaymentGatewayFactory` | `Integration_Setting__mdt` → `Type.forName()`; `@TestVisible gatewayOverride` for injection; throws `GatewayConfigException` on misconfiguration |
| `PaymentGatewayStub` | Deterministic: fails on amount ≤ 0 or email containing "declined"; returns `STUB-<invoice>-<ccy>` |
| `PaymentGatewayHttpClient` | POST `callout:Payment_Gateway/v1/charges`, `Idempotency-Key` header, 20 s timeout; CalloutException → logged Critical + failure result |

### Controllers

| Class | Consumers |
|---|---|
| `CohortController`, `EnrolmentController` | Internal LWCs (pre-existing) |
| `StudentPortalController` | Portal LWCs. Contact resolved from `UserInfo` (`@TestVisible contactIdOverride` for tests); `payInvoice` re-checks ownership server-side before delegating to `PaymentService` |
| `CertificateController` | `CertificatePdf.page` (`?id=<enrolmentId>`) |

### Trigger handlers

- `EnrolmentTriggerHandler` — before: defaults, unique key, bulk-safe capacity check.
  after: `StudentSummaryQueueable` + `InvoiceService.createForConfirmedEnrolments`
  (idempotent — the existing-invoice query makes trigger re-fires no-ops).
- `ErrorLogEventTrigger` — persists error events (runs as Automated Process user).

---

## 4. UI

| Component | Targets | Notes |
|---|---|---|
| `studentEnrolments` | Community + internal pages | Wire to `getMyEnrolments`; certificate download link `/sfc/servlet.shepherd/document/download/<docId>` |
| `studentInvoices` | Community + internal pages | Wire + imperative `payInvoice`, `refreshApex` after payment; all text from Custom Labels |
| `CertificatePdf.page` | — | A4 landscape, pure CSS; text via `$Label.*` so it renders in the recipient's language |

All portal-facing strings are Custom Labels (`Portal_*`, `Certificate_*`);
French translations in `translations/fr.translation-meta.xml` (requires French
enabled under Translation Language Settings before they apply).

---

## 5. Security model

- **Staff**: `Enrolment_Console_User` permission set — CRU on Course/Cohort/Enrolment,
  CRU on Invoice (no delete), tabs incl. Invoices, all controller classes.
- **Students**: `Student_Portal_User` — read-only objects/fields + `StudentPortalController`
  only. Post-payment writes happen in `PaymentService (without sharing)` as a
  deliberate system action.
- **Record access for portal users**: sharing sets cannot target `Enrolment__c`
  (master-detail child of Cohort, which has no contact field), so
  `StudentPortalController` runs `without sharing` and enforces row-level
  privacy itself — every query is scoped to the logged-in user's Contact and
  `payInvoice` re-checks ownership before any write.
- Fresh-org gotcha: metadata deploys grant **no FLS**. Assign both permission
  sets to the admin user or `WITH SECURITY_ENFORCED` queries throw.

---

## 6. Tests

37 tests, all green in `agentforceDev` (run `sf apex run test --test-level RunLocalTests`).

| Class | Covers |
|---|---|
| `InvoicePaymentServicesTest` | Invoice auto-creation + idempotency, stub payment happy/declined/double-pay, HTTP client via `HttpCalloutMock` (asserts Named-Credential endpoint + idempotency header), factory wiring |
| `StudentPortalControllerTest` | Contact scoping, currency display, pay-own-invoice, **rejects another student's invoice** |
| `CertificateServiceTest` | File + link + flag plumbing, skip-already-issued, invocable path (`getContent()` is stubbed in tests) |
| `CurrencyServiceTest` | Rates, rounding, unknown currency, formatting |
| `ErrorLoggerTest` | Apex/flow/custom paths through event bus (`Test.getEventBus().deliver()`) |
| `EnrolmentTriggerTest`, `CohortServicesTest` | Pre-existing core (capacity, duplicates, async roll-up) |

Conventions: `TestDataFactory` for all data (`createStudent` bypasses duplicate
rules); gateway injected via `PaymentGatewayFactory.gatewayOverride`; portal
identity via `StudentPortalController.contactIdOverride`.

---

## 7. Deployment & environments

```bash
sf project deploy start -o <org>                      # dev/sandbox
sf project deploy start -o <org> -l RunLocalTests     # prod-style
sf org assign permset -n Enrolment_Console_User -n Student_Portal_User -o <org>
```

Current orgs: **agentforceDev** (default; Developer Edition,
`orgfarm-ac2163eff5-dev-ed.develop.my.salesforce.com`), pageProd, pageQA, pageUAT.

Post-deploy clicks (fresh org): enable Digital Experiences + build the portal
site, sharing set, optional French language, wire the certificate action into a
flow — full steps in [USER_GUIDE.md](USER_GUIDE.md) §Admin.

**Going live with payments** (no code changes): repoint the `Payment_Gateway`
Named Credential at the real provider + configure auth, then set
`Integration_Setting__mdt.Payment_Gateway.Implementation_Class__c = PaymentGatewayHttpClient`.
