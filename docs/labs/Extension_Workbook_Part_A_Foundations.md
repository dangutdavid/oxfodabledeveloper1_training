# OXFORDABLE CAREERS — EXTENSION PACK · PART A OF 3 · PARTICIPANT WORKBOOK

# Error Logging, Invoicing Data Model & Multi-Currency

**Salesforce Developer Extension Programme · Labs 9, 10 and 11**

Name: ______________________  Cohort: ______________________  Date: ______________________

> In the Introductory Programme these features were **out of scope — on purpose**.
> Now you build them. Everything in Parts A, B and C extends the CareerLaunch org
> you already own: do not create a new org, and do not delete anything from Weeks 1–3.

---

## Welcome to the Extension Pack

Across three parts you will add five professional features to CareerLaunch:

| Part | Labs | You build |
|---|---|---|
| **A (this one)** | 9, 10, 11 | Org-wide error logging · the Invoice data model · multi-currency and multi-language |
| B | 12, 13 | Payment gateway integration (stubbed, with the real pattern) · certificate PDFs |
| C | 14, 15 | The Experience Cloud student portal · tests, UAT and release |

### How the code works in these labs

You will still build **every object, field, tab, label and setting yourself, with
clicks** — the steps are written out in full. For **Apex, Visualforce and LWC**,
each step names a **code pack item** (for example *code pack 9.1*). Ask your
instructor for that item when you reach the step, type or paste it exactly, and
read the comments — the comments explain *why* the code is shaped the way it is.

### Before you start — checklist

☐ My org contains everything from Weeks 1–3: Course, Cohort, Enrolment, the trigger, the flows, both LWCs, and the tests pass.
☐ I can log in and open **Setup**.
☐ VS Code + Salesforce CLI still work (`sf --version` returns a version).
☐ I have sample data: at least one Course with a Fee, one Open Cohort with seats, and Contacts with email addresses.

> **IF ANYTHING IS NOT TICKED** — fix it before Lab 9. Part A builds directly on
> the Week 2 data model and the Week 2 trigger.

---

# LAB 9 · 45 MINUTES · HANDS-ON
## Org-Wide Error Logging

*Build one front door for every error in the org — flows, triggers, Apex and integrations — that survives even when the failing transaction rolls back.*

### Why this lab comes first

Two classes you build later (the payment HTTP client in Lab 12 and the
certificate job in Lab 13) **call the logger you build now**. Build in order and
nothing ever fails to compile.

### The idea, in one paragraph

If a transaction fails and rolls back, a plain `insert Error_Log__c` rolls back
with it — the error erases its own evidence. So we never insert the log
directly. Instead the code **publishes a platform event** (which is set to
*publish immediately*, so it escapes the rollback), and a small trigger on that
event writes the permanent `Error_Log__c` record in a fresh transaction. This
is a real production pattern, word for word.

```
 Apex / Trigger / Flow fault path
            |
            v
      ErrorLogger  (Apex class - the only front door)
            |
            v   EventBus.publish - PUBLISH IMMEDIATELY
   Error_Log_Event__e  (platform event - survives rollback)
            |
            v   after insert
   ErrorLogEventTrigger  ->  Error_Log__c  (permanent record + tab)
```

### Step 1 — Create the Error Log object

**Setup → Object Manager → Create ▾ → Custom Object.**

| Setting | Value |
|---|---|
| Label / Plural Label | `Error Log` / `Error Logs` |
| Object Name | `Error_Log` |
| Record Name | `Error Number` |
| Data Type | Auto Number |
| Display Format | `ERR-{00000}` |
| Starting Number | `1` |
| Tick | Allow Reports · **Launch New Custom Tab Wizard after saving this custom object** |

Click **Save**. In the tab wizard pick any style you like (we used *Gears*),
then **Next → Next → Save**.

☐ Error Log object and tab created

### Step 2 — Add the Error Log fields

**Object Manager → Error Log → Fields & Relationships → New.** Repeat for each row.
On the field-level security and page layout screens, keep the defaults and click through.

