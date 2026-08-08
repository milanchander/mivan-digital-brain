---
layer: L2
node_type: domain
domain: medicare-advantage
source: web-research + manual
last_synced: 2026-08-08
validated_by: Digital Brain — pending SME review
fidelity: DRAFT
ghost_node_id: MEDICARE-ADVANTAGE-DOMAIN
links_back:
  - knowledge/L1-enterprise/mivan-enterprise-context.md
links_forward:
  - knowledge/L3-systems/mivan-system-landscape.md
  - knowledge/L5-business-rules/claims-business-rules.md
---

# Medicare Advantage (Part C) — Domain Knowledge
## Mivan Health Plan

> ⚠️ VALIDATE: All sections marked with this flag
> require confirmation against Mivan-specific
> MA contracts and CMS plan agreements before
> treating as authoritative.

---

## 1. Medicare Advantage Overview

### What Is Medicare Advantage
- Medicare Advantage (Part C) is a private plan alternative to Original Medicare (Parts A + B)
- Plans are contracted with CMS and must cover all Medicare-covered services
- Members enroll in a private plan rather than fee-for-service Medicare; CMS pays the plan a risk-adjusted capitation PMPM
- As of 2025, **34+ million enrollees** — representing **54% of all Medicare beneficiaries** (majority for the first time in program history)

### Plan Types
| Type | Description | 2025 Notes |
|---|---|---|
| Local HMO | In-network only; referrals typically required; lowest premiums (avg $11/month MA-PD 2025) | Dominant plan type — >99% of enrollees in local CCPs |
| Local PPO | In- and out-of-network coverage; avg $15/month MA-PD 2025 | Second most common |
| Regional PPO | Multi-county/state service area defined by CMS regions; avg $75/month MA-PD 2025 | Enrollment fell 39% from 2024 to 2025 |
| PFFS (Private Fee-for-Service) | Plan sets payment terms; any provider accepting terms may treat member | Enrollment rose 19% in 2025 |
| SNP (Special Needs Plan) | D-SNP (dual eligibles), C-SNP (chronic conditions), I-SNP (institutional) | ~21% of MA enrollees in 2025; accounted for half of CCP enrollment growth 2024→2025 |
| MSA (Medical Savings Account) | High-deductible plan + CMS-funded savings account | Minimal enrollment |

### Enrollment Periods and Eligibility
- **Eligibility:** Medicare Part A + B enrolled; age 65+ or qualifying disability; must reside in plan's service area
- **Annual Enrollment Period (AEP):** October 15 – December 7 (plan year begins January 1)
- **MA Open Enrollment Period:** January 1 – March 31 (switch MA plans or return to Original Medicare)
- **Special Enrollment Periods:** Qualifying life events (move, loss of coverage, etc.)
- **Geographic requirement:** Plans define county-level service areas approved by CMS; regional PPOs span CMS-defined multi-state regions

### MA Market Structure
- CMS is the regulator and the ultimate payer — sets rules, approves bids, pays capitation
- **Annual bid process:** Plans submit bids each June; CMS publishes Advance Notice (February) and Final Rate Announcement (April 1)
- **Benchmark:** CMS sets county-level benchmarks based on local FFS spending, adjusted for quality bonuses
- **Bid vs benchmark:** If bid < benchmark → plan receives a rebate; if bid > benchmark → member pays a premium
- **Rebate:** Plans must return ≥80% of rebate dollars to enrollees as supplemental benefits, premium reductions, or cost-sharing reductions
- **2025 effective growth rate:** 2.33% for non-ESRD rates (CMS CY2025 Rate Announcement)

### Mivan MA Program
> ⚠️ VALIDATE: Mivan MA plan types, service areas, Star rating history, and TriStar MA Platform involvement

---

## 2. MA Claims vs Commercial Claims

### Key Differences

