---
layer: L2
node_type: domain
domain: health-primer
source: manual
last_synced: 2026-08-08
validated_by: Milan Chander
fidelity: HIGH
ghost_node_id: HEALTH-PRIMER
links_back:
  - knowledge/L1-enterprise/mivan-enterprise-context.md
links_forward:
  - knowledge/L2-domain/commercial-claims.md
  - knowledge/L2-domain/medicare-advantage.md
  - knowledge/L2-domain/medicaid-managed-care.md
  - knowledge/L2-domain/provider-data-lifecycle.md
audience: non-health technology professionals
---

# Healthcare for Technologists
## A Plain English Primer for Developers Joining a Health Payer Engagement

> This document exists for one reason:
> every developer who joins a health payer
> engagement without understanding the business
> context will eventually make a change that
> seems correct in isolation but breaks
> something important downstream.
>
> This primer will not make you a healthcare
> expert. It will give you enough context to
> ask the right questions before you write
> code — not after.

---

## 1. The Bigger Picture — What You Are Actually Building

### You Are Not Building Software. You Are Building Financial Infrastructure.

When a claim is processed incorrectly in a
retail system a customer gets the wrong
recommendation. When a claim is processed
incorrectly in a health payer system:

- A member does not get reimbursed for
  a medical procedure they paid for
- A provider does not get paid for services
  they rendered
- The health plan pays twice for the same service
- A Medicare or Medicaid overpayment triggers
  a federal audit
- A HIPAA violation exposes member health
  information

The code you write processes financial
transactions for millions of people's
healthcare. Every story you implement has
a real person on the other end.

### The Scale Is Different

Mivan processes approximately 4 million
commercial claims per day at peak. Each
claim touches:
- Member eligibility and benefits
- Provider network status and contracts
- Clinical coverage rules
- Prior authorization
- Coordination with other insurance
- State and federal regulations

A bug that affects 0.1% of claims affects
4,000 people per day.

### The Regulatory Environment Is Not Optional

Healthcare is one of the most heavily regulated
industries in the world. Unlike retail or banking
where regulations are complex but relatively stable:

- CMS (Centers for Medicare and Medicaid Services)
  publishes new rules annually that affect
  how claims must be processed
- HIPAA governs how health information can
  be stored, transmitted, and accessed
- Each state has its own prompt pay laws,
  timely filing rules, and claim requirements
- Violations are not just fines —
  they can result in loss of plan licensure

When a developer changes a denial code mapping,
adjusts a timely filing window, or modifies
how coordination of benefits is calculated —
they are changing something that is likely
governed by a specific regulation. That
regulation exists in L5 of this knowledge layer.

**Before you implement any story that touches
business rules — ask: what regulation governs this?**

---

## 2. The Most Important Concept — Lines of Business

### What Is a Line of Business

A Line of Business (LOB) in health insurance
is not just a label or a customer segment.
It is a completely different regulatory
environment, payment model, and set of rules.

Mivan has three lines of business:

| LOB | Who It Covers | Who Pays Mivan | Who Regulates It |
|---|---|---|---|
| Commercial | Employer groups and individuals | Employers and members via premiums | State insurance departments |
| Medicare Advantage | Medicare-eligible members (65+) | CMS via capitation | CMS — federal |
| Medicaid | Low-income and disabled members | State government via capitation | State + CMS — joint |

### Why This Matters to a Developer

**A business rule that is correct for Commercial
may be wrong — or illegal — for Medicare or Medicaid.**

Examples:

Prior authorization:
- Commercial: plan sets its own PA requirements
- Medicare Advantage: CMS limits what plans
  can require PA for — stricter rules since 2024
- Medicaid: state directs PA requirements —
  MCO cannot add requirements beyond state policy

Timely filing:
- Commercial: varies by provider contract —
  typically 90-365 days
- Medicare Advantage: CMS standard is 365 days
  from date of service — cannot be shorter
- Medicaid: state-specific — varies by state contract

Coordination of benefits:
- Commercial: birthday rule, active employment rule
- Medicare Advantage: Medicare Secondary Payer
  federal rules override state COB rules
- Medicaid: Medicaid is always payer of last resort —
  federal law, no exceptions

Overpayment recovery:
- Commercial: governed by provider contract
- Medicare Advantage: CMS 60-day rule —
  overpayment must be returned within 60 days
  of identification or interest accrues
- Medicaid: state-specific look-back periods

### The Developer Mistake This Causes

A developer receives a story:
"Update the timely filing window from 180 days to 365 days"

They update the configuration. Tests pass. Story closed.