| Field Label | Data Type | Settings | API name it creates |
|---|---|---|---|
| Source Type | Picklist | Values, one per line: `Apex`, `Trigger`, `Flow`, `Integration`. Tick **Restrict picklist to the values defined**. After saving, make `Apex` the default value | `Source_Type__c` |
| Source Name | Text | Length `255` | `Source_Name__c` |
| Error Message | Text Area (Long) | Length `32768`, Visible Lines `5` | `Error_Message__c` |
| Stack Trace | Text Area (Long) | Length `32768`, Visible Lines `10` | `Stack_Trace__c` |
| Record Id | Text | Length `18` | `Record_Id__c` |
| Severity | Picklist | Values, one per line: `Info`, `Warning`, `Error`, `Critical`. Restricted. Default value `Error` | `Severity__c` |

☐ Six fields created

### Step 3 — Create the platform event

**Setup → in Quick Find type `Platform Events` → Platform Events → New Platform Event.**

| Setting | Value |
|---|---|
| Label / Plural Label | `Error Log Event` / `Error Log Events` |
| Object Name | `Error_Log_Event` |
| Publish Behavior | **Publish Immediately** ← this is the whole point of the lab |

Click **Save**. Then, on the platform event's page, use **Custom Fields &
Relationships → New** to add these fields (platform events offer fewer types —
that is normal):

| Field Label | Data Type | Settings | API name it creates |
|---|---|---|---|
| Source Type | Text | Length `50` | `Source_Type__c` |
| Source Name | Text | Length `255` | `Source_Name__c` |
| Error Message | Text Area (Long) | Length `32768` | `Error_Message__c` |
| Stack Trace | Text Area (Long) | Length `32768` | `Stack_Trace__c` |
| Record Id | Text | Length `18` | `Record_Id__c` |
| Severity | Text | Length `20` | `Severity__c` |

> **PAUSE HERE — WHAT JUST HAPPENED**
> You created two nearly identical shapes on purpose. The **event** is the
> in-flight message (temporary, survives rollback); the **object** is the
> permanent record you can report on. The trigger in Step 5 copies one into
> the other.

☐ Platform event and six fields created

### Step 4 — Create the ErrorLogger class

In VS Code (or Developer Console → File → New → Apex Class), create a class
named exactly `ErrorLogger` and enter **code pack item 9.1**.

Read the code before moving on and find these three things:

- the **Apex entry points** — `ErrorLogger.log(e, 'ClassName')` overloads;
- the **Flow entry point** — an `@InvocableMethod` labelled **Log Flow Error**;
- the single private `publish(...)` method — every path ends in `EventBus.publish`, never `insert`.

Save. It must compile with no errors.

☐ `ErrorLogger` saved

### Step 5 — Create the event trigger

Create an Apex **trigger** (VS Code: create the file under `triggers/`;
Developer Console: File → New → Apex Trigger, sObject `Error_Log_Event__e`)
named exactly `ErrorLogEventTrigger`, and enter **code pack item 9.2**.

It is an `after insert` trigger on `Error_Log_Event__e` that loops the events
and inserts one `Error_Log__c` per event. Note it runs as the *Automated
Process* user, in its own transaction — which is why the log survives.

☐ `ErrorLogEventTrigger` saved

### Step 6 — Wire the flows' fault paths

Open **Setup → Flows → Quick_Enrol_Student**. For **every** Get and Create
element that has a Fault connector to your error screen:

1. Drag an **Action** element onto the fault path, **before** the error screen.
2. Search actions for **Log Flow Error** (this is your invocable from Step 4 — it appears under category *Oxfordable CareerLaunch*).
3. Set **Flow Name** = `Quick_Enrol_Student` (literal text) and **Error Message** = `{!$Flow.FaultMessage}`.
4. Save as a new version and **Activate**.

Repeat for `Enrolment_Confirmed_Actions` if you added fault paths there.

☐ Fault paths log errors

### CHECKPOINT — prove the rollback survival

Open **Developer Console → Debug → Open Execute Anonymous Window** and run:

```
try { Integer boom = 1 / 0; }
catch (Exception e) { ErrorLogger.log(e, 'CheckpointTest'); }
```