| Dimension | Commercial | Medicare Advantage |
|---|---|---|
| Primary payer | Employer / individual | CMS via risk-adjusted capitation PMPM |
| Claim submission | 837P/837I to payer | 837P/837I to MA plan |
| Payment basis | FFS — per claim | Capitation — PMPM from CMS |
| Encounter data | Not required | Required — submitted to CMS EDPS |
| Timely filing | State law / contract | MA plan sets limit by contract (typically 90–180 days); no single CMS mandate |
| Coordination | COB with other commercial | Medicare Secondary Payer (MSP) rules |
| Coverage rules | Plan design + state law | CMS NCDs + LCDs + plan design |
| Prior auth | Plan policy | CMS federal oversight; 2026 timeframe reforms |
| Supplemental benefits | Plan-specific | CMS-defined categories; funded from bid rebate |

### Encounter Data vs Claims
- **Encounter data** = all services rendered to MA members, regardless of payment mechanism
- CMS requires full encounter submission for risk adjustment, program integrity, and quality measurement
- **RAPS (Risk Adjustment Processing System):** Legacy system accepting diagnosis-only submissions — **fully phased out in 2024**
- **EDPS (Encounter Data Processing System):** Current sole system; requires full encounter records at the claim level, not just diagnoses
- **Submission deadline:** Full encounters must be submitted within **13 months of Date of Service**
- **Payment model runs (PY2025):**
  - Initial Run: September 6, 2024
  - Midyear: March 7, 2025
  - Interim Final: January 31, 2026
  - Final Run: July 31, 2026
- **Consequences of incomplete submission:** Risk scores understated → reduced capitation PMPM; CMS program integrity flags; RADV audit exposure

### MA Clean Claim Rules (42 CFR §422.520)
- **Clean claim definition:** A claim that can be processed without obtaining additional information from the provider or third party
- **Payment timeframe:** MA organizations must pay **95% of clean claims within 30 days** of receipt (non-contracted providers and PFFS plans)
- **All other non-contracted claims:** Paid or denied within **60 calendar days**
- **Interest on late payments:** Required per 42 CFR §422.520, cross-referencing SSA §1816(c)(2)(B) and §1842(c)(2)(B)
- **Contracted providers:** Prompt payment terms governed by the written provider agreement

---

## 3. Risk Adjustment

### What Is Risk Adjustment
- CMS adjusts capitation payments to reflect member health status — sicker members generate higher PMPM payments
- Incentive for plans to accurately document member conditions
- Plans receive more for enrolling high-risk members; less for low-risk members
- Undercoding reduces capitation; overcoding creates RADV audit exposure

### HCC Coding
- **CMS-HCC model:** Maps ICD-10-CM diagnosis codes to Hierarchical Condition Categories (HCCs)
- Each HCC carries a relative factor that adds to the member's RAF score
- Chronic conditions must be documented by a qualified provider **each plan year** (annual recertification)
- Conditions not recertified in the current year drop from the RAF calculation

### CMS-HCC Model Version Transition (V24 → V28)
| Payment Year | Blend |
|---|---|
| PY2024 | 33% V28 / 67% V24 |
| PY2025 | 67% V28 / 33% V24 |
| PY2026 | **100% V28** |

- **V24:** 86 HCC categories, 9,797 valid ICD-10 codes
- **V28:** 115 HCC categories, 7,770 valid ICD-10 codes — net loss of ~2,027 codes; ~268 new codes added
- **Financial impact:** Projected 2.16% decrease in average risk scores PY2024; 2.45% decrease PY2025
- **Example:** Patient with diabetes + peripheral vascular disease: V24 RAF contribution = 0.590; V28 = 0.166

### Risk Adjustment Factor (RAF) Score
- RAF = sum of demographic factors (age, sex, Medicaid status, disability status) + HCC relative factors
- Average community member RAF ≈ 1.0; higher score = sicker member = higher capitation
- Higher RAF → higher PMPM from CMS → more revenue to cover care costs

