# OXFORDABLE CAREERS — EXTENSION PACK · PART B OF 3 · PARTICIPANT WORKBOOK

# Payment Gateway Integration & Certificate PDFs

**Salesforce Developer Extension Programme · Labs 12 and 13**

Name: ______________________  Cohort: ______________________  Date: ______________________

### Before you start — checklist

☐ Part A is complete: the Error Logs pipeline works, the Invoice object exists with all nine fields, both Custom Metadata Types have their records, and the ten Custom Labels exist.
☐ `ErrorLogger` and `CurrencyService` compile.
☐ I have at least one Course with a Fee greater than 0, one Open Cohort, and Contacts with emails.

---

# LAB 12 · 60 MINUTES · HANDS-ON
## The Payment Gateway & Automatic Invoicing

*Build the full payment stack: an interface, a factory driven by custom metadata, a deterministic stub for training, a real HTTP client for production, and the services that raise and settle invoices. This is the single most interview-valuable lab in the programme.*

### The architecture you are about to build

```
        Enrolment saved as Confirmed
                   |
        EnrolmentTriggerHandler.onAfterChange        (one new line - step 8)
                   |
        InvoiceService.createForConfirmedEnrolments  -> Invoice__c (Sent, due +14 days)
                   ...
        somebody presses "pay" (Lab 14) or we call it from Apex
                   |
        PaymentService.payInvoice(invoiceId)
                   |
        PaymentGatewayFactory  --- reads ---> Integration_Setting__mdt.Payment_Gateway
             |                                        "PaymentGatewayStub"
             v
        IPaymentGateway  (the contract: one charge() method)
             |                     |
   PaymentGatewayStub     PaymentGatewayHttpClient
   (training orgs -        (production - POSTs to the
    no network call)        Payment_Gateway Named Credential)
```

> **THE SEAM PRINCIPLE — say this out loud**
> Everything above the interface knows nothing about HTTP. Everything below it
> knows nothing about enrolments. Swapping the stub for a real provider is a
> **custom metadata edit**, not a code change. This is how real teams stub an
> external system they cannot call from a training org — and it is the pattern
> the Week 2 scope table promised we would "stub and explain".

### Step 1 — Create the Named Credential

The credential owns the URL and (in production) the authentication secrets, so
Apex never contains either.

1. **Setup → Quick Find `Named Credentials` → Named Credentials.**
2. Open the dropdown next to New and choose **New Legacy** (the legacy form is simpler and fully deployable).
3. Fill in:

| Setting | Value |
|---|---|
| Label | `Payment Gateway` |
| Name | `Payment_Gateway` |
| URL | `https://api.payments.example.com` |
| Identity Type | Anonymous |
| Authentication Protocol | No Authentication |

4. Save.

> The URL is a placeholder — nothing will ever call it while the stub is
> configured. Going live one day = repoint this URL + set up its auth +
> change the Lab 10 metadata record. Nothing else.

☐ Named Credential created

### Step 2 — The two data carriers

Create two Apex classes, in this order:

1. `PaymentRequest` — **code pack item 12.1**. A plain bag of data (amount, currency, invoice number, student email, idempotency key). Notice it contains **no SObjects** — the gateway layer must not know our data model.
2. `PaymentResult` — **code pack item 12.2**. What every gateway returns: `success`, `transactionId`, `errorMessage`, plus two small factory methods `ok()` and `fail()`.

☐ Both compile

### Step 3 — The contract

Create Apex class `IPaymentGateway` — **code pack item 12.3**. It is an
**interface**: one method, `PaymentResult charge(PaymentRequest request)`, and
no implementation at all. Every caller from now on depends only on this.

☐ Compiles

### Step 4 — The stub (what this org will actually run)

Create Apex class `PaymentGatewayStub` — **code pack item 12.4**. Read it:

- amounts ≤ 0 are rejected (real gateways validate too);
- an email containing the word `declined` simulates a failed card — this gives you a repeatable way to demo failure;
- everything else succeeds with reference `STUB-<invoice number>-<currency>`.

Deterministic on purpose: every student in the cohort gets identical results.

☐ Compiles

### Step 5 — The factory

Create Apex class `PaymentGatewayFactory` — **code pack item 12.5**. Read it:

- it reads `Integration_Setting__mdt.getInstance('Payment_Gateway')` — the record you created in Lab 10;
- `Type.forName(className).newInstance()` turns that text into a running object;
- it verifies the class really implements `IPaymentGateway` and throws a clear error if an admin typo'd the record;
- the `@TestVisible gatewayOverride` variable is how tests inject a fake in Lab 15.

☐ Compiles

### Step 6 — The real HTTP client (production pattern, dormant here)

Create Apex class `PaymentGatewayHttpClient` — **code pack item 12.6**. You
will not run it against a real endpoint, but every line teaches something:

- endpoint is `callout:Payment_Gateway/v1/charges` — the **Named Credential name**, never a raw URL;
- the `Idempotency-Key` header: after a timeout you do not know if the charge happened; retrying with the same key means the provider de-duplicates and the student **cannot be charged twice**;
- the `CalloutException` catch calls `ErrorLogger.log(...)` with severity `Critical` — your Lab 9 pipeline, already earning its keep;
- the JSON wire format lives in private inner classes so nothing outside this file can depend on it.

☐ Compiles

### Step 7 — The two services

1. `InvoiceService` — **code pack item 12.7**. One job: for every enrolment that is **Confirmed**, raise one `Sent` invoice for the course fee, due in 14 days — but skip free courses, and skip enrolments that already hold a live (non-cancelled) invoice, so it is safe to call again and again. Note the bulk shape you learned in Week 2: collect ids → one query → build list → one insert.
2. `PaymentService` — **code pack item 12.8**. Loads the invoice, refuses to pay one that is already Paid or Cancelled, builds a `PaymentRequest`, asks the factory for the gateway, calls `charge()`, and only on success marks the invoice **Paid** (date + reference) and rolls the GBP amount into `Enrolment__c.Amount_Paid__c`. Two things to notice and be able to explain:
   - the **callout happens before any DML** — Salesforce forbids the reverse order;
   - the class is `without sharing` with a comment explaining why (a payment confirmation is a *system* action; the amount always comes from the invoice, never from the caller).

☐ Both compile

### Step 8 — One line in the trigger handler

Open `EnrolmentTriggerHandler` (from Week 2) and, inside `onAfterChange`, add
the call to `InvoiceService.createForConfirmedEnrolments(newEnrolments);`
directly after `enqueueStudentSummary(...)` — **code pack item 12.9** shows the
exact two lines (call + comment). Save.

> Why is this safe on every save? Because `InvoiceService` checks for an
> existing live invoice first. Idempotent automation — automation you can
> re-run without fear — is a professional habit.

☐ Handler updated and compiles

### CHECKPOINT 1 — the invoice raises itself

1. Create a new Enrolment: any Contact, any Open Cohort, Status **Confirmed**. Save.
2. Open the enrolment's **Invoices** related list (add the related list to the page layout if it is not there: Object Manager → Enrolment → Page Layouts → drag *Invoices* related list on).
3. You should see one invoice: Status `Sent`, Amount = the course fee, Due Date = today + 14, Exchange Rate = 1.
4. Edit the enrolment (change Attendance % to anything) and save again. Check: **still exactly one invoice**.

☐ Auto-invoice confirmed, idempotency confirmed

### CHECKPOINT 2 — pay it, and decline it