What they did not ask:
- Which LOB does this apply to?
- Is 365 days the new requirement for all LOBs
  or just one?
- Does this change affect claims already in the
  suspense file?
- Is this driven by a regulatory change or a
  contract change?

If the change applied Commercial timely filing
rules to Medicare Advantage claims — and
Medicare Advantage is governed by CMS rules
that cannot be overridden — the plan is now
non-compliant with federal regulations.

**Every story that touches claim processing rules
must specify which LOB it applies to.
If the story does not say — ask before you code.**

---

## 3. How Healthcare Payment Actually Works

### The Four Parties

Every healthcare transaction involves four parties:

**Member** — the person receiving care.
They pay premiums to the health plan and
cost-sharing (deductible, copay, coinsurance)
at the time of service.

**Provider** — the doctor, hospital, or
other clinician delivering care. They submit
a claim to the health plan to get paid for
the services they rendered.

**Health Plan (Mivan)** — receives premiums,
processes claims, pays providers, manages
the member's benefits. This is the system
you are building.

**Government** — for Medicare and Medicaid,
the government (CMS or state) pays Mivan
a fixed monthly amount per member (capitation)
and sets the rules Mivan must follow.

### The Money Flow

**Commercial:**
```
Employer + Member → premium → Mivan → claim payment → Provider
Member → copay/deductible at time of service → Provider
```
Mivan earns money if premiums exceed claims + operating costs.
Mivan loses money if claims exceed premiums.
The risk of high utilization falls on Mivan.

**Medicare Advantage:**
```
CMS → fixed monthly capitation per member → Mivan → claim payment → Provider
Member → small copay → Provider
```
CMS pays Mivan a fixed amount per member per month regardless of how much
care that member uses. The amount is adjusted for how sick the member is
(risk adjustment — see the MA domain file). Mivan earns money if it manages
care efficiently within the capitation amount.

**Medicaid:**
```
State + Federal (FMAP match) → capitation → Mivan → claim payment → Provider
Member → very small or zero cost-sharing
```
Similar to Medicare Advantage but the payer is the state government, and
the federal government matches a portion of what the state spends
(the match rate is called FMAP — Federal Medical Assistance Percentage).

### What "Adjudication" Means

Adjudication is the process of deciding whether to pay a claim, how much
to pay, and who to pay it to. Think of it as the core business logic of
the health plan — the equivalent of an order fulfillment engine, except
instead of shipping a product it issues a payment or a denial.

Adjudication answers five questions for every claim:
1. Is the member eligible on the date of service?
2. Is the provider in-network and credentialed?
3. Is the service covered under the member's benefit plan?
4. Is there any other insurance that should pay first?
5. How much do we owe after applying deductible, copay, and coinsurance?

Each question has its own set of data dependencies, edit checks, and
business rules. The MiCPS adjudication engine (MADJDRV0) runs through
all of them in a defined sequence for every claim.

### Cost-Sharing — Deductible, Copay, Coinsurance

These are the amounts the member pays. As a developer you will encounter
them constantly in adjudication logic.

**Deductible** — the amount the member must pay out of pocket before
the plan starts covering costs. Example: $1,500 annual deductible means
the member pays the first $1,500 of medical bills each year; after that
the plan pays its share.

**Copay** — a fixed dollar amount the member pays per visit or service,
regardless of the total cost. Example: $25 copay for a primary care visit.

**Coinsurance** — a percentage the member pays after meeting the deductible.
Example: 20% coinsurance means the member pays 20% of the allowed amount
and the plan pays 80%.

**Out-of-Pocket Maximum** — the most the member will pay in a year.
Once reached, the plan covers 100% of covered services. The accumulator
that tracks how much the member has spent toward this limit is critical
adjudication state — in MiCPS it lives in the ACCUM-FILE VSAM.

**Why this matters to a developer:** Accumulator logic is stateful and
sequential. If the ACCUM-FILE is out of date when a claim is processed,
the member is charged incorrectly. Race conditions in accumulator updates
cause duplicate deductible charges — a real and serious defect.

### Why the Claim Is the Central Transaction

The claim is not just an invoice. It is:
- The financial record of what care was delivered
- The basis for provider payment
- The data that drives risk adjustment for MA
- The source for quality measurement reporting
- The audit trail for regulatory compliance
- The trigger for member cost-share calculation

When you change how a claim is processed
you are affecting all of these simultaneously.

---

## 4. The Claim Journey — Plain English

### Step 1: The Member Sees a Doctor

