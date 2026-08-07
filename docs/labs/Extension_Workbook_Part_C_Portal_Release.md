# OXFORDABLE CAREERS — EXTENSION PACK · PART C OF 3 · PARTICIPANT WORKBOOK

# The Student Portal, Testing & Release

**Salesforce Developer Extension Programme · Labs 14 and 15 · UAT and completion**

Name: ______________________  Cohort: ______________________  Date: ______________________

### Before you start — checklist

☐ Parts A and B are complete: error logging, invoices raising automatically, stub payments working, certificates generating.
☐ VS Code with the Salesforce Extension Pack is connected to my org (you **must** use VS Code in Lab 14 — Lightning Web Components cannot be created in Setup).
☐ I have one enrolment with a **Sent** (unpaid) invoice, and one **Completed** enrolment with a certificate file.

---

# LAB 14 · 75 MINUTES · HANDS-ON
## The Experience Cloud Student Portal

*Give students their own login: a public-facing site where each student sees only their own enrolments and invoices, pays with one click, and downloads their certificate.*

### The security model — understand it before you build it

The portal never trusts the browser. Three rules, enforced in the controller
you are about to install:

1. Every query starts from **the logged-in user's Contact** — the client never sends "whose data" as a parameter, so student A cannot request student B's records.
2. `payInvoice` **re-checks ownership on the server** before any money moves, whatever id the browser sent.
3. The controller is `without sharing` — deliberately, with a comment explaining why: `Enrolment__c` is a master-detail child (its sharing is controlled by its parent Cohort, which has no contact field), so Experience Cloud *sharing sets cannot reach it*. Row-level privacy therefore lives in the contact-scoped `WHERE` clauses instead. Being able to explain that trade-off is a genuinely senior answer.

### Step 1 — The portal controller

Create Apex class `StudentPortalController` — **code pack item 14.1**. Read it
and find: the `resolveContactId()` method (from `UserInfo.getUserId()` → `User.ContactId`),
the two `@AuraEnabled(cacheable=true)` read methods returning small **view
wrapper** classes rather than raw SObjects, the ownership `COUNT()` check inside
`payInvoice`, and the `@TestVisible contactIdOverride` used by Lab 15's tests.

☐ Compiles

### Step 2 — The two Lightning Web Components

In VS Code: **View → Command Palette → `SFDX: Create Lightning Web Component`.**

1. Name the first `studentEnrolments`, folder `force-app/main/default/lwc`. Replace the three generated files (`.html`, `.js`, `.js-meta.xml`) with **code pack item 14.2**.
2. Repeat for `studentInvoices` with **code pack item 14.3**.
3. Deploy both: right-click the `lwc` folder → **SFDX: Deploy Source to Org** (or `sf project deploy start -d force-app/main/default/lwc`).

Read the code and find:

- `import labelPayNow from '@salesforce/label/c.Portal_Pay_Now'` — your Lab 11 labels arriving in JavaScript; the component re-renders in the viewer's language with zero extra code;
- in the meta XML: `<target>lightningCommunity__Page</target>` — **this line is what makes the component appear in Experience Builder**;
- `studentInvoices` uses the Week 3 pattern pair: `@wire` for reading, imperative Apex + `refreshApex` for the Pay now write;
- the certificate link is simply `/sfc/servlet.shepherd/document/download/<documentId>` — the platform's own file-download URL.

☐ Both components deployed

### Step 3 — The Student Portal permission set

**Setup → Permission Sets → New.**

| Setting | Value |
|---|---|
| Label | `Student Portal User` |
| API Name | `Student_Portal_User` |
| Description | Read-only portal access: own enrolments, invoices and certificates. Payments are written by PaymentService in system mode. |

Then, inside the new permission set:

1. **Apex Class Access → Edit** → add `StudentPortalController` only. (The classes it calls internally do not need access — only the entry point does.)
2. **Object Settings** → grant **Read** (nothing else) on: **Courses**, **Cohorts**, **Enrolments**, **Invoices** — and within each, Field Permissions → **Read** on every field.

> Students get no Create/Edit anywhere. The only thing that ever writes on
> their behalf is `PaymentService`, in system mode, after the gateway says yes.

☐ Permission set saved

### Step 4 — Turn on Digital Experiences