Now open your new **Error Logs** tab (App Launcher → Error Logs → list view
*All*). You should see **ERR-00001**: Source Type `Apex`, Source Name
`CheckpointTest`, message containing `Divide by 0`, and a stack trace.

☐ Error record exists — the pipeline works end to end

### If you get stuck

| Problem | Fix |
|---|---|
| `Log Flow Error` does not appear in Flow actions | `ErrorLogger` did not compile, or you missed the `@InvocableMethod` block — re-check code pack 9.1 |
| No Error_Log__c record after the checkpoint | Is `ErrorLogEventTrigger` **Active**? Setup → Apex Triggers. Also confirm the event's Publish Behavior is *Publish Immediately* |
| “Platform Events” missing from Quick Find | Type just `Platform`, or use Integrations → Platform Events |
| Field API names differ from the table | Delete and recreate the field — the code expects these names exactly |

---

# LAB 10 · 45 MINUTES · HANDS-ON
## The Invoice Data Model & Configuration Records

*Build the Invoice object that Lab 12 will automate, and the two Custom Metadata Types that make currency rates and the payment gateway admin-editable configuration instead of hard-coded values.*

### The design decision to say out loud

Invoice → Enrolment is **Master-Detail**. Why? An invoice is meaningless
without its enrolment; we want cascade delete; and sharing is controlled by the
parent — whoever may see the enrolment may see its invoices. (Same reasoning
you gave for Enrolment → Cohort in Week 2. Interviewers love this answer.)

### Step 1 — Create the Invoice object

**Setup → Object Manager → Create ▾ → Custom Object.**

| Setting | Value |
|---|---|
| Label / Plural Label | `Invoice` / `Invoices` |
| Object Name | `Invoice` |
| Record Name | `Invoice Number` |
| Data Type | Auto Number |
| Display Format | `INV-{00000}` |
| Starting Number | `0` (or `1` — cosmetic only) |
| Tick | Allow Reports · Allow Activities · **Launch New Custom Tab Wizard** |

Tab wizard: pick a style (we used *Bank*), **Next → Next → Save**.

☐ Invoice object and tab created

### Step 2 — Add the Invoice fields — in this order

The Master-Detail must be first. **Object Manager → Invoice → Fields & Relationships → New.**

| Field Label | Data Type | Settings | API name it creates |
|---|---|---|---|
| **Enrolment** | Master-Detail Relationship | Related To: **Enrolment**. Accept the sharing defaults. Related List Label: `Invoices` | `Enrolment__c` |
| Amount (GBP) | Currency | Length `12`, Decimals `2`, tick **Required** | `Amount__c` |
| Currency Code | Picklist | Values one per line: `GBP`, `USD`, `EUR`. Restricted. Default `GBP` | `Currency_Code__c` |
| Exchange Rate | Number | Length `12`, Decimals `6`, Default Value `1`. Description: *Rate frozen at issue time — 1 GBP = this many units of the invoice currency* | `Exchange_Rate__c` |
| Amount (Invoice Currency) | **Formula** → Number, 2 decimals | Formula: `Amount__c * Exchange_Rate__c` · Treat blank fields as zeroes | `Amount_In_Currency__c` |
| Status | Picklist | Values: `Draft`, `Sent`, `Paid`, `Cancelled`. Restricted. Default `Draft` | `Status__c` |
| Due Date | Date | — | `Due_Date__c` |
| Paid Date | Date | — | `Paid_Date__c` |
| Payment Reference | Text | Length `100`. Description: *Transaction id returned by the payment gateway* | `Payment_Reference__c` |

> **PAUSE HERE — WHY TWO AMOUNTS AND A FROZEN RATE**
> `Amount__c` is always GBP — the org's one true currency. The **rate is
> stamped onto the invoice when it is issued**, and the display amount is a
> formula from those two. Result: an admin can change tomorrow's rates without
> ever changing what an already-issued invoice is worth. Say that sentence in
> an interview and you sound like you have done finance work — because you have.

☐ Nine fields created

### Step 3 — Add the validation rule

**Object Manager → Invoice → Validation Rules → New.**