A Mivan commercial member visits their
primary care physician. The doctor sees
the member, documents the visit, and
assigns diagnosis codes (what was wrong)
and procedure codes (what was done).

### Step 2: The Claim Is Submitted

The doctor's office submits a claim to Mivan
electronically. The claim says:
- Who the member is
- Who the doctor is
- What date the visit happened
- What diagnosis codes apply
- What procedure codes were performed
- How much the doctor is charging

This comes in a standardized electronic
format called X12 837. Think of it like
a very structured JSON payload with
specific segments and loops defined by
a federal standard.

### Step 3: Mivan Validates the Claim

Before adjudicating the claim Mivan checks:
- Is the file format correct? (EDI validation)
- Is the member actually enrolled and active?
- Is the doctor in Mivan's system?
- Are the diagnosis and procedure codes valid?
- Do the codes make clinical sense together?
  (NCCI edits — you cannot bill for two
  procedures that are always done together
  as separate line items)

Think of this as input validation —
garbage in, garbage out. If the claim
fails these checks it is rejected back
to the provider before adjudication starts.

### Step 4: Adjudication

This is the core decision engine. Mivan determines:

**Is it covered?**
Does the member's plan cover this service?
Some services are excluded (cosmetic surgery,
experimental treatments). Some require
prior authorization before they can be approved.

**How much is payable?**
For in-network providers Mivan has a
contracted rate — a negotiated price per
procedure code. The doctor may charge $500
but if the contracted rate is $200 then
$200 is the allowed amount.

**What does the member owe?**
The member's cost-share (deductible, copay,
coinsurance) is subtracted from the allowed amount.
If the member has not yet met their $1,000
deductible then the first $200 comes from
the member, not Mivan.

**Is there other insurance?**
If the member has coverage through a spouse's
employer plan Mivan needs to coordinate with
that plan — this is Coordination of Benefits (COB).
The rules for who pays first are complex and
LOB-specific.

### Step 5: Payment

Mivan pays the provider via electronic funds
transfer (EFT) and sends an Electronic
Remittance Advice (ERA) — a machine-readable
explanation of what was paid, what was denied,
and why. The member gets an Explanation of
Benefits (EOB) showing what happened.

### Step 6: Post-Payment

After payment Mivan continues to monitor:
- Was the claim paid correctly?
  (Post-payment audit)
- Was the member actually eligible?
  (Retroactive eligibility changes)
- Did another payer also pay?
  (COB reconciliation)
- Was there fraud or billing abuse?
  (SIU investigation)

If an overpayment is found Mivan must
recover it from the provider. This is
tightly regulated — especially for
Medicare Advantage.

---

## 5. The Systems You Will Work With

### MiCPS — The Core System

MiCPS (Mivan Claims Processing System) is
the mainframe system that processes all of
this. It was built 30 years ago in COBOL
and has been extended ever since. It works —
processing 4 million claims per day — but
it is being modernized.

Think of MiCPS as a very large, very fast,
very reliable batch processing system. Most
claims processing happens overnight in large
batch runs. It is not a real-time API system —
it is a mainframe.

### The Modernization Program

Mivan is replacing MiCPS function by function
with cloud-native Java microservices on AWS.
You may be building one of those replacement
services.

**Critical point:** The Java service you
build must produce identical results to the
COBOL program it replaces — for the same input.
Before your service goes live it runs in
shadow mode alongside MiCPS, and every
output is compared. Any difference is an
error — even if the Java output seems
more correct.

Why? Because MiCPS has been processing
claims correctly under regulatory scrutiny
for 30 years. Your new service inherits
that obligation. You cannot change business
behavior during migration — only after.

---

## 6. The Five Things That Will Save You

### 1. Always Ask Which LOB

Every story, every change, every business rule —
ask which Line of Business it applies to.
Commercial, Medicare Advantage, and Medicaid
have different rules. If the story does not
specify — it is incomplete.

### 2. Understand the Downstream Impact

Claims processing is a pipeline. A change
to how eligibility is checked affects
adjudication. A change to adjudication
affects pricing. A change to pricing
affects payment. A change to payment
affects the 835 ERA sent to providers.
A change to the ERA affects the feeds
sent to SQL Server and S3.

Before you implement ask:
what is downstream of what I am changing?
The L3 system landscape and batch feed
dependency map in this knowledge layer
will tell you.

### 3. Read the Regulation Before the Story

Health payer business rules are not arbitrary.
Almost every rule exists because of a
regulation — CMS, HIPAA, state law, or
provider contract. Before you implement
a business rule change ask what regulation
it is based on. That regulation is in L5.

### 4. Never Change Behavior in Migration