1. **Setup → Quick Find `Digital Experiences` → Settings** → tick **Enable Digital Experiences**.
2. Accept or adjust the suggested domain → Save.
3. Back on the same page, tick **Allow using standard external profiles for self-registration, user creation, and login** → Save. *(Skip this and Step 7 fails with a FIELD_INTEGRITY error — write that down.)*

☐ Both settings enabled

### Step 5 — Create and build the site

1. **Setup → Digital Experiences → All Sites → New.**
2. Pick a template (**Build Your Own (LWR)** is the leanest; any template works) → name it `CareerLaunch Portal` → Create. Wait for provisioning.
3. From All Sites click **Builder** next to the new site.
4. In Builder, click the **Components** icon (⚡, top of the thin left toolbar). Scroll to **Custom Components** — `Student Enrolments` and `Student Invoices` are there because of the `lightningCommunity__Page` target.
5. Drag **Student Enrolments** and **Student Invoices** onto the Home page, side by side. Delete the template's placeholder banners/forms if you want a clean page.
6. **Preview** — you will see *"Your user is not linked to a student record."* **That is the component working correctly**: you are previewing as an admin who has no Contact. Real data appears in Step 8.
7. Click **Publish** (top right) and confirm. Publishing also activates the site.

☐ Site published with both components

### Step 6 — Make the org able to own portal users

Two one-time administrative facts about Experience Cloud, both exam-worthy:

- a portal user's **account owner must have a role**;
- the portal **profile must be a member of the site**.

1. **Setup → Quick Find `Roles` → Set Up Roles** → Expand → **Add Role** anywhere sensible (e.g. under CEO): Label `CareerLaunch Admin` → Save. Then **Setup → Users → your user → Edit → Role** = CareerLaunch Admin → Save.
2. In **Experience Builder → (gear) Settings … Administration → Members**: under Profiles, search and add **Customer Community User** → Save. (If asked to publish again, publish.)

☐ Role assigned · profile is a site member

### Step 7 — Create the demo student's login

1. Create an Account named `Oxfordable Students` (portal contacts must belong to an account).
2. Create a Contact under it — e.g. `Amina Bello`, email `amina.bello@oxfordable.test`.
3. Enrol Amina (Status **Confirmed**) on an open cohort — Lab 12 raises her invoice automatically.
4. On Amina's Contact record, open the action menu (▾ top right) → **Enable Customer User**.
5. On the New User screen: Profile = **Customer Community User** · Username = something globally unique, e.g. `amina.bello@careerlaunch.portal` (a username only *looks* like an email — it does not need a mailbox) · Email = **your own real email**, so password mails reach you → Save.
6. Assign the permission set: **Setup → Permission Sets → Student Portal User → Manage Assignments → Add Assignment** → tick Amina Bello → Assign.
7. Set her password: open the email you received and follow the link, **or** Setup → Users → Amina Bello → **Reset Password**.

☐ Portal user exists, permission set assigned, password set

### CHECKPOINT — the full loop, as a student

1. Open a **private/incognito** browser window (so your admin session does not interfere).
2. Go to your site URL + `/login` (find the URL under All Sites — e.g. `https://<domain>.my.site.com/<path>/login`).
3. Log in as the portal user. You should see **My Enrolments** (Salesforce Developer — Confirmed) and **My Invoices** (one payable invoice with **Pay now**).
4. Press **Pay now** → toast *"Payment received - thank you!"* with a `STUB-…` reference → the badge flips to **Paid** and the button disappears.
5. As admin, verify the back end: invoice Paid + reference, enrolment Amount Paid = fee, **zero** rows in Error Logs.
6. Mark her enrolment **Completed** → the Lab 13 flow issues her certificate → back in the portal a **Download certificate** link appears. Download it.
7. Language bonus: Setup → Users → Amina → Edit → Language `Français` → reload the portal — *Mes inscriptions*, *Payer maintenant*. Switch back.

☐ Enrolments · payment · certificate · French — all proven from the student's side

### If you get stuck

