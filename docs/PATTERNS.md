# CareerLaunch — Feature Patterns Guide

This document explains the design behind the five feature areas added to the
CareerLaunch training app, and what is intentionally stubbed versus real.

---

## 1. Payment gateway integration & invoicing

### The flow
1. An `Enrolment__c` is saved with Status = **Confirmed** → `EnrolmentTriggerHandler.onAfterChange`
   calls `InvoiceService.createForConfirmedEnrolments`, which issues one **Sent**
   `Invoice__c` (course fee, 14-day terms) per enrolment that doesn't already
   hold a live invoice.
2. The student presses **Pay now** in the portal → `StudentPortalController.payInvoice`
   (ownership-checked) → `PaymentService.payInvoice`.
3. `PaymentService` builds a `PaymentRequest`, asks `PaymentGatewayFactory` for
   the org's gateway, calls `charge()`, and on success marks the invoice **Paid**
   and rolls the amount into `Enrolment__c.Amount_Paid__c`.

### The integration pattern (stub today, real tomorrow)
This is the classic **interface + factory + named credential** seam:

| Layer | Class | Job |
|---|---|---|
| Contract | `IPaymentGateway` | `PaymentResult charge(PaymentRequest)` — all callers depend only on this |
| Selection | `PaymentGatewayFactory` | Reads `Integration_Setting__mdt.Payment_Gateway` → `Type.forName()` → instance |
| Stub | `PaymentGatewayStub` | Deterministic fake: succeeds unless amount ≤ 0 or the email contains "declined" |
| Real | `PaymentGatewayHttpClient` | POSTs to `callout:Payment_Gateway/v1/charges` with an `Idempotency-Key` header |

**To go live** you change *zero* lines of Apex:
1. Point the `Payment_Gateway` Named Credential at the provider's real URL and
   configure its authentication (the credential owns secrets — Apex never sees them).
2. Edit the `Integration_Setting__mdt` record `Payment_Gateway`:
   `Implementation_Class__c` = `PaymentGatewayHttpClient`.
3. If the provider's JSON differs, write one new class implementing
   `IPaymentGateway` and point the setting at that instead.

**Why the idempotency key matters:** on a timeout you don't know whether the
charge happened. Retrying with the same key (`invoiceId + invoiceNumber`) lets
the provider de-duplicate, so a student can never be charged twice.

**Testing:** unit tests never hit the network. `PaymentGatewayFactory.gatewayOverride`
injects a fake; `HttpCalloutMock` exercises the real client's parsing.

---

## 2. Experience Cloud student portal

Code ships in the repo; the *site itself* is created in Setup (site metadata is
org-generated and not hand-authored):

1. **Setup → Digital Experiences → Settings** → enable, pick a domain.
2. **All Sites → New** → any template (e.g. *Build Your Own (LWR)* or *Customer
   Service*) → name it *CareerLaunch Portal*.
3. In Experience Builder, drag on the two components (exposed via
   `lightningCommunity__Page`): **Student Enrolments** and **Student Invoices**.
4. Create portal users: Contact → **Enable Customer User** (profile: Customer
   Community). Assign the **Student Portal User** permission set.
5. Publish.

Security model worth teaching:
- `StudentPortalController` derives the Contact from the **logged-in user** —
  the browser never says whose data to load.
- `payInvoice` re-checks ownership server-side before any money moves.
- Students are **read-only** (`Student_Portal_User` permset); the post-payment
  writes happen in `PaymentService`, which is `without sharing` because it is a
  system action, not a user edit.

---

## 3. Certificate PDF generation

- `CertificatePdf.page` is a Visualforce page with `renderAs="pdf"` — the only
  no-extra-cost PDF engine on platform.
- `CertificateService.issue()` runs a Queueable (`Database.AllowsCallouts`)
  because `PageReference.getContent()` counts as a callout and is banned in
  triggers. The PDF is stored as a `ContentVersion` with
  `FirstPublishLocationId = enrolment`, which files and links it in one insert.
- The enrolment is flagged `Certificate_Issued__c` and the portal surfaces a
  download link (`/sfc/servlet.shepherd/document/download/<docId>`).
- Call it from Flow with the **Issue Completion Certificate** action (e.g. when
  Status becomes Completed), or from Apex with a set of ids.
- `getContent()` is blocked in unit tests, so tests substitute a placeholder
  blob and assert on the file/link/flag plumbing instead.

---

## 4. Multi-currency & multi-language

### Currency (single-currency org pattern)
The org currency stays GBP. Display currencies come from `Exchange_Rate__mdt`
(GBP=1, USD, EUR) via `CurrencyService`. The rate is **frozen onto each invoice**
(`Exchange_Rate__c`) at issue time; `Amount_In_Currency__c` is a formula, so an
admin editing rates never changes an already-issued invoice.

> In an org with **native multi-currency** enabled you would instead use
> `CurrencyIsoCode` on every record plus dated conversion rates. Native
> multi-currency is an irreversible org setting — which is exactly why the
> custom-metadata pattern is common in real projects.

### Language
All user-facing text in the portal and the certificate comes from **Custom
Labels** (`Portal_*`, `Certificate_*`). LWCs import them via
`@salesforce/label/c.<Name>`; Visualforce uses `$Label.<Name>`. Each label
resolves in the viewing user's language automatically.

French translations ship in `translations/fr.translation-meta.xml`. Before they
deploy/apply, enable the language: **Setup → Translation Language Settings →
Add French**. (If French isn't enabled in the target org, deploy everything
else first and add the translation after.)

---

## 5. Error logging (flows, triggers, Apex)

**Objects:** `Error_Log__c` (durable record, tab *Error Logs*) and
`Error_Log_Event__e` (platform event, *publish immediately*).

**Why an event instead of a direct insert:** if the failing transaction rolls
back, a plain `insert Error_Log__c` rolls back with it — the error erases its
own evidence. A *publish-immediately* platform event escapes the rollback;
`ErrorLogEventTrigger` then persists it in a fresh transaction.

How each automation type uses it:
- **Apex / triggers:** `try { … } catch (Exception e) { ErrorLogger.log(e, 'ClassName', recordId); }`
  (see `CertificateService.IssueJob` for the async pattern).
- **Integrations:** `ErrorLogger.log('Integration', 'PaymentGatewayHttpClient', msg, stack, invoiceId, 'Critical')`
  (see the callout catch in `PaymentGatewayHttpClient`).
- **Flows:** drag the **Log Flow Error** action onto any fault path and pass
  the flow name + `{!$Flow.FaultMessage}`.

---

## Deploying

```bash
sf project deploy start -o <org> --test-level RunLocalTests   # prod-style
sf project deploy start -o <org>                              # sandbox/dev
```

Notes for a fresh Developer Edition org:
- The French translation file needs French enabled first (see §4).
- The Experience Cloud site is clicks, not metadata (see §2).
- The Named Credential deploys pointing at a placeholder URL — the stub gateway
  is what actually runs until `Integration_Setting__mdt` says otherwise.
