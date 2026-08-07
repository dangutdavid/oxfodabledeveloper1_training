# CareerLaunch — User Guide

How to use the CareerLaunch application, by role:
**§1 Enrolment staff** · **§2 Students (portal)** · **§3 Administrators**.

---

## 1. Enrolment staff (internal users)

You need the **Enrolment Console User** permission set.

### 1.1 Enrolling a student
1. Open the **Enrolment Console** page (App Launcher → Enrolment Console).
2. Browse courses and cohorts in the **Cohort Explorer** — each cohort shows
   *seats remaining*.
3. Select a cohort, pick the student, and press **Enrol**. Alternatively run
   the guided **Quick Enrol Student** flow.
4. Guard rails you may hit — both are expected behaviour:
   - *"This cohort is full…"* — capacity is enforced; choose another cohort.
   - *"That student is already enrolled on this cohort."* — duplicates are blocked.

### 1.2 Invoices
- The moment an enrolment becomes **Confirmed**, the system raises an invoice
  automatically: course fee, status **Sent**, due in **14 days**. You never
  create invoices by hand for standard fees.
- Find them on the **Invoices** tab or the *Invoices* related list on the
  enrolment. `INV-xxxxx` numbers are assigned automatically.
- **Paid** invoices always carry a *Payment Reference* from the gateway — an
  invoice cannot be saved as Paid without one (and normally the system sets it,
  not you).
- A free course (fee 0) produces no invoice. Cancelling an invoice
  (Status = Cancelled) allows a new one to be raised on the next confirmation.
- Foreign-currency invoices show the converted amount in *Amount (Invoice
  Currency)*; the exchange rate is locked in when the invoice is created, so
  later rate changes never alter existing invoices.

### 1.3 Certificates
- When a student finishes, set the enrolment Status to **Completed**. If the
  admin has wired the flow action (§3.4), the certificate PDF is generated
  automatically, attached to the enrolment under **Files**, and
  *Certificate Issued* is ticked.
- The student can download it themselves from the portal; you can also share
  the file from the enrolment record.
- A certificate is only ever generated once per enrolment.

### 1.4 When something goes wrong
- Check the **Error Logs** tab. Every failure from flows, triggers, Apex and
  the payment gateway lands there with the source, message, stack trace, the
  record involved, and a severity.
- Triage by severity: **Critical** (e.g. payment provider unreachable) first.
- Quote the `ERR-xxxxx` number when escalating to the admin/developer.

---

## 2. Students — the CareerLaunch portal

Log in with the link in your welcome email.

### 2.1 My Enrolments
Shows each course you are enrolled on: cohort, start date, and a status badge
(*Applied → Confirmed → Completed*). Once your certificate has been issued, a
**Download certificate** link appears — the PDF is yours to keep.

### 2.2 My Invoices
Each invoice shows the amount **in your invoice currency**, the due date, and a
status badge. Invoices awaiting payment show a **Pay now** button:

1. Press **Pay now**.
2. On success you'll see *"Payment received — thank you!"* with a payment
   reference — keep it for your records. The invoice flips to **Paid**.
3. If your card is declined, the invoice stays payable — check with your bank
   and try again. Retrying is always safe: the same invoice can never be
   charged twice.

The portal always shows **only your own** records, and it follows your language
setting (English and French are available today).

---

## 3. Administrators

### 3.1 Access
- Staff → assign permission set **Enrolment Console User**.
- Portal students → Contact (with an Account) → **Enable Customer User** →
  assign permission set **Student Portal User**.
- A **Sharing Set** on the community profile must grant Enrolment access where
  `Enrolment__c.Student__c = User.Contact` (invoices follow automatically).

### 3.2 Portal (one-time)
Setup → **Digital Experiences → Settings** → enable → create a site → in
Experience Builder add **Student Enrolments** and **Student Invoices** → publish.

### 3.3 Currencies & languages
- Rates live in **Custom Metadata → Exchange Rate** (GBP is the base and stays
  1.0). Editing a rate affects *future* invoices only.
- To add a currency: add the picklist value on `Invoice__c.Currency_Code__c` +
  an Exchange Rate record with the same code.
- Languages: enable French under **Translation Language Settings** (the
  translations are already deployed). Add further languages by translating the
  `Portal_*` / `Certificate_*` custom labels.

### 3.4 Certificate automation (one-time)
Add the action **Issue Completion Certificate** to a record-triggered flow on
Enrolment (when Status becomes *Completed*), passing the record Id.

### 3.5 Error logging in flows
For every flow, add the **Log Flow Error** action on fault paths, passing the
flow's name and `{!$Flow.FaultMessage}`. Apex and integrations log automatically.

### 3.6 Payments: stub vs real
Today the org runs a **simulated gateway** — perfect for training: any payment
succeeds instantly (a student email containing "declined" simulates a failed
card). To connect a real provider, see the *Going live* note at the end of
[TECHNICAL_GUIDE.md](TECHNICAL_GUIDE.md) — it is a metadata change only.
