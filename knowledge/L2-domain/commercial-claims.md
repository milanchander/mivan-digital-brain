---
layer: L2
node_type: domain
domain: commercial-claims
source: web-research + manual
last_synced: 2026-08-08
validated_by: Milan Chander
fidelity: HIGH
ghost_node_id: null
links_back:
  - knowledge/L1-enterprise/mivan-enterprise-context.md
links_forward:
  - knowledge/L3-systems/mivan-system-landscape.md
  - knowledge/L4-application/micps-application-knowledge.md
  - knowledge/L5-business-rules/claims-business-rules.md
audience: all
lob: commercial
---

# Commercial Claims — Domain Knowledge
## Mivan Health Plan — Commercial Line of Business

> **Validation flag legend used in this document:**
> `> ⚠️ VALIDATE:` marks a statement that requires confirmation against Mivan-specific policy, system behavior, or contractual terms before treating as authoritative.

---

## 0. Commercial LOB Overview

### What Is Commercial Health Insurance

Commercial health insurance covers individuals and employer groups outside of government programs (Medicare and Medicaid). It is the largest line of business for most national health plans including Mivan.

Mivan's commercial book covers:
- Fully-insured employer groups — Mivan bears the financial risk; employer pays premium
- ASO (Administrative Services Only) — employer self-funds the risk; Mivan administers claims for a fee
- Individual marketplace — ACA exchange plans; CMS regulates benefit design and pricing
- COBRA continuation coverage — former employees continuing group coverage

### Commercial vs Government Programs

| Dimension | Commercial | Medicare Advantage | Medicaid |
|---|---|---|---|
| Who pays Mivan | Employer/member premiums | CMS capitation | State capitation |
| Who regulates | State insurance dept | CMS — federal | State + CMS joint |
| Benefit design | Plan designs by Mivan | CMS-mandated baseline | State benefit package |
| Timely filing | State law / contract | CMS: 365 days | State contract |
| Prior auth | Plan policy | CMS limits what plans can require | State-directed |
| COB | Birthday rule, active employment | Medicare Secondary Payer rules | Payer of last resort |
| Encounter data | Not required | Required — CMS EDPS | Required — state MMIS |
| Overpayment | Contract-driven | CMS 60-day rule | State look-back limits |

### Fully-Insured vs ASO

**Fully-insured:**
- Mivan collects premiums and pays claims
- Mivan bears the financial risk of high claims
- Subject to state insurance regulations
- Premium taxes apply
- State prompt pay laws apply
- ACA MLR (Medical Loss Ratio) requirements apply

**ASO (Administrative Services Only):**
- Employer funds claims from their own assets
- Mivan processes claims and administers benefits for a fee
- Governed by ERISA — federal law preempts state insurance laws
- No state prompt pay law applies to ERISA plans
- No premium tax
- Different COB rules — ERISA plans can override some state COB rules
- Mivan still applies plan design and processes claims identically
- Claims examiners may not know if a claim is fully-insured or ASO

**Developer impact:**
ASO vs fully-insured status affects:
- Applicable regulatory requirements in L5
- Prompt pay timing requirements
- COB method applicability
- Overpayment recovery look-back limits
Always check plan type before assuming a regulatory rule applies.

### ACA Individual Marketplace

ACA marketplace plans (exchange plans) have additional requirements:
- Essential Health Benefits — 10 categories must be covered (ambulatory, emergency, hospitalization, maternity, mental health, prescription drugs, rehabilitative, laboratory, preventive, pediatric)
- Preventive services — covered at 100% before deductible (USPSTF A/B recommendations)
- Annual out-of-pocket maximum — ACA sets annual limits ($9,450 individual / $18,900 family for 2026)
- No lifetime or annual dollar limits on essential health benefits
- Cost-sharing reduction (CSR) plans — enhanced benefits for low-income members
- Metal tiers — Bronze, Silver, Gold, Platinum based on actuarial value

**Developer impact:**
ACA preventive service coverage at 100% before deductible is a specific coding requirement in the adjudication engine. Claims for USPSTF A/B-rated preventive services must bypass deductible application. This is a common source of incorrect cost-share calculations.

### COBRA Continuation Coverage

- Former employees may continue group coverage for up to 18-36 months by paying full premium
- Same benefits as active employees
- Mivan processes COBRA claims identically to active employee claims
- Eligibility flag in MEMBER-IDX indicates COBRA status
- COBRA termination is a common source of retroactive eligibility changes

## 1. Claims Lifecycle — End to End

The commercial health insurance claims lifecycle spans from the point of care through final payment. All commercial medical claims follow the same fundamental sequence, with payer-specific variations in system implementation.

```
Patient Encounter
      │
      ▼
Claim Preparation (Provider)
  - Assign ICD-10 diagnosis codes
  - Assign CPT / HCPCS procedure codes
  - Complete CMS-1500 (professional) or UB-04 (institutional)
      │
      ▼
Clearinghouse Submission
  - Format translation → ANSI X12 837P or 837I
  - Syntax and HIPAA compliance validation
  - 999 / TA1 acknowledgement returned to provider
      │
      ▼
Payer Intake
  - Claim received and logged
  - Duplicate detection
  - Member and provider lookup
      │
      ▼
Editing & Front-End Validation
  - OCE / claim edits (format, code, coverage)
  - NCCI edits (bundling, unbundling)
  - Medical necessity screening
      │
      ▼
Eligibility & Benefits Determination
  - Member active on date of service?
  - Correct plan / product?
  - COB order established?
      │
      ▼
Adjudication
  - Coverage determination
  - Prior auth check
  - Fee schedule / repricing
  - Cost-share calculation (deductible, copay, coinsurance, OOP max)
      │
      ├─── Auto-adjudicate (majority of clean claims)
      └─── Route to manual review (complex / flagged claims)
      │
      ▼
Adjudication Decision
  - Pay
  - Deny (with reason code)
  - Pend (request additional information)
  - Suspend (system hold for review)
      │
      ▼
Payment
  - EFT to provider (ACH)
  - X12 835 ERA sent to provider
  - EOB generated for member
      │
      ▼
Post-Payment
  - Remittance reconciliation
  - Overpayment / recovery (if applicable)
  - Reporting and analytics
```