In **Execute Anonymous** (replace the id with your invoice's id from the URL):

```
PaymentResult r = PaymentService.payInvoice('a0X.....');
System.debug(r.success + ' / ' + r.transactionId);
```

Expected: `true / STUB-INV-0000x-GBP`. Refresh the invoice: Status **Paid**,
Paid Date today, Payment Reference filled. Open the Enrolment: **Amount Paid**
now equals the fee (and the Week 2 validation rule *Payment_Not_Above_Fee*
silently agreed).

Now the failure path: create a Contact whose email contains `declined`
(e.g. `declined@oxfordable.test`), enrol them as Confirmed, and pay their
invoice the same way. Expected: `false`, the invoice stays `Sent`, Amount Paid
stays 0. Run the paid one a second time and you get a clear
*already paid* exception.

☐ Success, decline and double-pay all behave

### If you get stuck

| Problem | Fix |
|---|---|
| `Invalid type: Integration_Setting__mdt` | The custom metadata type from Lab 10 is missing or misspelled |
| Factory throws *names a class that does not exist* | The Lab 10 record value must be exactly `PaymentGatewayStub` |
| `Callout not allowed` errors in checkpoint | You are somehow running the HTTP client — check the metadata record points at the stub |
| No invoice after confirming | Is the course Fee blank or 0? Free courses are never invoiced. Also check the handler edit compiled |
| Two invoices appeared | Your handler calls the service twice, or the service's existing-invoice query was mistyped |

---

# LAB 13 · 45 MINUTES · HANDS-ON
## Certificate PDF Generation

*Render a designed A4 certificate as a real PDF, store it as a File on the enrolment, and expose the whole thing as a Flow action.*

### The idea, in one paragraph

A Visualforce page with `renderAs="pdf"` is the platform's built-in,
no-extra-cost PDF engine. But turning that page into a **stored file** uses
`getContent()`, which Salesforce counts as a callout — so it is banned inside
triggers. The professional answer is the one you learned in Week 2: do it
**asynchronously**, in a Queueable that declares `Database.AllowsCallouts`.

```
Flow action "Issue Completion Certificate"  (or Apex)
        -> CertificateService.issue(ids)
              -> enqueues IssueJob (Queueable + AllowsCallouts)
                    -> renders Page.CertificatePdf via getContent()
                    -> inserts ContentVersion, FirstPublishLocationId = enrolment
                    -> ticks Certificate_Issued__c
                    -> any exception -> ErrorLogger (async has no user watching!)
```

### Step 1 — The page controller

Create Apex class `CertificateController` — **code pack item 13.1**. It reads
the `id` page parameter, queries the enrolment with its student, cohort and
course names, and exposes today's date. Nothing else — controllers for render
pages should stay thin.

☐ Compiles

### Step 2 — The Visualforce page

1. **Setup → Quick Find `Visualforce Pages` → New** (or in VS Code create `pages/CertificatePdf.page`).
2. Label: `Certificate PDF` · Name: **exactly** `CertificatePdf` (the Queueable references `Page.CertificatePdf`).
3. Replace the default markup with **code pack item 13.2**.

Read the markup and find: `renderAs="pdf"`, the A4-landscape `@page` CSS rule,
and the four `{!$Label.Certificate_...}` merge fields — your Lab 11 labels, so
a French-language student receives a French certificate.

**See it now:** open a browser tab at
`https://<your-domain>/apex/CertificatePdf?id=<an enrolment id>` — copy the 18-character
id out of any Enrolment record URL. A PDF should render in the browser.

☐ Page renders as PDF

### Step 3 — The service + queueable

Create Apex class `CertificateService` — **code pack item 13.3**. Read it and find:

- the `@InvocableMethod` labelled **Issue Completion Certificate** — the Flow entry point;
- the inner `IssueJob implements Queueable, Database.AllowsCallouts`;
- the query filters `Certificate_Issued__c = false` — a certificate can never be issued twice;
- `ContentVersion` with `FirstPublishLocationId = enrolment id` — this one field stores the file **and** links it to the record in a single insert;
- the whole job body wrapped in try/catch → `ErrorLogger` — async failures must never vanish silently;
- the `Test.isRunningTest()` guard, because `getContent()` is blocked inside unit tests (Lab 15 will rely on this).

☐ Compiles

### Step 4 — Wire it into automation

Give the org a rule: *when an enrolment is Completed, issue the certificate.*

1. **Setup → Flows → New Flow → Record-Triggered Flow.**
2. Object `Enrolment__c` · Trigger: **A record is created or updated** · Entry conditions: `Status__c` Equals `Completed` · run **Only when a record is updated to meet the condition requirements** · Optimise for **Actions and Related Records**.
3. Add one element — **Action** → search `Issue Completion Certificate` → set **Enrolment Id** = `{!$Record.Id}`.
4. (Recommended) Add a Fault connector from the action to a **Log Flow Error** action — flow name `Issue_Certificate_On_Completion`, message `{!$Flow.FaultMessage}`.
5. Save as `Issue_Certificate_On_Completion` → **Activate**.

☐ Flow active

### CHECKPOINT

1. Open a Confirmed enrolment (use one from Lab 12) and change Status to **Completed**. Save.
2. Wait a few seconds (the Queueable is asynchronous), refresh the record.
3. Confirm all three: **Certificate Issued** is now ticked · the **Files** related list holds `Certificate ENR-0000x` (add the Files related list to the layout if needed) · opening the file shows your designed PDF with the student's name, course and today's date.
4. Set the same enrolment's status away from and back to Completed. Confirm **no second file** appears.

☐ Certificate issued exactly once

### If you get stuck

| Problem | Fix |
|---|---|
| Page shows a blank/id error | The `?id=` parameter is missing or is not an Enrolment id |
| `Page CertificatePdf does not exist` compile error | The page name must be exactly `CertificatePdf` — no space |
| Status flipped but no file ever appears | Check the flow is **Active**; then check **Error Logs** — the try/catch will have logged the real cause |
| File appears but Certificate Issued stays unticked | The field update is in the same job — see Error Logs; usually a field-level security gap |
| PDF ignores your fonts/layout | Only a CSS subset is supported in `renderAs="pdf"` — stay with the provided stylesheet |

### Key terms from Part B

| Term | Meaning |
|---|---|
| Interface | An Apex contract with no implementation; callers depend on it instead of on concrete classes |
| Factory | A class whose only job is deciding *which* implementation to hand back — here, driven by custom metadata |
| Stub | A deterministic fake implementation used where the real system is unreachable or unwanted |
| Named Credential | Org-level record owning an endpoint URL + authentication; Apex refers to it as `callout:Name` |
| Idempotency key | A stable identifier sent with a charge so retries can never duplicate a payment |
| `renderAs="pdf"` | Visualforce attribute that renders the page through the platform's PDF engine |
| `ContentVersion` / `FirstPublishLocationId` | The Files object; setting the location id files-and-links the document in one insert |

**Next: Part C — the Experience Cloud student portal, then tests, UAT and release.**