If you are building a Java replacement for
a COBOL program your job is to replicate
the behavior exactly — not improve it.
Document what the COBOL does. Build exactly
that. Validate in shadow mode. Improvements
come in a separate story after cutover.

### 5. The Digital Brain Knows More Than You Do Right Now

This knowledge layer contains the context
you need. Before you ask a colleague —
ask the Digital Brain. It has the system
architecture, the business rules, the
program documentation, and the tribal
knowledge that would otherwise require
a meeting with a senior engineer.

When you hit something the Digital Brain
does not know — that is a ghost node.
Register it. That is how the knowledge
layer grows.

---

## 7. Common Mistakes — And How to Avoid Them

### Mistake 1: Treating a Story as Self-Contained

The story says:
"Update denial code CO-50 to include
non-covered services under the new
benefit exclusion list"

The developer updates the CARC mapping
table and closes the story.

What they missed:
- CO-50 also appears on the 835 ERA
  sent to providers — the provider's
  billing system expects this code
- CO-50 feeds the denial trend report
  used by the operations team
- Some provider contracts have dispute
  rights triggered by specific CARC codes
- The change may affect all LOBs
  but was only intended for Commercial

**How to avoid:** Before implementing any
change to a code, table, or business rule —
ask the Digital Brain "what depends on X?"
Use the impact assessment question class.

### Mistake 2: Assuming Healthcare Works Like Other Industries

A developer from banking assumes that
because a deductible is "met" the plan
pays 100%. They implement accordingly.

What they missed:
- Some plans have separate in-network
  and out-of-network deductibles
- Some plans have embedded vs aggregate
  family deductibles
- ACA requires certain preventive services
  to be covered at 100% before the deductible
- Some grandfathered plans predate ACA
  and have different rules

Healthcare has accumulated 60 years of
legislative and regulatory layers.
Assumptions imported from other industries
are frequently wrong.

**How to avoid:** When you think you
understand a rule — read it in L5.
If it is not in L5 it is a ghost node.
Register it and ask a domain expert.

### Mistake 3: Ignoring the Batch Window

A developer adds a real-time database
call inside a batch job. In testing it
works fine. In production it times out
at 2am when the batch window is running
on 4 million claims.

**How to avoid:** Understand the difference
between online (CICS) and batch (JCL)
processing in MiCPS. Read L3.
For cloud-native services — understand
that the equivalent distinction exists
between synchronous API calls and
async batch/event processing.

### Mistake 4: Not Understanding Retroactivity

A developer implements eligibility checking
that looks up the member's current status.
They do not handle the case where eligibility
changes retroactively.

What happens:
- Member was active when care was delivered
- Insurance company terminates coverage
  retroactively (happens more than you think)
- Claims already paid must be recovered
- New claims for the same member and dates
  must be denied

**How to avoid:** Read the retroactive
termination handling section in L4 Module 2.
Ask the Digital Brain: "How does MiCPS
handle retroactive eligibility changes?"

### Mistake 5: Treating PHI Like Regular Data

Protected Health Information (PHI) —
any data that identifies a member and
relates to their health — is governed
by HIPAA. The rules are strict:
- PHI cannot be logged to application logs
- PHI cannot appear in error messages
- PHI cannot be stored in non-encrypted form
- PHI cannot be transmitted without
  appropriate safeguards
- Access to PHI must be audited

A developer adds a debug log that includes
member ID and diagnosis code. That is a
HIPAA violation. The plan must report it.

**How to avoid:** Treat every field that
could identify a member combined with
any health information as PHI.
When in doubt — do not log it.
Ask your compliance team.

---

## 8. Your First Week — What to Do

**Day 1:** Read this document fully.
Then read L1 — the Mivan enterprise context.
Understand the transformation mandate and
why the modernization program exists.

**Day 2:** Read L2 — the health payer
domain knowledge. Focus on the claims
lifecycle and adjudication engine sections.
Ask the Digital Brain: "Walk me through
how a commercial claim flows through MiCPS
end to end."

**Day 3:** Read L3 — the MiCPS system
landscape. Understand the batch architecture,
the VSAM files, the DB2 tables, and the
modernization wave sequence.

**Day 4:** Read the L4 module that your
first story relates to. Ask the Digital Brain
about the specific programs and tables you
will be working with.

**Day 5:** Pick up your first story.
Before you write a line of code ask the
Digital Brain: "What is the LOB for this
story, what depends on what I am changing,
and what regulation governs this rule?"

If the Digital Brain cannot answer one of
those questions — that is a ghost node.
Register it. You have already made your
first contribution to the knowledge layer.