### Claim Adjustment and Void

After a claim has been submitted and processed, providers may need to correct or cancel it using the X12 837 frequency code in CLM05-3.

| Frequency Code | Type | Description |
|---------------|------|-------------|
| 1 | Original | First submission of a new claim |
| 7 | Replacement (Corrected Claim) | Corrects and replaces a previously submitted claim; supersedes the original in full |
| 8 | Void | Cancels a previously processed claim entirely; triggers overpayment recovery if the original was paid |

**Replacement Claim Rules**

- The replacement claim (frequency code 7) must reference the original claim's **payer claim control number** (also called ICN — Internal Control Number, or DCN — Document Control Number) in the REF segment of Loop 2300
- The replacement claim resubmits all service lines — it is not a partial line-level correction
- The payer voids the original claim and adjudicates the replacement as a new claim

**Void Rules**

- A void (frequency code 8) cancels the original claim entirely
- If the original claim was paid, the void triggers an overpayment recovery obligation — the full paid amount becomes subject to recoupment

**MiCPS Complexity**

> ⚠️ HIGH TRIBAL KNOWLEDGE AREA: Matching replacement claims to their originals via ICN/DCN, handling partial adjustments, and managing the cascading downstream impacts on accumulators (deductible, OOP max) and COB calculations are among the most error-prone areas of MiCPS. When an original paid claim is replaced or voided, accumulator rollback and COB re-calculation must occur correctly or downstream claims will be mispriced. The logic for this is embedded in COBOL batch programs and is not fully documented.

### Regulatory Timelines

| Claim Type | Clean Claim Payment Deadline | Source |
|------------|-----------------------------|----|
| Commercial (fully-insured) | Varies by state; typically 30–45 days | State prompt pay laws |
| ERISA / self-funded | No federal mandate; contract-driven | DOL guidance |
| Medicare Advantage | 30 days (clean claim) / 60 days (unclean) | CMS MA regulations |
| Medicaid | Varies by state; typically 30 days | State Medicaid contracts |

> ⚠️ VALIDATE: Confirm Mivan's specific prompt pay obligations by state and line of business.