| Setting | Value |
|---|---|
| Rule Name | `Paid_Requires_Reference` |
| Error Condition Formula | `AND(ISPICKVAL(Status__c, "Paid"), ISBLANK(Payment_Reference__c))` |
| Error Message | `An invoice cannot be marked Paid without the gateway payment reference.` |

☐ Rule active

### Step 4 — Create the Exchange Rate custom metadata type

**Setup → in Quick Find type `Custom Metadata Types` → New Custom Metadata Type.**

| Setting | Value |
|---|---|
| Label / Plural Label | `Exchange Rate` / `Exchange Rates` |
| Object Name | `Exchange_Rate` |

Save, then on the type's page use **Custom Fields → New**:

| Field Label | Data Type | Settings | API name |
|---|---|---|---|
| Rate From GBP | Number | Length `12`, Decimals `6`, tick Required | `Rate_From_GBP__c` |
| Symbol | Text | Length `5` | `Symbol__c` |

Now click **Manage Exchange Rates → New** and create three records:

| Label | Exchange Rate Name | Rate From GBP | Symbol |
|---|---|---|---|
| `GBP` | `GBP` | `1.0` | `£` |
| `USD` | `USD` | `1.27` | `$` |
| `EUR` | `EUR` | `1.17` | `€` |

> Custom metadata records **deploy with your code** (ordinary custom object
> records do not). That is why configuration like rates belongs here and not
> in a custom object.

☐ Type, two fields, three records

### Step 5 — Create the Integration Setting custom metadata type

Same route: **New Custom Metadata Type.**

| Setting | Value |
|---|---|
| Label / Plural Label | `Integration Setting` / `Integration Settings` |
| Object Name | `Integration_Setting` |

Add one custom field:

| Field Label | Data Type | Settings | API name |
|---|---|---|---|
| Implementation Class | Text | Length `255`, Required | `Implementation_Class__c` |

Then **Manage Integration Settings → New**:

| Label | Integration Setting Name | Implementation Class |
|---|---|---|
| `Payment Gateway` | `Payment_Gateway` | `PaymentGatewayStub` |

> The class `PaymentGatewayStub` does not exist yet — you write it in Lab 12.
> That is fine: this record is just text until the factory reads it. This one
> record is the **switch** that will one day flip the org from the training
> stub to a real payment provider — with zero code changes.

☐ Type, field, one record

### Step 6 — Give staff access to Invoices

**Setup → Permission Sets → Enrolment Console User** (from Week 3):

1. **Object Settings → Invoices** → Edit → Object Permissions: tick **Read, Create, Edit** (not Delete) → in Field Permissions grant **Read** on every Invoice field and **Edit** on all except the two formulas/auto fields → Save.
2. Still in the permission set: **Object Settings → Invoices → Tab Settings** → tick **Available** and **Visible** → Save.

☐ Permission set updated

### CHECKPOINT

Open the **Invoices** tab → **New**. Pick any existing Enrolment, Amount `500`,
leave the rest defaulted, Save. Confirm: the record is `INV-0000x`, Currency
Code defaulted to `GBP`, Exchange Rate `1.000000`, **Amount (Invoice Currency)
= 500.00** (the formula fired). Now edit it: set Status = `Paid` and save — the
validation rule must block you because Payment Reference is empty. Delete this
test invoice afterwards.

☐ Both behaviours confirmed

### If you get stuck

| Problem | Fix |
|---|---|
| Master-Detail not offered | You are creating the field on the wrong object — it goes on **Invoice**, pointing to Enrolment |
| Formula field rejects the syntax | Field type must be **Formula → Number, 2 decimals**; check the API names spell exactly `Amount__c * Exchange_Rate__c` |
| Custom Metadata Type records have no New button | You are on the type definition page — click **Manage Records** first |
| Validation rule blocks every save | You typed `OR` instead of `AND`, or missed `ISPICKVAL` |

---

# LAB 11 · 40 MINUTES · HANDS-ON
## Multi-Currency Service & Multi-Language Labels

*Turn the rate records from Lab 10 into a reusable Apex service, and move every piece of student-facing text into Custom Labels so the app can speak French (or any language) without touching code.*

### Step 1 — Create the CurrencyService class