### RADV Audits
- **Risk Adjustment Data Validation:** CMS contract-level audit; medical records reviewed to validate HCC submissions
- **2023 Final Rule (published Feb 1, 2023):** Eliminated FFS Adjuster; authorized extrapolation of sample error rates to full contract population; authorized audits back to Payment Year 2018
- **September 2025 legal development:** Federal court **vacated the 2023 final rule** (cited procedural flaws); extrapolation methodology reverted to pre-2023 (2012) standard pending further action
  > ⚠️ VALIDATE: RADV litigation status — confirm current applicable audit methodology before any compliance decisions
- **Medical record review process:** CMS selects random enrollee sample; requests records from providers; coders validate submitted HCCs; unvalidated HCCs drive repayment
- **Plan preparation:** Prospective chart review, coder training, medical record retrieval capabilities

---

## 4. MA Adjudication Differences

### CMS Coverage Determinations
- **National Coverage Determinations (NCDs):** CMS-mandated coverage — MA plans must cover all NCD-mandated services; no plan design overrides
- **Local Coverage Determinations (LCDs):** Issued by Medicare Administrative Contractors (MACs); MA plans must follow or exceed LCD requirements
- **Supplemental benefits:** MA plans may offer vision, dental, hearing, OTC allowances, fitness memberships, home-based care — funded from bid rebate dollars

### Prior Authorization in MA
- **CMS-0057-F (Interoperability and Prior Authorization Final Rule):**
  - Standard PA decisions: **7 calendar days** (reduced from 14) — effective for plan years beginning January 1, 2026
  - Expedited/urgent PA decisions: **72 hours** (unchanged)
  - Plans must provide specific denial reasons
  - Plans must publicly report PA metrics
- **Prior Auth API (FHIR-based):** Required by January 1, 2027 for electronic PA workflows
- **Clinical criteria:** CMS requires MA plans to use evidence-based clinical criteria for PA decisions; increased enforcement scrutiny following OIG audit findings of inappropriate denials
- **Appeals:** Reconsideration → ALJ → Medicare Appeals Council → Federal district court