| Problem | Fix |
|---|---|
| Components missing from Builder's panel | The `.js-meta.xml` must contain `lightningCommunity__Page` and `<isExposed>true</isExposed>`; redeploy, then hard-refresh Builder |
| *FIELD_INTEGRITY_EXCEPTION … standard external profiles* when saving the user | Step 4.3 was skipped — enable the setting, retry |
| *…account owner must have a role* | Step 6.1 was skipped |
| Portal login says user is locked/invalid | The profile is not a site member (Step 6.2), or the site is not published |
| Cards render but show the "not linked" message for the student | The user's ContactId is blank — you created a plain user instead of using **Enable Customer User** on the Contact |
| Cards error with "no access" | Permission set missing (Step 7.6) or `StudentPortalController` not in its Apex Class Access |
| Pay now fails with ownership error | You are logged in as the wrong portal user for that invoice — which means the security check works |

---

# LAB 15 · 60 MINUTES · HANDS-ON
## Tests, UAT & Release

*Prove all of it works, prove it keeps working, and ship it.*

### Step 1 — Extend the TestDataFactory

Open `TestDataFactory` and add the single-student helper method
`createStudent(String email)` — **code pack item 15.1** shows the exact method
to paste in. It matters because the payment tests need a student with a
*specific* email (remember: `declined@…` drives the stub's failure path).

☐ Factory compiles

### Step 2 — Create the five test classes

Create each class and enter the matching code pack item. After each one, run
just that class (VS Code: click *Run Test* above the class name, or
`sf apex run test --tests <Name> --result-format human --wait 10`).

| Class | Code pack | What it proves — read the assertions |
|---|---|---|
| `ErrorLoggerTest` | 15.2 | Apex, Flow and custom paths all end as `Error_Log__c` rows. Note `Test.getEventBus().deliver()` — that is how a test forces platform events to be processed |
| `CurrencyServiceTest` | 15.3 | Rates, 2-dp half-up rounding, the unknown-currency exception, formatting |
| `InvoicePaymentServicesTest` | 15.4 | Invoice auto-creation + idempotency; stub payment happy path, declined card, double-pay exception; the **HTTP client tested with `HttpCalloutMock`** (asserting the `callout:` endpoint and the idempotency header without any network); the factory + its `@TestVisible` override |
| `CertificateServiceTest` | 15.5 | File created and linked, flag ticked, never issued twice, the Flow invocable path. `Test.startTest()/stopTest()` forces the Queueable to run — Week 3 knowledge, reused |
| `StudentPortalControllerTest` | 15.6 | A student sees **only their own** records; pays their own invoice; and **cannot pay someone else's** — the security test that matters most |

☐ All five classes pass individually

### Step 3 — Full run with coverage

```
sf apex run test --code-coverage --result-format human --wait 10
```

Target: **everything green** (the original Week 3 tests must still pass — you
changed the trigger handler in Lab 12, and this run proves you broke nothing)
and overall coverage **75% or higher**; the reference build sits above 85%.

Write your numbers here:  Tests passed ______ / ______ · Coverage ________ %

☐ Green run at 75%+

### Step 4 — UAT script for the extension pack

Run each step in the org and tick it. This continues the Week 3 UAT table.

| ID | Feature | Test step | Expected result | Pass |
|---|---|---|---|---|
| UAT-16 | Error logging | Execute Anonymous: catch a divide-by-zero and call `ErrorLogger.log` | New `ERR-` record with type, source, message, stack trace | ☐ |
| UAT-17 | Error logging | Force a flow fault (e.g. Quick Enrol a full cohort) | The fault path writes an `ERR-` record with Source Type `Flow` | ☐ |
| UAT-18 | Invoicing | Confirm a new enrolment on a fee-paying course | One `Sent` invoice, fee amount, due +14 days | ☐ |
| UAT-19 | Invoicing | Edit and re-save that enrolment | Still exactly one invoice | ☐ |
| UAT-20 | Invoicing | Try to set an invoice to Paid with no reference | Validation rule blocks the save | ☐ |
| UAT-21 | Payments | Pay an invoice (portal button or Apex) | Paid + `STUB-` reference + Amount Paid updated on the enrolment | ☐ |
| UAT-22 | Payments | Pay an invoice for a `declined@…` student | Failure message; invoice stays Sent; nothing written | ☐ |
| UAT-23 | Payments | Pay the same invoice twice | Clear *already paid* error | ☐ |
| UAT-24 | Currency | Execute Anonymous: `CurrencyService.convertFromGBP(100,'USD')` | `127.00` (or 100 × your configured rate) | ☐ |
| UAT-25 | Certificates | Set an enrolment to Completed | PDF file on the record, Certificate Issued ticked, exactly once | ☐ |
| UAT-26 | Portal | Log in as the portal student | Sees only their own enrolments and invoices | ☐ |
| UAT-27 | Portal | Pay now in the portal | Success toast with reference; badge flips to Paid | ☐ |
| UAT-28 | Portal | Completed course in the portal | Download certificate link opens the PDF | ☐ |
| UAT-29 | i18n | Switch the portal user to French | Card titles and buttons render in French | ☐ |
| UAT-30 | Quality | Full test run | All pass, ≥75% coverage | ☐ |

### Step 5 — Version control

```
git add force-app docs
git commit -m "Extension pack: error logging, invoicing, payments, certificates, i18n, student portal"
git push origin main
git tag v2.0 && git push --tags
```

☐ Pushed and tagged

### Step 6 — Deploy to a second org (or a partner's)

The Week 3 routine, now with a longer post-deploy checklist because you have
learned that **deployment is never finished at "the deploy succeeded"**:

```
sf project deploy start --source-dir force-app --target-org targetorg --test-level RunLocalTests --dry-run
sf project deploy start --source-dir force-app --target-org targetorg --test-level RunLocalTests
```

Post-deploy checklist in the target org:

| # | Action | Done |
|---|---|---|
| 1 | Assign **both** permission sets to the admin user first — fresh metadata deploys grant no field-level security, and `WITH SECURITY_ENFORCED` queries fail until you do | ☐ |
| 2 | Confirm every Flow is **Active** (including `Issue_Certificate_On_Completion`) | ☐ |
| 3 | Load reference data — Courses, Cohorts, Contacts (records never deploy) | ☐ |
| 4 | If the target org has no French: either enable it (Translation Language Settings) before deploying, or deploy without the `translations` folder and add it later | ☐ |
| 5 | The Experience Cloud site is **clicks, not metadata** — repeat Lab 14 Steps 4–7 in the target org | ☐ |
| 6 | Smoke-test UAT-18, UAT-21 and UAT-26 in the target org | ☐ |

☐ Second org live

### Completion criteria — Extension Pack

| # | Evidence | Done |
|---|---|---|
| 1 | Error Logs tab capturing Apex, flow and integration failures | ☐ |
| 2 | Invoices raised automatically, exactly once, on confirmation | ☐ |
| 3 | Stub payments: success, declined and double-pay all handled, reference stored | ☐ |
| 4 | The stub→real switch explained out loud: Named Credential + one custom metadata edit | ☐ |
| 5 | Certificates: designed PDF, filed on the enrolment, issued exactly once, Flow-triggered | ☐ |
| 6 | Portal: student login sees only their data, pays, downloads their certificate | ☐ |
| 7 | French: portal and certificate both render translated | ☐ |
| 8 | Green test run ≥75% coverage including the five new test classes | ☐ |
| 9 | UAT-16 → UAT-30 all ticked | ☐ |
| 10 | Tagged release pushed to GitHub | ☐ |

### Add it to your portfolio write-up

Append to your Week 3 portfolio paragraph:

> *Extended the application with a payment layer built on an interface + custom-metadata factory (training stub and production HTTP client with named credential and idempotency key), automatic invoicing with frozen exchange rates, PDF certificate generation via async Visualforce rendering, a rollback-proof platform-event error-logging framework, custom-label internationalisation (English/French), and an Experience Cloud portal with contact-scoped, server-side-authorised self-service payments — all covered by the automated test suite.*

Every phrase maps to something you personally built. That is the whole point.

### Ten interview questions the Extension Pack prepares you to answer

1. How do you integrate with an external system you cannot call from your dev org?
2. What does a Named Credential give you that hard-coding a URL does not?
3. What is an idempotency key and why does a payment retry need one?
4. Why publish a platform event instead of inserting a log record directly?
5. Why must a callout happen before DML in the same transaction?
6. Where would you freeze an exchange rate, and why not compute it live?
7. Why can't a sharing set grant portal users access to a master-detail child object — and what did you do instead?
8. How does one LWC serve users in multiple languages?
9. Why is `PageReference.getContent()` banned in triggers, and what is the pattern instead?
10. Custom metadata vs custom settings vs custom objects for configuration — when each?

**— End of the Extension Pack. Your org now contains everything the Week 2 scope table once said was out of scope.**
