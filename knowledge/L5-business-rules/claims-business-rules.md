---
layer: L5
node_type: process
domain: claims
app_id: micps
last_validated: 2026-08-07
validated_by: "Digital Brain — pending SME review"
fidelity: PARTIAL
source_count_declared: 10
source_count_captured: 10
owns:
  - Claims editing rules (claim-level and line-level)
  - NCCI edit logic
  - Adjudication decision rules
  - Coordination of Benefits priority rules
  - Overpayment detection rules
  - Pricing and fee schedule business rules
  - Near-duplicate detection rules
implements: []
links_back:
  - L2-domain/commercial-claims.md
  - L2-domain/medicare-advantage.md
  - L2-domain/medicaid-managed-care.md
  - L4-application/micps-application-knowledge.md
links_forward: []
ghost_nodes:
  - Mivan-specific COB priority rules by line of business
  - State-specific mandate variations for all 50 states
  - Complete adjudication rule priority order and conflict resolution
  - Internal fee schedule update cadence and override authority
  - NCCI edit version in production and update schedule
---

# Claims Business Rules
## Commercial Health Insurance — Industry Standard Rules

> **Flag legend used in this document:**
>
> `> ⚠️ MIVAN-SPECIFIC:` Rule or parameter that must be filled in based on Mivan/MiCPS domain expertise — not determinable from public sources alone.
>
> `> 📌 REGULATORY SOURCE:` Citable public standard (CMS, NAIC, HIPAA, state law).
>
> `> ⚠️ VALIDATE:` Statement derived from industry norms that should be confirmed against Mivan's actual implementation before treating as authoritative.

---

## 1. Claims Editing Rules

Claims editing is the process of validating a submitted claim for correct coding, clinical consistency, and payer-specific policy before adjudication begins. Editing occurs in two scopes: **claim-level** (the entire claim is evaluated as a unit) and **line-level** (each service line is evaluated independently).

### 1a. Claim-Level vs. Line-Level Edits

| Edit Scope | Description | Outcome |
|------------|-------------|---------|
| Claim-level edit | Evaluates the entire claim — header fields, total charges, required provider and member data | If triggered, the entire claim is rejected or denied |
| Line-level edit | Evaluates individual service lines — procedure code, units, modifiers against clinical rules | If triggered, the affected line(s) are denied; other lines may still pay |

**When claim-level rejection applies:** Format errors, missing member ID, invalid provider NPI, missing required claim header fields. The claim does not enter adjudication.

**When line-level denial applies:** NCCI bundling edits, MUE unit violations, sex/age/procedure conflicts, prior auth absent on a specific procedure. The claim enters adjudication; specific lines are denied.

> ⚠️ MIVAN-SPECIFIC: Confirm how MiCPS routes claim-level vs. line-level failures — whether a claim with one failing line is adjudicated with remaining lines or held entirely.

---

### 1b. NCCI — National Correct Coding Initiative

The NCCI was created by CMS to promote correct coding and prevent improper payments. Originally a Medicare standard, NCCI edit logic has been broadly adopted by commercial payers including Mivan.