### MA Timely Filing
- No single CMS-mandated MA provider timely filing limit (unlike Original Medicare's 365 days under 42 CFR §424.44)
- MA plans set timely filing limits by contract — typically **90–180 days** from date of service
  > ⚠️ VALIDATE: Mivan MA plan timely filing limits per contract

### Medicare Secondary Payer in MA
- MSP rules apply to MA members — Medicare (and the MA plan) is secondary when another insurer is primary
- Primary situations: employer group health plan, workers' comp, auto/no-fault, liability insurance
- MA plan must identify MSP situations and coordinate before paying

### Dual Eligible Crossover Claims
- **Full duals** (QMB+Medicaid, SLMB+Medicaid): Medicare primary; Medicaid wraps cost-sharing
- **Partial duals** (QMB-only, SLMB-only, QI): Limited Medicaid assistance with Medicare cost-sharing
- **D-SNPs** (Dual Eligible Special Needs Plans): MA plan designed specifically for dual eligibles; coordinates both Medicare and Medicaid benefits

---

## 5. MA Quality and Star Ratings

### Star Rating Program
- **CMS 5-star rating system:** Plans rated 1–5 stars annually; released each October for the following payment year
- **2025 Star Ratings (released October 2024):**
  - Only **7 plans** earned 5 stars (down from 38 in 2024 — dramatic decline)
  - 86 plans at 4.5 stars; 116 plans at 4 stars
  - Enrollment-weighted average: **3.92** (down from 4.37 in 2022)
- **Quality Bonus Payments (QBP):** Plans ≥3.5 stars qualify; total 2025 QBP ≥ **$13 billion** (~4× the level of 10 years prior)
- **Bonus formula:** Difference between quality-adjusted and base benchmark × retention percentage (65% for 4-star; 70% for ≥4.5-star in 2025)
- **Low-performing plan consequences:** Plans < 3 stars for 3 consecutive years subject to Corrective Action Plan (CAP); persistent poor performance can lead to plan non-renewal

### HEDIS and Quality Measures
- **HEDIS** (Healthcare Effectiveness Data and Information Set): Maintained by NCQA; ~90 measures across 6 domains; updated annually
- **Star weight (2027):** HEDIS measures will drive **~26% of overall Star Rating** — the largest single driver
- **Key MA HEDIS Star measures:**
  - Controlling High Blood Pressure (CBP)
  - Comprehensive Diabetes Care (CDC) — multiple sub-measures
  - Breast Cancer Screening (BCS)
  - Colorectal Cancer Screening (COL)
  - Annual Flu Vaccine
  - Medication Adherence (Part D — Diabetes, RAS Antagonists, Statins)
- **Claims data limitation:** Claims alone are insufficient for many HEDIS measures (e.g., blood pressure reading has no billable claim); plans must supplement with lab results and medical records (hybrid methodology)
- **Gaps in care:** Plans run gap reports from claims data to identify members missing preventive services; outreach closes gaps before the measurement year ends

---

## 6. MA-Specific MiCPS Implications

> ⚠️ VALIDATE: All items in this section require
> confirmation with the MiCPS operations team

### What MiCPS Does for MA
- L1 states MA is adjudicated by the **TriStar MA Platform** — confirm whether MiCPS is involved in MA claim processing or is purely commercial/Medicaid
  > ⚠️ VALIDATE: MiCPS involvement in MA adjudication

### Encounter Data Submission
- How MiCPS-adjudicated data (if any) feeds the MA EDPS encounter submission process
- Which MiCPS batch feeds (if any) support MA encounter data
- CMS submission deadlines: 13 months from DOS; Final Run July 31 of the year following the payment year

### Risk Adjustment Data Flow
- How diagnosis codes from MiCPS claims (if applicable) reach EDPS for HCC risk scoring
- HCC coding quality — impact of MiCPS claim edits on diagnosis code accuracy and RAF scores
- V28 transition impact — review which ICD-10 codes dropped between V24 and V28 that may affect current coding workflows

---

## Glossary — Medicare Advantage Terms

| Term | Definition |
|---|---|
| Part C | Medicare Advantage — private plan alternative to Original Medicare Parts A + B |
| Capitation | Fixed PMPM payment from CMS to MA plan, risk-adjusted by member RAF score |
| HCC | Hierarchical Condition Category — CMS diagnosis grouping for risk adjustment |
| RAF | Risk Adjustment Factor — member risk score driving capitation amount; avg community member ≈ 1.0 |
| RADV | Risk Adjustment Data Validation — CMS audit of MA risk adjustment submissions |
| RAPS | Risk Adjustment Processing System — legacy diagnosis-only submission system; phased out 2024 |
| EDPS | Encounter Data Processing System — current CMS full encounter submission system |
| NCD | National Coverage Determination — CMS-mandated coverage policy; MA plans must comply |
| LCD | Local Coverage Determination — MAC-level coverage policy; MA plans must follow or exceed |
| Star Rating | CMS 1–5 star quality rating; ≥3.5 stars qualifies for Quality Bonus Payment |
| QBP | Quality Bonus Payment — benchmark uplift for plans ≥3.5 stars; $13B+ total in 2025 |
| HEDIS | Healthcare Effectiveness Data and Information Set — NCQA quality measurement framework |
| SNP | Special Needs Plan — MA plan for specific populations (dual, chronic, institutional) |
| D-SNP | Dual Eligible Special Needs Plan — MA plan for Medicare-Medicaid dual eligibles |
| PFFS | Private Fee-for-Service — MA plan type where plan sets provider payment terms |
| MSA | Medical Savings Account — high-deductible MA plan paired with CMS-funded savings account |
| Benchmark | CMS county-level payment rate used in MA bid process |
| Rebate | Portion of MA plan savings (bid below benchmark) returned to enrollees; ≥80% required |
| AEP | Annual Enrollment Period — October 15 to December 7 |
| MSP | Medicare Secondary Payer — rules defining when Medicare is secondary to another payer |
| CMS-HCC V28 | Current HCC risk adjustment model version; 100% effective PY2026 |
| CAP | Corrective Action Plan — required for MA plans < 3 stars three years running |