---

## Glossary — Essential Terms for Your First Week

| Term | Plain English Definition |
|---|---|
| LOB | Line of Business — Commercial, Medicare Advantage, or Medicaid. Different rules for each. Always ask. |
| Claim | An invoice from a provider to the health plan for services rendered to a member |
| Adjudication | The process of deciding whether to pay a claim and how much |
| Member | The person covered by the health plan — the patient |
| Provider | The doctor, hospital, or clinician who delivered care |
| Payer | The health plan — Mivan. The entity that pays claims. |
| Premium | Monthly payment from employer/member to the health plan for coverage |
| Deductible | Amount the member must pay before the plan starts paying |
| Copay | Fixed dollar amount the member pays per visit |
| Coinsurance | Percentage of the allowed amount the member pays after deductible |
| OOP Max | Out-of-Pocket Maximum — annual cap on member cost-share |
| Prior Auth | Pre-approval required before certain services are covered |
| COB | Coordination of Benefits — when a member has two insurance plans |
| CARC | Claim Adjustment Reason Code — standardized code explaining why a claim was adjusted |
| ERA | Electronic Remittance Advice — machine-readable payment explanation sent to providers |
| EOB | Explanation of Benefits — member-facing summary of how a claim was processed |
| PHI | Protected Health Information — any data identifying a member plus health information. HIPAA governs this. |
| HIPAA | Federal law governing health information privacy and electronic transaction standards |
| CMS | Centers for Medicare and Medicaid Services — federal agency governing Medicare and Medicaid |
| NPI | National Provider Identifier — unique 10-digit ID for every provider |
| 837 | HIPAA-standard electronic format for submitting claims |
| 835 | HIPAA-standard electronic format for payment remittance |
| MiCPS | Mivan Claims Processing System — the mainframe that processes all of this |
| Ghost Node | Knowledge that is known to be missing from the Digital Brain — register it when you find it |

There are two main claim types:

**Professional claim (837P)** — used by individual providers (physicians,
therapists, labs). Named after the CMS-1500 paper form it replaces.
Contains: the provider's NPI, the member's ID, the date of service,
the diagnosis codes (what was wrong), the procedure codes (what was done),
and the charge amount.

**Institutional claim (837I)** — used by hospitals and facilities.
Named after the UB-04 paper form it replaces. Contains similar information
but structured differently for facility billing.

The "837" refers to the X12 EDI (Electronic Data Interchange) transaction
set standard maintained by ASC X12. EDI is the data interchange standard
for healthcare — it predates REST APIs by decades and is still the
dominant format for claim submission.

### The Key Codes on Every Claim

**ICD-10-CM diagnosis codes** — a standardized code set describing
what condition the patient has. Example: J06.9 = Acute upper respiratory
infection. There are approximately 70,000 ICD-10-CM codes. Diagnosis codes
affect coverage determination, clinical edits, and risk adjustment.

**CPT procedure codes** — Current Procedural Terminology codes describing
what service was performed. Maintained by the American Medical Association.
Example: 99213 = Office visit, established patient, moderate complexity.
CPT codes drive fee schedule pricing and clinical edit logic.

**Revenue codes** — used on institutional claims; identify the type of
service at a facility level (room and board, pharmacy, lab, etc.).

**Modifier codes** — two-digit additions to CPT codes that change how
the procedure is interpreted. Example: modifier -25 on an E&M code means
a significant, separately identifiable evaluation was performed on the same
day as a procedure. Modifiers affect pricing, bundling rules, and NCCI edits.

**Why this matters to a developer:** These code sets are not static.
ICD-10 is updated October 1 every year. CPT is updated January 1 every
year. When Mivan loads updated code tables, claims submitted with new codes
before the table is updated will fail edits. Release timing for code table
updates is a real operational risk.

### The Allowed Amount

The allowed amount is not the same as the billed charge.

The provider bills $500 for a service. The plan's contract with that
provider (or the fee schedule if no contract exists) sets the allowed
amount at $180. The plan pays based on $180, not $500. The provider has
agreed via their contract to accept $180 as payment in full — they cannot
bill the member for the difference (called balance billing).

The allowed amount is a critical adjudication output. Getting it wrong —
because the fee schedule is stale, the provider's contract is expired,
or the taxonomy code lookup is incorrect — creates both overpayment
and provider payment disputes.

---

## 5. The Claims Lifecycle — From Submission to Payment

### Overview

A claim goes through seven stages before payment is issued:

```
1. Intake       → receive, validate format, assign ICN
2. Edit         → check for structural completeness
3. Eligibility  → is the member covered on DOS?
4. Pricing      → what is the allowed amount?
5. Adjudication → apply all business rules, make pay/deny decision
6. COB          → is there other insurance?
7. Payment      → generate EOP/EOB, issue payment
```

### Stage 1 — Intake

The claim arrives via EDI 837 transaction, provider portal, or paper
(scanned and converted). The system assigns an Internal Control Number
(ICN) — a unique identifier for this claim instance. The ICN is how
every downstream system, report, and audit trail refers to this claim.

**Developer note:** The ICN is the primary key of the claims world.
If you are building any claims-adjacent service, you will deal with ICNs
constantly. Understand the ICN structure — in MiCPS it encodes the
processing date, batch, and sequence number.

### Stage 2 — Edit Checks

Before any business logic runs, the claim is checked for structural
validity. Edit checks verify: required fields are present, codes are valid
in the current code tables, dates are logical, NPI is on file.

Claims that fail edits are rejected — returned to the provider for correction
before they enter adjudication. This is different from a denial (which is
a business decision after full adjudication).

**Rejection vs denial — developers frequently confuse these:**
- Rejection: the claim could not be processed; returned to sender; no adjudication occurred
- Denial: the claim was adjudicated and the plan decided not to pay; the member/provider has appeal rights

### Stage 3 — Eligibility Verification

The system verifies that the member was covered by Mivan on the date of
service. This sounds simple but is not:

- The member's employer may have sent a termination that has not been
  processed yet
- The member may have had a coverage gap
- For Medicaid, the member's eligibility changes monthly
- The coverage type (deductible, benefits) may have changed mid-year

Eligibility verification hits the member master file. In MiCPS this
is the MEMB-MSTR VSAM file and the BENE-FILE VSAM for benefit details.

### Stage 4 — Pricing

The system determines how much the plan is contractually obligated to pay.
For a professional claim this means:
1. Identify the rendering provider's NPI and taxonomy code
2. Look up the provider's contract (in PROV-MSTR and FEE-SCHED VSAM)
3. Apply the fee schedule to the procedure codes on the claim
4. Calculate the allowed amount

If the provider is out-of-network, a different fee schedule applies —
typically a percentage of the Medicare fee schedule or a billed charge
percentage, depending on the benefit plan.

### Stage 5 — Adjudication

This is the core. Adjudication applies all business rules to determine
the final payment decision:

- Apply clinical coverage rules (is this service covered?)
- Check prior authorization (was this authorized?)
- Apply NCCI edits (are these procedure codes being billed correctly together?)
- Apply accumulator logic (has the deductible been met?)
- Calculate member cost-sharing (copay, coinsurance)
- Apply any duplicate claim detection
- Apply any overpayment recovery logic

In MiCPS, MADJDRV0 orchestrates all of this by calling a sequence of
sub-programs, each responsible for one layer of the decision.

### Stage 6 — Coordination of Benefits (COB)

If the member has more than one insurance plan, the plans must coordinate
to avoid paying more than 100% of the allowed amount. The rules for
which plan pays first (primary vs secondary) are governed by:
- The birthday rule (for commercial — primary is the plan of the parent
  whose birthday comes first in the calendar year)
- Medicare Secondary Payer rules (for Medicare Advantage — federal law)
- Payer of last resort rules (for Medicaid — always last)

COB is one of the most complex areas of claims processing. Errors here
result in either the plan paying when it should not (overpayment) or
the member being billed when they should not be.

### Stage 7 — Payment and Explanation

Once adjudicated, the system generates:
- **EOP (Explanation of Payment)** — sent to the provider; shows what was paid and why
- **EOB (Explanation of Benefits)** — sent to the member; shows what the plan paid and what the member owes
- **Payment file** — initiates the actual EFT/check payment to the provider

The payment runs are typically batched — not real-time. MiCPS generates
payment files nightly during the batch window.

---

## 6. HIPAA — What It Actually Means for Developers

### What HIPAA Is

HIPAA (Health Insurance Portability and Accountability Act) is a federal
law that sets standards for protecting health information. As a developer
you need to understand two parts:

**The Privacy Rule** — governs who can access and use Protected Health
Information (PHI). PHI is any information that can identify a person
AND relates to their health condition, care, or payment for care.

**The Security Rule** — governs how PHI must be protected technically:
encryption in transit and at rest, access controls, audit logging,
breach notification.

### What Is PHI

PHI includes more than you think. It is not just medical records.
Any combination of health data + an identifier is PHI:

- Member name + diagnosis code = PHI
- Member ID + claim amount = PHI
- Date of birth + prescription = PHI
- IP address + health plan enrollment = potentially PHI

There is no grey area here. When in doubt, treat the data as PHI.

### What This Means for Your Code

**Logging:** Never log PHI in application logs. Member IDs, claim
details, diagnosis codes — none of it. Use tokens or internal IDs
in logs. This is a real compliance issue that has generated multi-million
dollar HIPAA settlements.

**APIs:** Any API that returns health information must be authenticated
and authorized. There is no public endpoint for claims data.

**Data at rest:** PHI must be encrypted. No PHI in plaintext config
files, no PHI in unencrypted S3 buckets, no PHI in environment variables.

**Data in transit:** TLS everywhere. No HTTP for any PHI-carrying service.

**Minimum necessary:** Only access the PHI you need for the specific
purpose. Don't build queries that pull full member records when you
only need a member ID for routing.

**Audit trail:** Every access to PHI must be auditable. Who accessed
what record, when, and why. This is not optional — it is a HIPAA
Security Rule requirement.

### The BAA

If you are building a service that will touch PHI and run on a cloud
provider (AWS, Azure, GCP), that cloud provider must have a signed
Business Associate Agreement (BAA) with Mivan. Most major cloud
providers offer BAAs. Without one, using that service for PHI is a
HIPAA violation. This is an architecture decision, not a developer
decision — but you need to know it exists.

---

## 7. The Concepts That Catch Developers Off Guard

### "Date of Service" Is Not "Date of Submission"

Every claim has a date of service (when the member received care) and
a date of submission (when the provider sent the claim). They can be
months apart. Almost every time-based rule in claims processing (timely
filing windows, eligibility lookups, fee schedule effective dates,
accumulator resets) uses the **date of service**, not the submission date.

If you write a query that filters on submission date when the business
requirement says date of service — your results will be wrong.

### Retroactive Changes Are Normal

In health insurance, the past changes constantly:
- A provider's contract may be updated retroactively
- A member's eligibility may be backdated
- A fee schedule may be corrected and applied to prior claims
- A diagnosis code may be added after the original claim was processed

This means claims are not immutable after they are paid. A claim can
be adjusted (corrected and reprocessed) or voided and replaced. The
original claim and all adjustments are retained. If you are building
reporting or analytics, you must understand the adjustment hierarchy
and only report on the final adjudication status.

**Frequency codes on institutional claims:**
- Frequency 1 = original claim
- Frequency 7 = replacement (void the original and process this one)
- Frequency 8 = void (cancel the original, no replacement)

### The Difference Between "Denied" and "Pended"

**Denied:** A final decision was made — the claim will not be paid
for a specific reason. The provider has appeal rights.

**Pended:** The claim cannot be adjudicated yet because information
is missing. It is in a holding queue (the suspense file) waiting for
something: a prior authorization to come through, a coordination of
benefits response, a missing medical record. Pended claims are not
denied — they may be paid once the missing information arrives.

The suspense file is the source of many operational headaches.
Claims that pend but never resolve sit there indefinitely. Reports
on pending claims are a key operational metric.

### Provider Data Staleness Causes Silent Failures

When a claim is adjudicated, the system looks up the provider in the
provider master file. If the provider's contract expired yesterday and
the termination was not loaded into the system, the claim is paid at
the in-network rate when it should be out-of-network. This is a silent
error — the system does not know it is wrong.

Provider data is loaded from a nightly batch feed. There is always a
staleness window. Claims adjudicated in that window may have incorrect
network status, wrong fee schedule, or stale credentialing status.
This is a known operational risk — not a bug to be fixed, but a
constraint to be understood.

### Coordination of Benefits Is Genuinely Hard

If a member has two insurance plans, determining which one pays first
and how much each pays is governed by rules that interact in non-obvious
ways. The birthday rule, the Medicare Secondary Payer rules, ERISA plan
vs state plan rules, and Medicaid's payer-of-last-resort status all
apply to different situations. There are scenarios where:

- Plan A pays first, calculates its payment
- Plan B receives Plan A's payment details (the COB information)
- Plan B pays only the remaining member cost-sharing, not the full claim

If COB information is missing when the secondary claim is processed,
the secondary plan may pay the full allowed amount — creating an
overpayment. Recovering overpayments from providers is one of the
costliest operational activities in health insurance.

---

## 8. A Developer's Quick Reference

### Questions to Ask Before You Code

For any story touching claims processing:

1. **Which LOB?** Commercial, Medicare Advantage, Medicaid, or all three?
2. **What regulation governs this?** Is there a CMS rule, a state law, or a contract requirement?
3. **Does this change affect already-processed claims?** Will it require retroactive reprocessing?
4. **What is the date reference?** Date of service, date of submission, or date of payment?
5. **Does this touch PHI?** If yes, what are the access controls and audit requirements?
6. **Is there a pend/suspense impact?** Does this change how claims enter or leave the suspense file?
7. **What is the accumulator impact?** Does this change member cost-sharing calculations?

### The Most Common Developer Mistakes in Health Payer Systems

| Mistake | Consequence |
|---|---|
| Applying a rule to all LOBs when it only applies to one | Regulatory violation for the other LOBs |
| Using submission date instead of date of service | Wrong eligibility, wrong timely filing determination |
| Not handling claim adjustments in reporting | Reports show overstated or understated payment figures |
| Logging PHI | HIPAA Security Rule violation |
| Treating denied and pended claims the same | Operational confusion, incorrect metrics |
| Assuming provider data is current | Silent overpayments and network status errors |
| Treating the allowed amount as the billed charge | Incorrect payment calculations |
| Not considering accumulator race conditions | Members charged deductible twice |

### Where to Go Next

| Topic | Document |
|---|---|
| Detailed claims lifecycle in MiCPS | knowledge/L2-domain/commercial-claims.md |
| Medicare Advantage specifics | knowledge/L2-domain/medicare-advantage.md |
| Medicaid specifics | knowledge/L2-domain/medicaid-managed-care.md |
| Provider data and credentialing | knowledge/L2-domain/provider-data-lifecycle.md |
| MiCPS system architecture | knowledge/L3-systems/mivan-system-landscape.md |
| Claims business rules | knowledge/L5-business-rules/claims-business-rules.md |
| What is still unknown | knowledge/ghost-nodes.md |

---

## Glossary — Essential Terms for New Developers

| Term | Plain English Definition |
|---|---|
| Adjudication | The process of deciding whether to pay a claim and how much |
| Allowed Amount | The maximum the plan will pay for a service per its contract or fee schedule — not the billed charge |
| BAA | Business Associate Agreement — required contract before a vendor can handle PHI |
| Capitation | A fixed monthly payment from the government to Mivan per member, regardless of how much care they use |
| Claim | The bill a provider submits to the health plan after treating a member |
| CMS | Centers for Medicare and Medicaid Services — the federal agency that runs Medicare and Medicaid |
| COB | Coordination of Benefits — the process of determining which insurance pays first when a member has multiple plans |
| Coinsurance | The percentage of the allowed amount the member pays after meeting the deductible |
| Copay | A fixed dollar amount the member pays per visit |
| CPT | Current Procedural Terminology — the code set describing medical procedures |
| Date of Service | When the member received care — the primary date reference for almost all claims rules |
| Deductible | The amount the member must pay before the plan starts covering costs |
| Denial | A final adjudication decision not to pay a claim — the provider has appeal rights |
| EDI | Electronic Data Interchange — the standard format for electronic healthcare transactions |
| EOB | Explanation of Benefits — the statement sent to the member explaining what the plan paid |
| EOP | Explanation of Payment — the statement sent to the provider explaining what the plan paid |
| Fee Schedule | The list of allowed amounts for each procedure code — negotiated by contract or set by regulation |
| HIPAA | Health Insurance Portability and Accountability Act — federal law governing health information privacy and security |
| ICD-10 | International Classification of Diseases — the code set for diagnoses |
| ICN | Internal Control Number — the unique identifier assigned to a claim when it enters the system |
| LOB | Line of Business — Commercial, Medicare Advantage, or Medicaid; each has distinct rules |
| NCCI | National Correct Coding Initiative — CMS edit rules governing which procedure codes can be billed together |
| NPI | National Provider Identifier — the unique 10-digit ID for every provider |
| Out-of-Pocket Maximum | The most a member pays in a year; after this the plan covers 100% |
| Pend | A claim held in suspense pending missing information — not denied, not paid |
| PHI | Protected Health Information — any data that identifies a person and relates to their health |
| Premium | The monthly amount paid to the health plan for coverage |
| Prior Authorization | Pre-approval required before certain services will be covered |
| Provider | A doctor, hospital, or other clinician who delivers care and bills the plan |
| Rejection | A claim returned to the provider before adjudication due to format or edit failure |
| Risk Adjustment | Adjusting capitation payments based on how sick a member population is |
| Suspense File | The queue of claims that cannot yet be adjudicated — waiting for information |
| Timely Filing | The deadline by which a provider must submit a claim |