> 📌 REGULATORY SOURCE: CMS NCCI — [cms.gov/medicare/coding-billing/national-correct-coding-initiative-ncci-edits](https://www.cms.gov/medicare/coding-billing/national-correct-coding-initiative-ncci-edits)

#### NCCI PTP Edits (Procedure-to-Procedure)

NCCI PTP edits define pairs of HCPCS/CPT codes that should not be billed together because one procedure is considered a component of the other, or because the two procedures are mutually exclusive.

Each PTP edit pair has two columns:

| Column | Role | Payment |
|--------|------|---------|
| Column 1 | Comprehensive or primary code | Eligible for payment |
| Column 2 | Component or mutually exclusive code | Denied unless a valid NCCI-associated modifier is appended |

**Modifier Indicators**

| Indicator | Meaning |
|-----------|---------|
| 0 | Modifier not allowed — Column 2 code is never separately payable when billed with Column 1 on the same date of service |
| 1 | Modifier allowed — Column 2 may be separately payable if a clinically appropriate NCCI-associated modifier (e.g., -59, -XU, -XS, -XE, -XP) is appended and documented |
| 9 | Edit deleted — no longer applicable |

**NCCI-Associated Modifiers**

| Modifier | Meaning |
|----------|---------|
| -59 | Distinct procedural service — different session, site, lesion, or organ system |
| -XE | Separate encounter |
| -XS | Separate structure |
| -XP | Separate practitioner |
| -XU | Unusual non-overlapping service |

**Rule:** A modifier override is only valid when there is a clinically distinct, separately documented service. Using modifier -59 / -X{EPSU} without documentation to bypass NCCI is a compliance violation and grounds for overpayment recovery.

> ⚠️ MIVAN-SPECIFIC: Confirm which NCCI table version Mivan loads into MiCPS (CMS publishes quarterly — Q1/Q2/Q3/Q4), and whether commercial-specific NCCI overrides are maintained separately from the CMS table.

#### NCCI PTP — Claim-Level vs. Line-Level Application

PTP edits are applied at the **claim line level**: the edit checks whether two specific codes appear on the same claim for the same beneficiary on the same date of service. If the edit triggers and no valid modifier is present, the Column 2 line is denied.

---

### 1c. MUE — Medically Unlikely Edits

MUEs define the maximum units of service (UOS) that can be reported for a given CPT/HCPCS code on a single date of service. They prevent billing errors where abnormally high unit counts are submitted.

> 📌 REGULATORY SOURCE: CMS MUE — [cms.gov/medicare/coding-billing/national-correct-coding-initiative-ncci-edits/medicare-ncci-medically-unlikely-edits-mues](https://www.cms.gov/medicare/coding-billing/national-correct-coding-initiative-ncci-edits/medicare-ncci-medically-unlikely-edits-mues)

#### MUE Adjudication Indicator (MAI)

Each MUE has an associated MAI that determines how it is applied:

| MAI | Type | Application Rule |
|-----|------|-----------------|
| 1 | Date of Service (DOS) edit | All units across all claim lines for that code on that DOS are summed; if total exceeds MUE, entire amount is denied |
| 2 | Claim line edit | Each individual claim line is checked independently against the MUE value; lines exceeding the MUE are denied; other lines for the same code are unaffected |
| 3 | Claim line edit (absolute) | Same as MAI 2 but represents an absolute physiologic limit — modifier override is not allowed |

**MAI 1 (Date of Service) — Example:**
- CPT 99213 has MUE = 1 (MAI 1)
- Provider bills three lines of 99213 for the same member on the same DOS
- All three units are denied — combined total of 3 exceeds MUE of 1

**MAI 2 (Claim Line) — Example:**
- CPT 11042 (debridement) has MUE = 3 (MAI 2) per claim line
- Line 1: 3 units → passes (≤ 3)
- Line 2: 4 units → that line is denied (exceeds 3)

> 📌 Update frequency: CMS publishes MUE table updates quarterly. Tables cover Practitioner Services, Outpatient Hospital Services, and DME Supplier Services.

> ⚠️ MIVAN-SPECIFIC: Confirm whether Mivan adopts CMS MUE tables verbatim or maintains custom MUE overrides for commercial lines of business. Confirm MUE table load cadence in MiCPS (quarterly CMS release → how many days to load into production?).

---

### 1d. Clinical / Code-Pair Edits

In addition to NCCI, MiCPS applies a set of clinical editing rules to catch coding errors that indicate clinical impossibility or improbability.

| Edit Type | Rule | Example |
|-----------|------|---------|
| Sex conflict | Procedure is anatomically impossible for the member's sex | Orchiectomy billed for female member |
| Age conflict | Procedure is age-inappropriate | Neonatal code billed for 45-year-old member |
| Diagnosis-procedure mismatch | Procedure code is inconsistent with the reported diagnosis | Cardiac catheterization with a sprained ankle as the only diagnosis |
| Manifestation sequencing | A manifestation code (ICD-10 "M" convention) is used as the principal diagnosis | E11.65 (Type 2 DM with hyperglycemia, manifestation) billed as principal without underlying condition |
| Invalid code | CPT or ICD-10 code does not exist in the current active code set | Expired or not-yet-effective code |
| Bilateral conflict | Both unilateral and bilateral code billed for the same body part | CPT 27447 (total knee, bilateral) billed alongside CPT 27447-RT |

> ⚠️ MIVAN-SPECIFIC: Confirm which clinical editing engine is used (e.g., Optum ClaimLogic, Change Healthcare ClaimsXten, or custom MiCPS COBOL rules). Confirm whether commercial clinical edits are applied at line level or claim level.

---

### 1e. Timely Filing Rules

Every payer enforces a filing deadline — the maximum period after the date of service within which a claim must be submitted to be eligible for payment.

> 📌 REGULATORY SOURCE: Filing deadlines are contractual and/or state-mandated; no single federal standard governs commercial timely filing limits.

| Payer Category | Typical Filing Limit | Source |
|----------------|---------------------|--------|
| Commercial (major carriers) | 90–180 days from DOS | Provider contract |
| Medicare (Part A/B) | 12 months from DOS | 42 CFR 424.44 |
| Medicaid | Varies by state; commonly 90–365 days | State Medicaid regulations |
| Coordination of Benefits (secondary) | Usually 90 days from primary EOB date | Provider contract |

**Rule:** A claim received after the timely filing limit is denied with CARC CO-29 ("The time limit for filing has expired"). This denial is generally not clinically overridable but may be appealed with proof of timely submission (e.g., clearinghouse acceptance acknowledgement).

> ⚠️ MIVAN-SPECIFIC: Confirm Mivan's commercial timely filing limit (likely 90 or 180 days) and any exceptions for COB secondary claims, corrected claims, or late-reported eligibility.

---

## 2. Eligibility Rules

Eligibility rules govern whether a member was covered on the date of service, what benefit plan applies, and how to handle edge cases such as retroactive terminations.

### 2a. Core Eligibility Verification Logic

The eligibility check runs at claim intake and resolves the following questions in order:

| Check | Rule | Denial if Failed |
|-------|------|-----------------|
| 1. Member exists | Member ID on the claim must match an enrolled member record | CO-4 or CO-16 (claim lacks information) |
| 2. Active on DOS | Member's enrollment effective date ≤ date of service ≤ termination date (or open-ended) | CO-97 or CO-27 (expenses incurred after coverage terminated) |
| 3. Correct plan | Claim is routed to the correct product (HMO, PPO, HDHP) based on member's enrolled plan | Internal routing error; reroute or deny |
| 4. Line of business | Commercial, Medicare Advantage, or Medicaid — each adjudicated by different rules | Internal routing |
| 5. Provider network | Rendering provider's network participation on DOS — in-network vs. out-of-network | Affects cost-share tier; OON claims may require separate benefit structure |
| 6. COB indicator | Is there other coverage? If yes, establish COB order before proceeding | COB logic invoked (see Section 5) |

> 📌 REGULATORY SOURCE: HIPAA 270/271 — Electronic Eligibility Inquiry and Response standard. [accountablehq.com — HIPAA 270/271 Compliance](https://www.accountablehq.com/post/hipaa-compliance-for-electronic-eligibility-verification-270-271-requirements-and-best-practices)

### 2b. Effective Date Rules

| Scenario | Rule |
|----------|------|
| New enrollment (employer group) | Coverage effective date set by group contract; typically first of the month following enrollment event or first of the month of hire |
| Special enrollment (HIPAA) | Qualifying life event triggers 30-day enrollment window; coverage effective no later than first day of the month following receipt of enrollment request |
| Open enrollment | Coverage effective date per plan year start (typically January 1 for calendar year plans) |
| Newborn | Many states require automatic 30-day coverage from birth under the subscriber's plan; after 30 days, formal enrollment is required |
| Late enrollment | May be subject to a waiting period; claims during waiting period denied |

> ⚠️ MIVAN-SPECIFIC: Confirm Mivan's newborn auto-coverage rule by state and whether MiCPS enforces waiting periods at claim time or at enrollment.

### 2c. Termination Handling

| Scenario | Rule |
|----------|------|
| Standard termination | Member coverage ends on the termination date; claims with DOS after termination are denied |
| Retroactive termination | Employer reports termination after claims have already been processed; creates overpayment recovery obligation — paid claims must be reviewed and potentially recouped |
| Grace period (ACA individual plans) | ACA-compliant individual plans must provide a 3-month grace period for premium non-payment; payer can pend but not deny claims during grace period months 2–3 |
| COBRA continuation | Member may elect COBRA within 60 days of qualifying event; if elected, coverage is retroactive to the date of the qualifying event |
| Retroactive enrollment | Member retroactively enrolled after claims already denied for no-coverage; denied claims must be reopened and adjudicated |

> ⚠️ MIVAN-SPECIFIC: Confirm how MiCPS handles retroactive terminations — specifically, the look-back period for recoupment review and the process for reopening denied claims after retroactive enrollment.

### 2d. Eligibility Data Sources and Hierarchy

| Source | Description | Precedence |
|--------|-------------|-----------|
| Employer group enrollment file (834) | Primary source of enrollment for commercial group members | Highest |
| Real-time eligibility query (270/271) | Point-in-time check; reflects latest enrollment data | High |
| Member self-reported | Member provides coverage details; requires verification | Low without verification |
| CAQH / third-party eligibility hub | Aggregated eligibility data; useful for COB secondary detection | Supplemental |

---

## 3. Adjudication Rules

### 3a. Coverage Determination Hierarchy

Before pricing or cost-share is applied, the adjudicator must determine whether the service is covered. Determination follows a defined hierarchy:

```
1. Plan Exclusions (absolute — no override)
      │ If the service is explicitly excluded → deny CO-50
      ▼
2. Benefit Design Limitations
      │ Frequency limits, visit caps, age limits
      │ If exceeded → deny with appropriate CARC
      ▼
3. Prior Authorization Requirement
      │ Is auth required for this procedure code?
      │ Is a valid auth on file (matching member, procedure, dates, provider)?
      │ If required and absent → deny CO-197
      ▼
4. Medical Necessity Determination
      │ Does clinical evidence support the service for the reported diagnosis?
      │ Apply clinical criteria (see 3b)
      │ If not met → deny CO-50 or CO-11
      ▼
5. Network / Provider Eligibility
      │ Is the rendering provider credentialed and in the correct network?
      │ Apply correct cost-share tier
      ▼
6. Coverage Confirmed → Proceed to Pricing
```

**Plan Exclusion Examples (Standard Commercial)**

| Exclusion Category | Examples |
|-------------------|---------|
| Cosmetic services | Rhinoplasty, blepharoplasty for cosmetic purposes |
| Experimental / investigational | Services not approved by a recognized clinical body |
| Non-covered procedures | Infertility treatment (plan-specific), weight loss surgery (plan-specific) |
| Dental / vision (unless separately purchased) | Routine dental, eye exams, eyeglasses |
| Self-inflicted injury | Injuries resulting from self-harm (plan-specific) |
| Workers' compensation | Services covered by WC must be submitted to WC, not group health |

> ⚠️ MIVAN-SPECIFIC: Confirm Mivan's standard commercial exclusion list and any plan-specific exclusion riders.

---

### 3b. Medical Necessity Criteria

Medical necessity is the clinical standard that determines whether a service is appropriate and required for the member's condition. Commercial payers use a combination of industry-standard criteria sets and proprietary clinical coverage policies (CCPs).

> 📌 REGULATORY SOURCE: CMS defines medical necessity as services "reasonable and necessary for the diagnosis or treatment of illness or injury." Commercial payers adopt similar language but are not bound by CMS definitions. [aapc.com — Medical Necessity](https://www.aapc.com/blog/77660-medical-necessity-is-it-really-necessary/)

#### Industry-Standard Criteria Sets

| Criteria Set | Publisher | Common Use |
|-------------|-----------|-----------|
| InterQual | Change Healthcare (Optum) | Acute inpatient level-of-care criteria, surgical procedures, post-acute care |
| MCG (Milliman Care Guidelines) | Milliman | Evidence-based criteria for medical/surgical procedures, behavioral health, home health |
| Hayes Medical Technology Directory | Hayes Management Consulting | Emerging technology and medical device coverage determinations |

#### Coverage Determination Logic

```
Is there a National Coverage Determination (NCD) equivalent 
or payer policy for this service?
      │
      Yes → Apply payer clinical coverage policy
      │
      No → Apply InterQual / MCG criteria set
            │
            Criteria met → Medically necessary → Approve
            │
            Criteria not met → Clinical reviewer route
                  │
                  Peer-to-peer available → Provider can request
                  │
                  Upheld denial → CO-50 with clinical denial rationale
```

> ⚠️ MIVAN-SPECIFIC: Confirm which clinical criteria set(s) Mivan uses (InterQual, MCG, or both — often by service type). Confirm whether clinical denial rationale letters are generated automatically by MiCPS or manually by a clinical team.

---

### 3c. Clinical Editing vs. Medical Necessity Review

These are distinct processes that are frequently confused:

| Concept | Clinical Editing | Medical Necessity Review |
|---------|----------------|------------------------|
| What it checks | Code-level accuracy — are the codes correct and consistent? | Clinical appropriateness — is the service appropriate for the condition? |
| Who performs it | Automated rules engine (MiCPS COBOL / edit software) | Automated criteria engine or human clinical reviewer |
| Happens when | Pre-adjudication edit phase | During adjudication |
| Appeal path | Corrected claim submission | Peer-to-peer review; then standard appeals process |
| Examples | Diagnosis doesn't support procedure; unbundled codes | Inpatient stay not meeting acute level-of-care criteria |

---

### 3d. Timely Adjudication Rules

> 📌 REGULATORY SOURCE: State prompt pay laws govern most commercial payers. All states except South Carolina have prompt pay requirements. [namas.co — Prompt Pay](https://namas.co/timely-claims-payment-prompt-pay/)

| Claim Type | Standard Deadline | Penalty for Non-Compliance |
|------------|------------------|--------------------------|
| Clean electronic claim | 30 days (many states) | Interest (commonly 10–18% APR); state-specific |
| Clean paper claim | 45 days (many states) | Interest; state-specific |
| Unclean claim | 30–45 days to request additional information; clock restarts upon receipt of requested information | State-specific |
| ERISA self-funded plans | No federal prompt pay mandate; governed by plan document and DOL regulations | No interest penalty; ERISA preempts state prompt pay laws |

> ⚠️ MIVAN-SPECIFIC: Confirm which states Mivan has fully-insured commercial business in, and document the specific prompt pay deadlines and interest rates for each. ERISA self-funded plans are exempt from state prompt pay — confirm how MiCPS distinguishes fully-insured from self-funded at adjudication time.

---

## 4. Pricing Rules

### 4a. Fee Schedule Hierarchy

When pricing a claim, the adjudication engine must determine which fee schedule to apply. Hierarchy is evaluated in order — the first applicable rule wins.

```
1. Does a specific bilateral provider-group contract exist?
      └── Yes → Apply group contract fee schedule
      └── No  ↓
2. Does an individual provider contract exist?
      └── Yes → Apply individual contract fee schedule
      └── No  ↓
3. Is the provider in a leased network (rented network arrangement)?
      └── Yes → Apply leased network fee schedule
      └── No  ↓
4. Is the provider out-of-network?
      └── Professional → Apply UCR (see 4c)
      └── Institutional → Apply institutional OON rate (see 4d)
```

> ⚠️ MIVAN-SPECIFIC: Confirm Mivan's contracted rate hierarchy and whether leased/rented network arrangements (e.g., MultiPlan, PHCS) are in use.

---

### 4b. Contracted Rate Application — Professional Claims

**In-Network Professional (CPT/HCPCS-based)**

1. Look up the provider's contract by NPI (or group/TIN)
2. Retrieve the allowed amount for the billed CPT/HCPCS code (+ place of service, if applicable)
3. If the specific code is not listed in the contract, apply the contract's fallback rate (commonly a percentage of Medicare MPFS)
4. **Lesser of rule:** The allowed amount is the lesser of the billed charge or the contracted rate
5. Apply modifiers that affect reimbursement (e.g., -26 professional component, -TC technical component, -51 multiple procedures)

**Multiple Procedure Reduction Rule**

When two or more surgical procedures are performed on the same day, the second and subsequent procedures are typically reimbursed at a reduced rate (commonly 50% of the allowed amount for the secondary procedure).

| Procedure | Reimbursement |
|-----------|--------------|
| Primary (highest RVU) | 100% of allowed amount |
| Secondary | 50% of allowed amount (industry standard) |
| Tertiary and beyond | 25–50% of allowed amount (plan-specific) |

> ⚠️ MIVAN-SPECIFIC: Confirm Mivan's multiple procedure reduction percentages and whether the reduction applies to the allowed amount or the billed charge.

---

### 4c. UCR Pricing — Out-of-Network Professional Claims

UCR (Usual, Customary, and Reasonable) is the benchmark for out-of-network professional claims. The allowed amount is determined by the prevailing rate for the same service in the same geographic area.

| UCR Benchmark Source | Description |
|--------------------|-------------|
| FAIR Health | Independent non-profit; widely used; rates published at percentile of billed charges by ZIP code and procedure code |
| Optum iCES (formerly Ingenix) | Commercial database; payer-licensable |
| Medicare MPFS percentage | OON allowed = X% of Medicare Physician Fee Schedule; common in self-funded plans |
| Proprietary payer database | Payer's own UCR database based on historical billed charges |

> 📌 REGULATORY SOURCE: Several states mandate specific UCR methodologies or require disclosure of the UCR methodology used. No single federal standard governs commercial OON UCR for non-MA plans.

> ⚠️ MIVAN-SPECIFIC: Confirm which UCR database Mivan uses for commercial OON professional claims, and what percentile is applied (e.g., 80th percentile of billed charges). Document any state-specific OON rules (e.g., New York's Independent Dispute Resolution process under the NY IDR law; federal No Surprises Act application).

---

### 4d. DRG-Based Pricing — Institutional Inpatient Claims

Inpatient facility claims are priced using Diagnosis Related Groups (DRGs). The DRG groups similar clinical episodes into a single payment category.

> 📌 REGULATORY SOURCE: CMS publishes MS-DRG definitions and relative weights annually. Commercial payers typically adopt MS-DRG as the base system, with contractual modifications.

**DRG Pricing Formula**

```
Allowed Amount = DRG Base Rate × DRG Relative Weight
                 + Outlier Payment (if applicable)
                 + Carve-Outs (if applicable)
```

| Component | Description |
|-----------|-------------|
| DRG Base Rate | Hospital-specific or regional negotiated dollar amount per relative weight unit |
| DRG Relative Weight | CMS-assigned complexity weight for the DRG; published annually; higher RW = higher payment |
| DRG Grouper | Software that assigns the MS-DRG based on principal diagnosis, secondary diagnoses (CCs/MCCs), procedures, age, sex, and discharge status |

**CC / MCC Impact**

| Classification | Effect on DRG |
|---------------|--------------|
| No CC or MCC | Base DRG (lowest tier) |
| CC (Complication or Comorbidity) | Mid-tier DRG; moderate payment increase |
| MCC (Major Complication or Comorbidity) | High-tier DRG; significant payment increase |

---

### 4e. High-Cost Outlier Rules — Institutional Inpatient

Outlier payments compensate hospitals for cases where actual treatment costs significantly exceed the DRG payment. Outlier logic prevents the DRG payment system from penalizing hospitals for legitimately complex, high-cost cases.

> 📌 REGULATORY SOURCE: CMS Outlier Payments — [cms.gov/medicare/payment/prospective-payment-systems/acute-inpatient-pps/outlier-payments](https://www.cms.gov/medicare/payment/prospective-payment-systems/acute-inpatient-pps/outlier-payments)

**Outlier Qualification Rule**

```
Estimated Case Cost > Fixed Loss Outlier Threshold

Where:
  Estimated Case Cost = Total Covered Charges × Hospital Cost-to-Charge Ratio (CCR)
  Fixed Loss Outlier Threshold = DRG Payment + Operating Outlier Threshold Amount
```

If estimated cost exceeds the fixed loss threshold, the payer pays an additional outlier amount:

```
Outlier Payment = (Estimated Case Cost − Outlier Threshold) × Marginal Cost Factor
```

The marginal cost factor is typically 80% under Medicare rules; commercial contracts specify their own marginal cost factor.

> ⚠️ MIVAN-SPECIFIC: Confirm whether Mivan uses a fixed loss threshold approach (CMS-style), a statistical outlier threshold (e.g., cost > 1.96 standard deviations above DRG mean), or a contractual per diem carve-over-threshold approach. Confirm CCR source — whether hospital-specific (from cost reports) or statewide default.

**Carve-Out Items**

Certain high-cost items are priced separately outside the DRG and do not count toward the outlier threshold:

| Carve-Out Type | Revenue Code Examples | Common Examples |
|---------------|----------------------|----------------|
| High-cost implants | RC 278 | Joint prostheses, cardiac devices |
| High-cost drugs | RC 636 | Chemotherapy, biologics |
| Blood products | RC 038X | Factor concentrates |

> ⚠️ MIVAN-SPECIFIC: Confirm which revenue codes are carved out in Mivan's hospital contracts and the pricing method for each carve-out (invoice cost, invoice cost + markup, or fixed rate).

---

### 4f. Per Diem and Case Rate Pricing

Some hospital contracts use alternative pricing methods:

| Method | Description | Common Use |
|--------|-------------|-----------|
| Per diem | Fixed daily rate by level of care (ICU, Step-Down, Med/Surg, Psych, Rehab) | Behavioral health inpatient; some commercial hospital contracts |
| Case rate / Global fee | Single all-inclusive payment per episode | Maternity (global OB), transplant, bariatric surgery |
| Percent of charges (POC) | Allowed = Billed Charges × Contract Percentage | Small or non-contracted hospitals; out-of-network fallback |

> ⚠️ MIVAN-SPECIFIC: Confirm which hospital pricing methods are in use in Mivan's network and how MiCPS determines which pricing method to apply for a given claim.

---

## 5. COB Rules

### 5a. Overview

COB rules determine payment order when a member has coverage under more than one health plan. Rules are based on the NAIC Coordination of Benefits Model Regulation, which most states have adopted as the basis for their commercial COB regulations.

> 📌 REGULATORY SOURCE: NAIC COB Model Regulation #120 — [content.naic.org/sites/default/files/model-law-120.pdf](https://content.naic.org/sites/default/files/model-law-120.pdf)

---

### 5b. Order of Benefits Determination — Full Rule Hierarchy

Rules are applied in sequence. The first applicable rule determines primary/secondary. If a rule produces a tie, move to the next rule.

**Rule 1 — Subscriber vs. Dependent**

The plan that covers a person as a subscriber (primary enrolled member) is primary over the plan that covers that person as a dependent.

*Example: Member is enrolled in their own employer plan AND covered as a dependent on their spouse's plan → own employer plan is primary.*

---

**Rule 2 — Active vs. Inactive Coverage**

The plan covering an individual as an active employee (or dependent of an active employee) is primary over a plan covering that individual as a retired employee (or dependent of a retiree).

> 📌 REGULATORY SOURCE: NAIC COB Model Regulation §7(B)(2) — Active/Inactive Rule.

*Example: Member covered by current employer plan and also by a retiree plan from a former employer → current employer plan is primary.*

---

**Rule 3 — COBRA vs. Active Coverage**

An active employee plan is primary over a COBRA continuation plan.

---

**Rule 4 — Dependent Children — Birthday Rule**

When a dependent child is covered under both parents' plans and both parents are living together (not divorced/separated), the plan of the parent whose birthday falls **earlier in the calendar year** is primary. Year of birth is irrelevant — only month and day matter.

> 📌 REGULATORY SOURCE: NAIC COB Model Regulation §7(B)(4) — Birthday Rule.

| Parent A Birthday | Parent B Birthday | Primary Plan |
|------------------|------------------|-------------|
| March 15 | September 22 | Parent A |
| July 4 | February 28 | Parent B |
| June 1 | June 1 (same day) | Plan in effect longer is primary |

---

**Rule 5 — Dependent Children — Divorced/Separated Parents**

When parents are divorced, separated, or not living together, a different rule hierarchy applies:

| Condition | Primary Plan |
|-----------|-------------|
| Court decree assigns health care coverage responsibility to one parent | Plan of the parent assigned responsibility by court order is primary |
| Court decree assigns joint custody without specifying coverage responsibility | Birthday Rule applies |
| No court decree — custodial parent | Plan of the custodial parent is primary |
| No court decree — custodial parent has remarried | Plan of custodial parent > Plan of custodial parent's new spouse > Plan of non-custodial parent |

> 📌 REGULATORY SOURCE: NAIC COB Model Regulation §7(B)(5) — Divorced/Separated Parents.

---

**Rule 6 — Gender Rule (Largely Superseded)**

Older COB provisions used the "gender rule" — the father's plan was primary for a dependent child. This rule has been superseded in the NAIC Model Regulation and most state laws by the Birthday Rule. However:

> ⚠️ VALIDATE: Some legacy contracts and older self-funded plan documents may still reference the gender rule. Confirm whether MiCPS has fully retired gender rule logic or whether it remains in specific contract configurations.

---

**Rule 7 — Medicare Secondary Payer (MSP) Rules**

Federal law governs when Medicare is secondary to commercial insurance. These rules override all NAIC COB rules for Medicare-enrolled members.

| Situation | Medicare Status |
|-----------|----------------|
| Active employee (employer with 20+ employees) | Medicare is Secondary |
| Working spouse covered as dependent (employer with 20+ employees) | Medicare is Secondary |
| End-Stage Renal Disease (ESRD) — first 30 months | Medicare is Secondary to employer plan |
| End-Stage Renal Disease (ESRD) — after 30 months | Medicare is Primary |
| Disability (employer with 100+ employees) | Medicare is Secondary |
| No-fault auto or workers' compensation | Medicare is Secondary |
| Retired employee | Medicare is Primary |
| COBRA | Medicare is Primary over COBRA |

> 📌 REGULATORY SOURCE: 42 U.S.C. §1395y(b) — Medicare Secondary Payer statute; CMS MSP Manual.

> ⚠️ MIVAN-SPECIFIC: Confirm how MiCPS handles MSP determination for commercial members who also have Medicare. Confirm whether MSP data is obtained from CMS BCRC (Beneficiary Coordination & Recovery Center) data exchange.

---

### 5c. COB Payment Methods

See L2 Domain Knowledge for full COB calculation details. Summary of methods:

| Method | How Secondary Pays | Typical Use |
|--------|-------------------|------------|
| Standard COB | Pays up to its normal benefit; total of both plans ≤ 100% of charges | Most commercial group plans |
| Non-Duplication | Pays nothing if primary payment ≥ secondary's allowable | Many self-funded commercial plans |
| Maintenance of Benefits (MOB) | Applies its own deductible and coinsurance to the remainder after primary payment | Some commercial; common in dental |
| Carve-Out | Secondary pays normal benefit minus primary's payment | Some commercial plans |

> ⚠️ MIVAN-SPECIFIC: Confirm which COB payment method applies to Mivan's commercial products and whether different methods apply to HMO vs. PPO vs. HDHP products.

---

### 5d. COB Data Sources and Verification

| Source | Purpose |
|--------|---------|
| Member eligibility file (834 inbound) | Employer-reported COB data at enrollment |
| Real-time 271 response | COB indicator — "other coverage exists" flag |
| CAQH / clearinghouse COB databases | Cross-payer COB data aggregators |
| CMS BCRC data exchange | Medicare COB data for MSP determination |
| Member self-reported (COB questionnaire) | Periodic outreach to members for COB updates; required by many state laws |

> ⚠️ MIVAN-SPECIFIC: Confirm whether Mivan participates in a commercial COB data exchange or relies solely on member-reported and employer-reported COB data.

---

## 6. Overpayment Rules

### 6a. CMS 60-Day Rule (Medicare and Medicaid Applicable; Commercial Reference)

> 📌 REGULATORY SOURCE: 42 U.S.C. §1320a-7k(d); 42 CFR Parts 401, 405, 422, 423, 447, 495; CMS Final Rule published February 2025.

The CMS 60-day rule requires providers and Medicare Advantage organizations to report and return identified overpayments within 60 days of identification.

**2024–2025 Regulatory Updates**

CMS issued a final rule in early 2025 revising the 60-day rule in two key ways:

| Change | Old Rule | New Rule (2025) |
|--------|---------|----------------|
| Definition of "identified" | "Reasonable diligence" standard | False Claims Act "knowingly" standard — actual knowledge, deliberate ignorance, or reckless disregard |
| Investigation grace period | None explicitly | New 180-day suspension of the 60-day clock during a timely, good-faith investigation of related overpayments |

> 📌 Source: [bassberry.com — CMS Revises 60-Day Rule](https://www.bassberry.com/news/a-new-year-a-new-overpayment-rule-cms-revises-the-60-day-rule/) · [morganlewis.com — Tick-Tock 60-Day Rule](https://www.morganlewis.com/pubs/2024/12/tick-tock-cms-overpayment-refund-final-rule-and-practical-implications)

**Penalties for Non-Compliance**

Failure to return an identified overpayment within 60 days (or 60 days after the end of the 180-day investigation period) triggers liability under the **False Claims Act** — potential treble damages plus per-claim penalties.

> ⚠️ VALIDATE: The 60-day rule applies directly to Medicare Advantage and Medicaid managed care. For Mivan's commercial lines of business, there is no equivalent federal rule — confirm whether Mivan has adopted the 60-day rule as a voluntary standard for commercial overpayment management.

---

### 6b. Commercial Overpayment Rules

Commercial overpayment rules are governed by:
1. **Provider contract** — contractual right to recoup, timelines, interest provisions
2. **State insurance law** — some states impose recoupment limits or require specific processes
3. **ERISA** — for self-funded plans; no state recoupment law applies

#### Commercial Recoupment Timeline Rules

| Jurisdiction | Rule |
|-------------|------|
| No state law restriction | Provider contract governs; payer may recoup with notice per contract terms |
| States with recoupment limits (example: CA, TX, NY, FL) | Many states impose a look-back period (commonly 12–36 months) beyond which recoupment is prohibited |
| ERISA self-funded plans | Preempted from state recoupment limits; contract governs |

> ⚠️ MIVAN-SPECIFIC: Confirm the states where Mivan has fully-insured commercial business subject to state recoupment laws. Document the applicable recoupment look-back period per state. Confirm whether Mivan's provider contracts include a recoupment limitation provision.

---

### 6c. Overpayment Identification Rules

The following rules trigger overpayment identification in MiCPS or downstream post-pay audit:

| Trigger | Rule | Responsible System |
|---------|------|-------------------|
| Retroactive eligibility termination | Member was not covered on DOS; claim was paid | MiCPS / MiMember retroactive file |
| Duplicate payment | Same claim paid twice (paper + EDI; or duplicate submission) | MiCPS duplicate detection / post-pay audit |
| COB not applied | Claim paid primary when COB data shows another payer is primary | COB reconciliation job |
| Wrong fee schedule | Incorrect contracted rate applied (e.g., wrong contract tier, wrong plan year rate) | Post-pay audit / pricing validation |
| Retroactive prior auth void | Auth was cancelled or never valid; paid claim must be reviewed | MiAuth retroactive update feed |
| Incorrect DRG assignment | DRG grouper error; post-discharge DRG validation identifies incorrect assignment | DRG validation / post-pay clinical audit |
| Upcoding / billing error (post-audit) | Clinical audit identifies that billed code does not match documented service | SIU / clinical audit program |

> ⚠️ MIVAN-SPECIFIC: Confirm which post-pay audit processes are automated in MiCPS vs. manual. Confirm whether Mivan has a dedicated SIU (Special Investigations Unit) and what triggers SIU referral.

---

### 6d. Overpayment Recovery Process Rules

```
Overpayment Identified and Validated
        │
        ▼
Internal Review
  - Confirm amount, claim(s), root cause
  - Classify: systematic (affects many claims) vs. isolated
        │
        ▼
Provider Notification — Demand Letter
  Required elements:
  - Specific claim ID(s) and date(s) of service
  - Overpayment amount (total and per claim)
  - Reason for overpayment determination
  - Recovery method (offset or direct refund)
  - Response timeline (per contract)
  - Appeal and dispute rights
        │
        ▼
Response Window (typically 30–60 days per contract)
  ├── Provider agrees → offset consent or refund check
  ├── Provider disputes → suspend recoupment; initiate review
  └── No response → proceed per contract terms
        │
        ▼
Recovery Method Applied
  ├── Offset → automatic deduction from future remittances
  ├── Direct refund → provider check or ACH
  └── Escalation → collections / legal (large amounts, non-responding provider)
```

> 📌 REGULATORY SOURCE: CMS Managed Care Overpayment Recoveries Toolkit — [cms.gov/files/document/managed-care-overpayment-recoveries.pdf](https://www.cms.gov/files/document/managed-care-overpayment-recoveries.pdf)

---

### 6e. Offset / Recoupment Rules

| Rule | Description |
|------|-------------|
| Offset amount per remittance | Provider contract specifies maximum offset amount per ERA (e.g., no more than 25% of any single remittance) to prevent financial hardship |
| Interest on overpayment | Some contracts specify interest accrues on uncollected overpayments after the response window; rate is contract-specific |
| Refund vs. offset preference | Payer may offer provider the choice of refund check or offset; offset is more common for ongoing billing relationships |
| Partial offset | If the overpayment amount exceeds a single remittance, offset continues across successive remittances until recovered in full |
| Recoupment suspension during dispute | While an overpayment is under appeal or dispute, recoupment should be suspended per many state laws and CMS MA guidance |

> ⚠️ MIVAN-SPECIFIC: Confirm Mivan's maximum offset-per-remittance cap (if any), interest rate on delinquent overpayments, and whether recoupment is suspended automatically when a dispute is filed.

---

### 6f. State-Specific Recoupment Laws (Key Examples)

> ⚠️ VALIDATE: The following examples are representative; Mivan must confirm applicability based on its specific state footprint and whether each state's law applies to fully-insured commercial, Medicaid managed care, or both.

| State | Key Provisions |
|-------|---------------|
| California | 365-day recoupment look-back for most commercial plans; longer for fraud |
| New York | Recoupment limited to claims within 24 months of original payment date for non-fraud |
| Texas | State law limits retroactive claim adjustments to 12 months from original payment |
| Florida | Prompt pay laws include overpayment dispute rights; recoupment cannot begin until dispute is resolved |
| Illinois | Provider must be given 30 days written notice before offset begins |
| New Jersey | Prohibits recoupment beyond 18 months from date of original payment for non-fraud cases |

> 📌 Sources: State insurance department regulations; individual state prompt pay statutes.

> ⚠️ MIVAN-SPECIFIC: Document the complete list of states where Mivan has fully-insured commercial risk and the applicable recoupment window for each. This is a critical compliance input for the MiCPS OVERPAY module and its cloud-native successor.

---

## Glossary — Business Rules Terms

| Term | Definition |
|------|-----------|
| NCCI | National Correct Coding Initiative — CMS-originated code bundling and edit standard |
| PTP Edit | Procedure-to-Procedure edit — defines code pairs that cannot be billed together |
| MUE | Medically Unlikely Edit — maximum units of service per code per date of service |
| MAI | MUE Adjudication Indicator — determines whether MUE is applied at claim or line level |
| Column 1 / Column 2 | NCCI PTP code pair positions; Column 1 is payable, Column 2 is denied |
| Modifier -59 / -X{EPSU} | NCCI-associated modifiers used to indicate a distinct, separately documented service |
| CARC | Claim Adjustment Reason Code — standard reason code for payment adjustments |
| CO-29 | CARC: Timely filing limit exceeded |
| CO-50 | CARC: Non-covered service |
| CO-197 | CARC: Prior authorization required and absent |
| PR-1/2/3 | CARC: Patient responsibility — deductible / coinsurance / copay |
| UCR | Usual, Customary, and Reasonable — OON pricing benchmark |
| DRG | Diagnosis Related Group — inpatient payment classification unit |
| MS-DRG | Medicare Severity DRG — current CMS inpatient DRG system |
| CC / MCC | Complication or Comorbidity / Major Complication or Comorbidity — DRG severity modifiers |
| Fixed Loss Threshold | Dollar threshold above which outlier payment is triggered for inpatient claims |
| CCR | Cost-to-Charge Ratio — used to estimate actual hospital cost from billed charges |
| NAIC | National Association of Insurance Commissioners — publishes model insurance regulations |
| Birthday Rule | NAIC COB rule: parent with earlier birthday in calendar year is primary for dependent child |
| MSP | Medicare Secondary Payer — federal rule governing when Medicare pays secondary to commercial |
| 60-Day Rule | CMS rule requiring return of identified Medicare/Medicaid overpayments within 60 days |
| False Claims Act | Federal statute imposing treble damages for knowingly retaining government overpayments |
| Recoupment | Recovery of overpayment via deduction from future claim payments |
| Offset | Synonym for recoupment in most commercial contexts |
| Look-Back Period | Maximum period into the past that a payer may recoup; governed by state law or contract |
| SIU | Special Investigations Unit — handles fraud, waste, and abuse investigations |