**Sources:** [FinThrive — Claims Lifecycle](https://finthrive.com/blog/understanding-the-claims-lifecycle-a-step-by-step-guide) · [SSI Group — Healthcare Claim Life Cycle](https://thessigroup.com/understanding-the-healthcare-claim-life-cycle-from-patient-registration-to-payment/) · [MedEvolve — Claims Submission](https://medevolve.com/revenue-cycle-101/claims-submission-rcm-process/)

---

## 2. Claims Intake & Editing

### Submission Channels

| Channel | Format | Typical Users |
|---------|--------|--------------|
| EDI clearinghouse | X12 837P / 837I | Large provider groups, hospitals |
| Direct EDI (trading partner) | X12 837P / 837I | Large systems with bilateral agreements |
| Provider web portal | Payer-proprietary form | Small practices, single providers |
| Paper (CMS-1500 / UB-04) | Scanned / OCR | Small providers; legacy submissions |

### ANSI X12 837 Format Overview

The X12 837 is the HIPAA-mandated electronic format for all healthcare claim submissions. The current required version is **005010** (X12 005010X222A2 for Professional; 005010X223A3 for Institutional).

#### 837P — Professional Claims

Used for physician and outpatient professional services. Maps to the paper CMS-1500 form.

| Key Segment | Description |
|------------|-------------|
| ISA / GS | Interchange and functional group headers — trading partner IDs |
| ST 837 | Transaction set header |
| BPR | Loop 2000A — Billing Provider |
| Loop 2000B | Subscriber / insured information |
| Loop 2000C | Patient information (if different from subscriber) |
| Loop 2300 | Claim header — dates, total charge, place of service, diagnosis codes |
| Loop 2400 | Service line detail — CPT/HCPCS, modifiers, charge, units |
| SE | Transaction set trailer |

Key data carried: NPI (billing and rendering), member ID, date of service, place of service (POS), ICD-10 diagnosis codes (up to 12), CPT / HCPCS codes, modifiers, charge amounts.

#### 837I — Institutional Claims

Used for inpatient and outpatient facility services. Maps to the paper UB-04 form.

| Key Segment | Description |
|------------|-------------|
| Loop 2300 | Claim header — admission date, discharge date, bill type, DRG |
| CLM05 | Type of bill (TOB) — 3-digit code identifying facility type and claim frequency |
| Loop 2400 | Revenue codes (not CPT for inpatient) + HCPCS for outpatient |

Key data carried: Type of bill (TOB), admission/discharge dates, DRG, revenue codes, condition codes, occurrence codes, value codes.

### Acknowledgement Transactions

| Transaction | Purpose |
|-------------|---------|
| TA1 | Interchange acknowledgement — confirms ISA-level receipt |
| 999 (replaces 997) | Functional acknowledgement — confirms transaction-level syntax acceptance or rejection |

> ⚠️ VALIDATE: Confirm whether Mivan uses 999 or legacy 997 acknowledgement with trading partners.

### Edit Categories

Once a claim passes EDI syntax validation, payer-side edits are applied in layers:

#### Layer 1 — Front-End / Format Edits
Validate structural completeness and HIPAA compliance before the claim enters the adjudication queue.

| Edit Type | Example |
|-----------|---------|
| Required field missing | Member ID absent |
| Invalid code format | NPI not 10 digits |
| Date logic | Service date after received date |
| Provider not credentialed | Rendering NPI not on file |

#### Layer 2 — Clinical / OCE Edits
The Outpatient Code Editor (OCE) is used by many payers (modeled after CMS's OCE for OPPS) to validate procedure and diagnosis code combinations.

| Edit Type | Example |
|-----------|---------|
| Invalid diagnosis code | ICD-10 code not in current code set |
| Sex / procedure conflict | Prostatectomy billed for female member |
| Age / procedure conflict | Pediatric code on adult member |
| Manifestation code as principal diagnosis | Code sequencing error |

#### Layer 3 — NCCI / Bundling Edits
The National Correct Coding Initiative (NCCI) defines procedure code pairs that should not be billed together. Originally a Medicare standard, widely adopted by commercial payers.

| Edit Type | Example |
|-----------|---------|
| Mutually exclusive procedure codes | Two procedures that cannot be performed together |
| Comprehensive / component edit | Component procedure included in a comprehensive code — unbundling |
| Modifier override | Some NCCI edits can be bypassed with appropriate modifier (e.g., -59, XU, XS) |

#### Layer 4 — Payer-Specific Business Edits
Rules specific to the plan's coverage, policy, or contract terms.

| Edit Type | Example |
|-----------|---------|
| Prior auth required and absent | Procedure requires auth; none on file |
| Non-covered service | Cosmetic procedure excluded from plan benefits |
| Frequency limit exceeded | More PT visits than plan allows per year |
| Referral required | HMO plan requires PCP referral; none on file |

### Timely Filing

Timely filing is the deadline by which a claim must be submitted to be eligible for payment, measured from the date of service (DOS). Claims received after the timely filing limit are denied regardless of clinical validity.

| Attribute | Detail |
|-----------|--------|
| Definition | Maximum period from DOS within which a claim must reach the payer to be eligible for payment |
| Commercial range | 90 days to 365 days from DOS; some contracts allow up to 24 months |
| Denial code | CARC CO-29 — "The time limit for filing has expired" |
| Governing authority | Contract-driven for commercial payers — no single federal standard |
| COB secondary claims | Typically measured from the primary payer's EOB date, not DOS |

**Late Filing Exceptions**

A timely filing denial may be overturned on appeal if the provider can demonstrate one of the following:

| Exception | Documentation Required |
|-----------|----------------------|
| Coordination of benefits | Primary payer EOB showing claim was submitted to primary within timely filing window |
| Retroactive eligibility | Proof that member's coverage was not confirmed until after the filing deadline |
| Provider system issues | Evidence of a documented system outage or clearinghouse failure that prevented timely submission |
| Payer error | Proof that the claim was submitted on time but rejected in error by the payer |

> ⚠️ VALIDATE: Confirm Mivan's commercial timely filing limit per provider contract tier (large group, individual, facility). Confirm the COB secondary timely filing window and whether it is measured from primary EOB date or DOS.

---

### Split Claims

A split claim is a single episode of care divided into two or more separate claims for processing purposes.

**Common Triggers**

| Trigger | Description |
|---------|-------------|
| Claim spans two benefit years | Inpatient admission beginning in December and discharging in January crosses plan year boundary; cost-share accumulators reset at year-end |
| Claim exceeds line item maximum | Some payers impose a maximum number of service lines per claim (e.g., 50 lines); claims exceeding this must be split into multiple submissions |
| Inpatient stay crosses two plan benefit periods | Member's benefit period resets mid-stay (e.g., Medicare benefit periods); stay must be split at the boundary |
| Payer system constraint | Legacy systems (including MiCPS) may impose internal record size limits requiring splits for very large claims |

**MiCPS Implication**

> ⚠️ HIGH TRIBAL KNOWLEDGE AREA: Split claim logic is one of the most complex areas of MiCPS batch processing. The rules for when and how to split a claim, how to link the resulting claim parts, and how to correctly apply accumulators and COB across split segments are embedded in COBOL batch logic with limited documentation. This area must be a priority for knowledge extraction before migration.

---

**Sources:** [AccountableHQ — HIPAA EDI Transactions](https://www.accountablehq.com/post/hipaa-edi-transactions-explained-types-x12-codes-and-compliance) · [DetailRCM — ANSI X12 837](https://detailsrcm.com/blog/medical-coding/ansi-x12-837-edi-claims-file-format-healthcare-billing/) · [EDI Academy — 837 Professional](https://ediacademy.com/blog/837-professional-health-care-claim/)

### MiCPS Implementation Notes — Claims Intake & Editing

> [TO BE POPULATED — MiCPS-specific implementation of this function, including COBOL program names, DB2 tables, VSAM files, batch job names, and known complexity areas]

---

## 3. Eligibility & Benefits Verification

### Real-Time Eligibility Check (EDI 270/271)

At claim intake, the payer performs an eligibility verification against its membership system:

| Check | Description |
|-------|-------------|
| Member active | Was the member enrolled and active on the date of service? |
| Plan / product | Which product (HMO, PPO, HDHP) was the member on? |
| Coverage effective dates | Did coverage start before and extend through the DOS? |
| LOB routing | Commercial, Medicare Advantage, or Medicaid? Route accordingly |

The EDI 270 (Eligibility Inquiry) / 271 (Eligibility Response) transaction pair is the HIPAA-standard real-time eligibility check, widely used by providers pre-service and payers at intake.

### Benefit Determination

Once eligibility is confirmed, the adjudication engine retrieves the member's benefit structure:

| Benefit Element | Description |
|----------------|-------------|
| Deductible | Annual amount member must pay before plan pays |
| Copay | Fixed dollar amount per visit or service type |
| Coinsurance | Member's percentage of allowed amount after deductible |
| Out-of-Pocket Maximum (OOP Max) | Annual cap on member cost-share; once reached, plan pays 100% |
| In-Network vs. Out-of-Network | Separate accumulators and cost-share tiers typically apply |
| Plan Exclusions | Services not covered under the benefit design |
| Benefit Limitations | Frequency limits, visit caps, prior auth requirements |

### Accumulator Tracking

The adjudication engine tracks cumulative member spending against deductible and OOP max accumulators, resetting annually at the plan's benefit year start.

> ⚠️ VALIDATE: Confirm whether Mivan uses calendar year or plan year benefit periods, and how mid-year enrollment affects accumulators.

### COB Detection at Eligibility

Most eligibility responses include COB indicators. When a member is flagged as having other coverage, COB order must be established before adjudication proceeds. See Section 7 for COB methods.

**Sources:** [Stedi — COB Checks](https://www.stedi.com/docs/healthcare/coordination-of-benefits) · [Machinify — What Is COB](https://www.machinify.com/resources/what-is-coordination-of-benefits-cob) · [Aetna — Claims Coordination](https://www.aetna.com/health-care-professionals/claims-payment-reimbursement/claim-coordination-review.html)

---

## 4. Adjudication Engine

### What Is Adjudication?

Adjudication is the process by which a payer reviews a submitted claim and determines: (1) whether it is covered, (2) how much is payable, and (3) what the member owes. It is the core financial decision-making step in the claims lifecycle.

### Adjudication Logic Flow

```
Claim enters adjudication queue (post-editing)
        │
        ▼
1. Coverage Determination
   - Is the service covered under the member's plan?
   - Are there applicable exclusions or limitations?
        │
        ▼
2. Prior Authorization Check
   - Does the procedure require prior auth?
   - Is a valid auth on file matching procedure, provider, and date?
        │
        ▼
3. Medical Necessity Review
   - Does the service meet payer's clinical coverage criteria?
   - Does diagnosis support the procedure?
        │
        ▼
4. Pricing / Fee Schedule Application
   - Apply contracted rate (in-network) or UCR (out-of-network)
   - Apply DRG grouper (institutional inpatient)
        │
        ▼
5. Cost-Share Calculation
   - Apply deductible accumulator
   - Apply copay / coinsurance
   - Check OOP max
        │
        ▼
6. COB Adjustment (if applicable)
   - Reduce payer liability based on primary plan payment
        │
        ▼
7. Adjudication Decision
   ├── Pay
   ├── Deny (with CARC / RARC codes)
   ├── Pend (awaiting additional information)
   └── Suspend (internal hold for manual review)
```

### Pended vs. Suspended Claims

These two statuses are frequently confused but represent distinct states in the adjudication workflow:

| Status | Initiated By | Meaning | Resolution |
|--------|-------------|---------|------------|
| **Pended** | System or adjudicator | Claim routed to a human work queue — awaiting action by a claims examiner (e.g., missing documentation, medical record request, manual coverage determination) | Claims examiner reviews and takes action: approve, deny, or request additional info |
| **Suspended** | System only | System-initiated hold — claim is paused pending an automated condition being met | Condition clears (e.g., COB data arrives, auth response received, eligibility confirmed) and a batch job automatically releases the claim back into adjudication |

**Common Suspend Triggers**

| Trigger | Condition That Clears It |
|---------|------------------------|
| Awaiting COB data | Primary payer EOB received via COB data exchange |
| Awaiting prior auth response | Auth approval or denial received from MiAuth |
| Awaiting eligibility confirmation | Retroactive enrollment processed in MiMember |
| Awaiting coordination with another claim | Related claim (e.g., split claim part 1) adjudicates first |

**MiCPS Implementation**

In MiCPS, suspended claims are held in a **suspense file** — either a dedicated VSAM file or a DB2 table with a suspend status code — and are released by a scheduled batch job that polls for the clearing condition. Pended claims are routed to an operations work queue managed via CICS transactions.

> ⚠️ VALIDATE: Confirm whether MiCPS uses a VSAM suspense file or a DB2 suspense table, and which batch job performs the suspense release sweep.

### Auto-Adjudication vs. Manual Review

| Category | Auto-Adjudicated | Manual Review |
|----------|-----------------|--------------|
| Definition | System resolves claim end-to-end without human intervention | Claim routed to a human reviewer (clinical or non-clinical) |
| Typical rate | 85–95% of clean claims for mature payers | 5–15% |
| Triggers for auto | Clean claim, known member, in-network provider, no auth required | Missing auth, clinical complexity, fraud flags, high-dollar threshold |
| Triggers for manual | Auth absent or mismatched, medical necessity question, coordination of benefits, experimental treatment | |

> ⚠️ VALIDATE: Confirm Mivan's current MiCPS auto-adjudication rate and target rate for the cloud-native platform.

### Medical Necessity Determination

Medical necessity is the clinical standard used to determine whether a service is appropriate and required. Most commercial payers use one of two industry-standard criteria sets:

| Criteria Set | Publisher | Notes |
|-------------|-----------|-------|
| InterQual | Change Healthcare (now Optum) | Level of care, acute care, procedures |
| MCG (Milliman Care Guidelines) | Milliman | Evidence-based; widely used for UM and concurrent review |

Payers may also maintain proprietary clinical coverage policies (CCPs) that supplement or override published criteria for specific services.

> ⚠️ VALIDATE: Confirm which clinical criteria set(s) Mivan uses for commercial medical necessity determinations.

### Common Adjudication Denial Reasons

| CARC Code | Reason |
|-----------|--------|
| CO-4 | Procedure code inconsistent with modifier |
| CO-11 | Diagnosis inconsistent with procedure |
| CO-15 | Authorization number missing / invalid |
| CO-29 | Time limit for filing expired |
| CO-50 | Non-covered service |
| CO-97 | Payment included in allowance for another service |
| CO-197 | Prior authorization required |
| PR-1 | Deductible |
| PR-2 | Coinsurance |
| PR-3 | Copay |

CARC = Claim Adjustment Reason Code. Published and maintained by the Washington Publishing Company (WPC). RARC (Remittance Advice Remark Codes) provide supplementary denial detail.

**Sources:** [OSP Labs — Adjudication Software](https://www.osplabs.com/insights/everything-you-should-know-about-healthcare-claims-adjudication-software/) · [Kodjin — Auto Adjudication](https://kodjin.com/blog/auto-adjudication-of-claims-system-case/) · [CareCloud — Adjudication](https://carecloud.com/continuum/what-is-adjudication-in-medical-billing/)

### MiCPS Implementation Notes — Adjudication Engine

> [TO BE POPULATED — MiCPS-specific implementation of this function, including COBOL program names, DB2 tables, VSAM files, batch job names, and known complexity areas]

---

## 5. Pricing & Fee Schedules

### Fee Schedule Types

| Type | Used For | Basis |
|------|---------|-------|
| Contracted / negotiated fee schedule | In-network professional claims | Payer-provider contract; typically expressed as % of Medicare or flat rate per CPT |
| Medicare Physician Fee Schedule (MPFS) | Medicare Advantage; often the baseline for commercial contracts | CMS RVU-based (Work + Practice Expense + Malpractice RVUs × GPCI × Conversion Factor) |
| DRG-based (IPPS) | Inpatient institutional claims | MS-DRG grouper assigns a DRG; payer pays a fixed rate per DRG |
| APC-based (OPPS) | Outpatient hospital claims | Ambulatory Payment Classifications; CMS OPPS rates used as reference |
| Per Diem | Inpatient; common in commercial contracts | Fixed daily rate by level of care (ICU, Med/Surg, etc.) |
| Case Rate / Global Fee | Maternity, transplant, bundled episodes | Single payment covers all services in an episode |
| UCR (Usual, Customary, and Reasonable) | Out-of-network professional claims | Benchmarked against what most providers in a geographic area charge for the same service |
| Capitation | Delegated / risk-bearing providers | Fixed PMPM payment; provider assumes utilization risk |

### Professional Claims Repricing (In-Network)

1. Retrieve provider's contracted fee schedule (indexed by NPI, specialty, or group contract)
2. Look up allowed amount for the billed CPT / HCPCS code
3. If no specific contracted rate, apply fallback (e.g., % of Medicare MPFS)
4. Allowed amount = the lesser of billed charge or contracted rate

### Professional Claims Repricing (Out-of-Network)

For out-of-network professional claims, payers typically use one of:

| Method | Description |
|--------|-------------|
| UCR databases | FAIR Health, Optum iCES, or proprietary data; rates set by percentile of billed charges in a geographic area |
| Medicare multiples | Allowed = X% of Medicare MPFS for the same code and locality |
| Billed charge percentage | Allowed = X% of provider's billed charge |

> ⚠️ VALIDATE: Confirm Mivan's out-of-network repricing methodology and which UCR database is used (FAIR Health, internal, etc.).

### Institutional Inpatient — DRG Pricing

Inpatient hospital claims are priced using the MS-DRG (Medicare Severity Diagnosis Related Group) system:

```
Admission
  → ICD-10 diagnosis codes + procedures assigned by coder
  → DRG Grouper assigns MS-DRG based on principal diagnosis, CCs/MCCs, procedures, age, discharge status
  → Payer applies contracted DRG rate (base rate × relative weight)
  → Outlier payments applied if length of stay exceeds threshold
```

| Concept | Description |
|---------|-------------|
| Base Rate | Negotiated dollar amount per DRG relative weight unit |
| Relative Weight (RW) | CMS-assigned complexity weight per DRG (higher = more complex = higher payment) |
| CC / MCC | Complication or Comorbidity / Major CC — presence increases DRG payment |
| Outlier Payment | Additional payment for cases where cost significantly exceeds the DRG rate |
| Transfer DRG | Reduced payment when patient transferred before full LOS |

> ⚠️ VALIDATE: Confirm whether Mivan uses MS-DRG, APR-DRG (All Patient Refined), or a mix by product.

### Institutional Outpatient — APC / Revenue Code Pricing

Outpatient facility claims are priced by revenue code and/or HCPCS code. Commercial payers often use APC-equivalent groupings or flat per-procedure rates.

**Sources:** [PMC — Physician Pricing](https://pmc.ncbi.nlm.nih.gov/articles/PMC4191326/) · [FindACode — UCR Fees](https://www.findacode.com/topics/topic/ucr.html) · [MderCRM — Claim Repricing 2026](https://mdercm.com/blog/claim-repricing-healthcare-billing-guide-2026/)

### MiCPS Implementation Notes — Pricing & Fee Schedules

> [TO BE POPULATED — MiCPS-specific implementation of this function, including COBOL program names, DB2 tables, VSAM files, batch job names, and known complexity areas]

---

## 6. Claims Payment

### Payment Methods

| Method | Description | Regulatory Basis |
|--------|-------------|-----------------|
| EFT (Electronic Funds Transfer) | ACH deposit to provider's bank account | ACA Operating Rules (CAQH CORE) mandate EFT enrollment option |
| Paper Check | Physical check mailed to provider | Legacy; declining; still required for providers not enrolled in EFT |
| Virtual Card Payment (VCP) | Single-use virtual credit card | Convenience method; providers may opt out under ACA rules |

### X12 835 — Electronic Remittance Advice (ERA)

The EDI 835 is the HIPAA-mandated electronic standard for payment remittance. It is sent by the payer to the provider concurrent with or following the EFT payment. Governed by 45 CFR Part 162.

#### 835 Structure

| Segment / Loop | Content |
|---------------|---------|
| ISA / GS | Interchange and functional group headers |
| ST 835 | Transaction set header |
| BPR | Payment information — amount, payment method, EFT trace number |
| TRN | Trace number — links ERA to the corresponding EFT deposit |
| Loop 2000 | Payer / payee identification |
| Loop 2100 | Claim payment / denial detail — one loop per claim |
| CLP | Claim-level summary — billed, allowed, paid amounts, patient responsibility, claim status |
| SVC | Service line detail — procedure code, billed, allowed, paid per line |
| CAS | Adjustment reasons — CARC codes explaining each adjustment |
| MOA | Medicare outpatient adjudication (Medicare Advantage specific) |
| SE | Transaction set trailer |

#### Key 835 Data Points

| Field | Description |
|-------|-------------|
| Billed Amount | What the provider charged |
| Allowed Amount | Contracted or UCR rate |
| Paid Amount | Amount actually disbursed |
| Patient Responsibility | Deductible + copay + coinsurance |
| CARC | Claim Adjustment Reason Code — why payment differs from billed |
| RARC | Remittance Advice Remark Code — supplementary detail |
| Check / EFT Number | Payment trace identifier for reconciliation |

### EOB — Explanation of Benefits

The EOB is the member-facing equivalent of the ERA. It is sent to the member by mail or made available electronically on the member portal, and summarizes how the claim was processed and what the member owes.

> ⚠️ VALIDATE: Confirm Mivan's ERA delivery mechanism (clearinghouse, direct to provider, provider portal) and EOB delivery SLA.

**Sources:** [AccountableHQ — 835 Compliance](https://www.accountablehq.com/post/hipaa-and-remittance-advice-compliance-requirements-for-835-eob-transactions) · [SignalEDI — EDI 835](https://signaledi.com/blog/edi-835-remittance) · [Dastify — ERA 835](https://www.dastifysolutions.com/blog/era-835-electronic-remittance-advice-era-edi-835-in-medical-billing/)

---

## 7. Coordination of Benefits (COB)

### Overview

COB is the process payers use to determine the order and amount of payment when a member is covered by more than one health plan. The goal is to prevent total payments from exceeding 100% of actual charges.

Approximately 43 million Americans carry dual health coverage. CO-22 (claim paid by another payer) is consistently among the top denial reasons in commercial claims.

### Primary vs. Secondary Determination

The payer that pays first is **primary**; the payer that pays after the primary is **secondary**. Determination follows these rules in order:

| Rule | Description |
|------|-------------|
| 1. Active employment | Plan from current employment is primary over a plan from retirement |
| 2. Birthday rule | For dependents, parent whose birthday falls earlier in the calendar year is primary |
| 3. Gender rule | Some older plans use gender (father's plan primary); largely superseded by birthday rule |
| 4. Custody / court order | For children of divorced parents, court-ordered plan is primary; if no court order, birthday rule applies |
| 5. Medicare Secondary Payer (MSP) rules | Federal rules govern when Medicare is secondary (e.g., active employee with employer coverage, auto accident, workers comp) |
| 6. COBRA | Active employee coverage is primary over COBRA coverage |

### COB Payment Methods

#### 1. Standard COB (Traditional)
The secondary plan pays after the primary. The combined payment from both plans can equal up to 100% of actual charges but not exceed them. The secondary plan pays its normal benefit amount, reduced only to prevent total payment from exceeding 100% of charges.

**Example:**
- Billed: $1,000
- Primary pays: $800
- Secondary normal benefit: $900
- Secondary actually pays: $200 (to bring total to $1,000, not $1,700)

#### 2. Non-Duplication COB
The secondary plan compares its allowable amount to what the primary already paid. If the primary paid equal to or more than the secondary's allowable, the secondary pays nothing.

**Example:**
- Billed: $1,000
- Secondary allowable: $750
- Primary paid: $800
- Secondary pays: $0 (primary already exceeded secondary's allowable)

> ⚠️ VALIDATE: Confirm whether Mivan uses standard or non-duplication COB for commercial products.

#### 3. Maintenance of Benefits (MOB)
The secondary plan reduces covered charges by the amount the primary plan paid, then applies its own deductible and coinsurance to the remainder.

**Example:**
- Billed: $1,000 | Primary paid: $700
- Remaining after primary: $300
- Secondary applies 20% coinsurance: pays $240

#### 4. Carve-Out COB
The secondary plan calculates what it would normally pay, then subtracts the primary's payment. Common in self-funded commercial plans.

### COB Data Exchange

Payers exchange COB data via:
- EDI 837 COB loops (Loop 2330 — Other Subscriber Information)
- CMS COB contractor (for Medicare as secondary)
- State COB databases (for Medicaid coordination)

**Sources:** [CMS — Coordination of Benefits](https://www.cms.gov/medicare/coordination-benefits-recovery/overview/coordination-benefits) · [Machinify — What Is COB](https://www.machinify.com/resources/what-is-coordination-of-benefits-cob) · [AMBCI — COB Definitions](https://ambci.org/medical-billing-and-coding-certification-blog/understanding-coordination-of-benefits-cob-clear-definitions) · [MODPractice — Non-Duplication](https://modpractice.com/coordination-of-benefits-non-duplication-plans/)

### MiCPS Implementation Notes — Coordination of Benefits

> [TO BE POPULATED — MiCPS-specific implementation of this function, including COBOL program names, DB2 tables, VSAM files, batch job names, and known complexity areas]

---

## 8. Overpayment & Recovery

### What Is an Overpayment?

An overpayment occurs when a payer disburses more than the correct amount for a claim. Common causes:

| Cause | Description |
|-------|-------------|
| COB not applied | Claim paid as primary when secondary; or secondary liability miscalculated |
| Duplicate payment | Same claim paid twice (e.g., paper and EDI versions both processed) |
| Eligibility error | Member not active on date of service; claim paid before termination was processed |
| Pricing error | Wrong fee schedule applied; incorrect DRG grouping |
| Auth retroactively voided | Prior auth cancelled or never valid; paid claim must be recovered |
| Fraud / billing error | Upcoding, unbundling, services not rendered |
| Post-payment audit finding | SIU or clinical audit identifies overpayment after initial payment |

### Overpayment Identification

| Source | Description |
|--------|-------------|
| Automated post-payment auditing | Rules engine flags claims that passed adjudication but meet post-pay review criteria |
| COB reconciliation | Cross-payer COB data reveals duplicate primary/secondary payment |
| Provider audit | Contractual right-to-audit provisions; medical record review |
| SIU (Special Investigations Unit) | Fraud, waste, and abuse investigations |
| Provider self-disclosure | Provider identifies and voluntarily returns overpayment |
| CMS overpayment reports | For Medicare Advantage, CMS RADV audits can trigger recovery |

### Recovery Process

```
Overpayment Identified
        │
        ▼
Internal Validation
  - Confirm overpayment amount and affected claims
  - Document root cause
        │
        ▼
Demand Letter Issued to Provider
  - Identifies specific claim(s), dates, and overpaid amount
  - States recovery method and timeline
  - Includes appeal / dispute rights
        │
        ▼
Provider Response Window (typically 30–60 days)
  ├── Provider agrees → voluntary refund check or offset consent
  ├── Provider disputes → review process; may adjust demand
  └── No response → payer proceeds to recoupment
        │
        ▼
Recovery Method
  ├── Offset / Recoupment → deduct from future claim payments
  ├── Direct refund → provider mails check
  └── Escalation → collections or legal (rare; large amounts)
```

### Demand Letter Requirements

Per CMS guidance for Medicare overpayments, demand letters must include:
- The specific claim(s) and service dates in question
- The amount of the overpayment
- The reason for the overpayment determination
- The timeframe for repayment
- Appeal and dispute rights and instructions

> ⚠️ VALIDATE: Confirm Mivan's commercial demand letter template and required elements — commercial may differ from Medicare standards.

### Recovery Methods Defined

| Method | Description | Typical Trigger |
|--------|-------------|----------------|
| Offset | Future claim payments are reduced until the overpayment is recovered | Provider ongoing billing relationship; most common method |
| Recoupment | Systematic deduction from remittances; often automated | Standard recovery process; same as offset in most usage |
| Direct Refund | Provider sends a check or ACH back to the payer | Provider-initiated or agreed-upon for large amounts |
| Capitation Adjustment | Reduce monthly cap payment for delegated providers | Capitated provider arrangements |

### Timelines and Interest

| Scenario | Timeline | Interest |
|----------|----------|---------|
| Commercial (contract-driven) | Per provider contract; typically 30–60 days to respond | Contract-specified; may accrue after response window |
| Medicare Advantage | CMS requires return within 60 days of identification | Interest may accrue under CMS rules |
| Provider self-disclosure | 60 days from identification (Medicare rule; commercial varies) | N/A if voluntary and timely |

> ⚠️ VALIDATE: Confirm Mivan's commercial overpayment interest policy and whether it differs by line of business or provider contract tier.

### Appeals and Disputes

Providers have the right to dispute overpayment demands. Commercial payer dispute processes are governed by:
- Provider contract dispute resolution provisions
- State prompt pay laws (some include overpayment dispute rights)
- ERISA for self-funded plans

> ⚠️ VALIDATE: Confirm Mivan's overpayment dispute SLA and escalation path.

**Sources:** [FRG Systems — Overpayment Recovery](https://frgsystems.com/healthcare-finance-news/understanding-overpayment-recovery-process) · [CMS — Medicare Overpayments Fact Sheet](https://www.cms.gov/outreach-and-education/medicare-learning-network-mln/mlnproducts/downloads/overpaymentbrochure508-09.pdf) · [Noridian — Demand Letter Elements](https://med.noridianmedicare.com/web/jadme/claims-appeals/overpayments/elements-of-a-demand-letter) · [MediBillMD — Recoupment](https://medibillmd.com/blog/recoupment-payment/)

### MiCPS Implementation Notes — Overpayment & Recovery

> [TO BE POPULATED — MiCPS-specific implementation of this function, including COBOL program names, DB2 tables, VSAM files, batch job names, and known complexity areas]

---

## Glossary

| Term | Definition |
|------|-----------|
| 837P | ANSI X12 EDI transaction for professional claims |
| 837I | ANSI X12 EDI transaction for institutional claims |
| 835 | ANSI X12 EDI transaction for payment remittance (ERA) |
| 270/271 | ANSI X12 EDI transaction for eligibility inquiry / response |
| CARC | Claim Adjustment Reason Code — explains payment adjustment |
| RARC | Remittance Advice Remark Code — supplementary detail on ERA |
| NCCI | National Correct Coding Initiative — CMS procedure code bundling edits |
| OCE | Outpatient Code Editor — validates outpatient claim codes |
| DRG | Diagnosis Related Group — inpatient payment classification |
| MS-DRG | Medicare Severity DRG — CMS's current DRG system |
| APC | Ambulatory Payment Classification — outpatient facility payment grouping |
| UCR | Usual, Customary, and Reasonable — out-of-network pricing benchmark |
| MPFS | Medicare Physician Fee Schedule |
| RVU | Relative Value Unit — basis for MPFS pricing |
| COB | Coordination of Benefits |
| MOB | Maintenance of Benefits — a COB method |
| EFT | Electronic Funds Transfer — ACH payment to provider |
| ERA | Electronic Remittance Advice — EDI 835 |
| EOB | Explanation of Benefits — member-facing payment summary |
| Recoupment | Recovery of overpayment via deduction from future payments |
| Offset | Synonym for recoupment in most commercial contexts |
| SIU | Special Investigations Unit — fraud, waste, and abuse |
| PMPM | Per Member Per Month — capitation payment unit |
| TOB | Type of Bill — 3-digit code on 837I identifying facility and claim frequency |
| POS | Place of Service — 2-digit code on 837P |

## Commercial-Specific Complexity Areas

### Grandfathered Plans

Plans in existence before March 23, 2010 (ACA enactment) may be grandfathered and exempt from certain ACA requirements:
- Do not need to cover preventive services at 100% before deductible
- Different cost-sharing rules may apply
- MiCPS has a grandfathered plan indicator in the benefit parameters table
- VALIDATE: How many Mivan commercial plans are still grandfathered as of 2026?

### Self-Funded Plan Design Variations

ASO employers have significant flexibility in plan design. Common variations that affect MiCPS processing:
- Carve-outs — pharmacy, behavioral health, or dental carved out to separate vendors
- Embedded vs aggregate deductibles — family deductible structure differs
- Reference-based pricing — allowable set as percentage of Medicare rather than contracted rate
- Direct contracting — employer contracts directly with specific providers
- Custom accumulator rules — some employers exclude certain services from deductible

### State Variation in Commercial

Unlike ERISA self-funded plans, fully-insured commercial plans are subject to state mandates:
- Mandated benefit requirements by state (e.g. infertility coverage, chiropractic, autism treatment)
- State-specific timely filing limits
- State-specific COB rules
- State prompt pay interest rates
- State surprise billing protections

MiCPS handles state variation through the STATE_CONTRACT table and state-specific business rules in MBUSNED0.
VALIDATE: How are state mandates implemented in MiCPS — plan-level configuration or state-code logic in COBOL?

### Commercial COB Specifics

Commercial COB follows NAIC model rules:
- Birthday rule for dependents
- Active employment rule — active employer coverage is primary over retirement coverage
- Gender rule — still present in some legacy MiCPS plan configurations (see L4 COB module)
- COBRA is always secondary to active coverage

Unlike Medicare (MSP federal rules) and Medicaid (payer of last resort), commercial COB is governed by state law and NAIC guidelines — giving plans more flexibility but also more variation.

## Related Lines of Business & Implementation

> **Platform note:** This document covers **commercial** claims, which are adjudicated by **MiCPS**. **Medicare Advantage and Medicaid are adjudicated by a different platform — MiFCT (TriZetto Facets)** — not MiCPS. MiEDI routes each claim by line of business. See L3 "LOB Routing Architecture".

### Sibling LOB Domain Nodes
- Medicare Advantage — `knowledge/L2-domain/medicare-advantage.md`
- Medicaid Managed Care — `knowledge/L2-domain/medicaid-managed-care.md`
- Provider Data (cross-LOB) — `knowledge/L2-domain/provider-data-lifecycle.md`
- Healthcare primer (for non-health readers) — `knowledge/L2-domain/health-primer.md`

### Commercial Program Tree
The commercial claims program tree implements the processing flow described in this document:
- COBOL: `src/cobol/commercial/` — `MCOMCLDR0` driver plus 5 subprograms *(planned — not yet built)*
- Java: `src/java/commercial/` — Spring Boot equivalent *(planned — not yet built)*

See L4 (`knowledge/L4-application/micps-application-knowledge.md`) for module-level program detail and L5 (`knowledge/L5-business-rules/claims-business-rules.md`) for the business rules these programs implement.