Create an Apex class named exactly `CurrencyService` and enter **code pack
item 11.1**. Read it and find:

- `getRate('USD')` → reads `Exchange_Rate__mdt.getInstance('USD')` — **no SOQL needed** for custom metadata;
- `convertFromGBP(amount, iso)` → multiply then round to 2 dp, half-up (money rounding);
- a custom exception for unknown currencies — failing loudly beats returning nonsense.

☐ `CurrencyService` compiles

### Step 2 — Quick test in Execute Anonymous

```
System.debug(CurrencyService.convertFromGBP(100, 'USD'));   // expect 127.00
System.debug(CurrencyService.format(1250, 'GBP'));          // expect £1,250.00
```

Check the debug log shows both values.

☐ Both correct

### Step 3 — Create the ten custom labels

**Setup → in Quick Find type `Custom Labels` → New Custom Label.** Create each
row exactly — Lab 13's certificate and Lab 14's portal import these **by name**,
so a typo here becomes a compile error later. Put `CareerLaunch` in Categories
for all of them.

| Name (exact) | Short Description | Value |
|---|---|---|
| `Certificate_Title` | Certificate title | `Certificate of Completion` |
| `Certificate_Awarded_To` | Awarded-to line | `This certificate is proudly awarded to` |
| `Certificate_Completion_Text` | Completion line | `for successfully completing` |
| `Certificate_Issued_On` | Issued-on line | `Issued on` |
| `Portal_My_Enrolments` | Portal card title | `My Enrolments` |
| `Portal_My_Invoices` | Portal card title | `My Invoices` |
| `Portal_Pay_Now` | Button | `Pay now` |
| `Portal_No_Records` | Empty state | `Nothing to show here yet.` |
| `Portal_Payment_Success` | Success toast | `Payment received - thank you!` |
| `Portal_Download_Certificate` | Download link | `Download certificate` |

☐ Ten labels created

### Step 4 — Enable French and translate

1. **Setup → Quick Find `Translation Language Settings` → Enable** Translation Workbench if prompted.
2. Click **Add**, Language: **French**, tick **Active**, add yourself as a translator, Save.
3. **Setup → Quick Find `Translate` → Translate**. Language: French · Setup Component: **Custom Labels**.
4. Double-click the *Translation* column next to each label and enter:

| Label | French translation |
|---|---|
| Certificate_Title | `Certificat de réussite` |
| Certificate_Awarded_To | `Ce certificat est fièrement décerné à` |
| Certificate_Completion_Text | `pour avoir terminé avec succès` |
| Certificate_Issued_On | `Délivré le` |
| Portal_My_Enrolments | `Mes inscriptions` |
| Portal_My_Invoices | `Mes factures` |
| Portal_Pay_Now | `Payer maintenant` |
| Portal_No_Records | `Rien à afficher pour le moment.` |
| Portal_Payment_Success | `Paiement reçu - merci !` |
| Portal_Download_Certificate | `Télécharger le certificat` |

5. Save.

> **HOW THIS PAYS OFF** — a label used in Visualforce as `{!$Label.Certificate_Title}`
> or imported into an LWC resolves **in the viewing user's language**,
> automatically. One codebase, every language you translate.

☐ French active and translated

### CHECKPOINT

On your own user (avatar → Settings → Language & Time Zone) switch **Language**
to `Français`. Reload — Setup is now in French. Switch back to English. (In
Lab 14 you will see the portal itself flip languages this way.)

☐ Language round-trip works

### Key terms from Part A

| Term | Meaning |
|---|---|
| Platform event | A publish/subscribe message on the event bus; *publish immediately* means it survives the publishing transaction's rollback |
| Custom Metadata Type | Admin-editable configuration records that **deploy with code** and are readable in Apex without SOQL |
| Frozen rate | Stamping the conversion rate onto the record at creation so later rate edits never rewrite history |
| Custom Label | A named piece of user-facing text, translatable per language, usable from Apex, Visualforce and LWC |
| Invocable method | Apex that Flow (and Agentforce) can call — here, the flow fault paths calling the logger |

**Next: Part B — the payment gateway (with the stub-to-real pattern) and certificate PDFs.**
