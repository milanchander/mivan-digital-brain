---
layer: L2
node_type: domain
domain: medicaid
source: web-research + manual
last_synced: 2026-08-08
validated_by: Digital Brain — pending SME review
fidelity: DRAFT
ghost_node_id: MEDICAID-DOMAIN
links_back:
  - knowledge/L1-enterprise/mivan-enterprise-context.md
links_forward:
  - knowledge/L3-systems/mivan-system-landscape.md
  - knowledge/L5-business-rules/claims-business-rules.md
---

# Medicaid Managed Care — Domain Knowledge
## Mivan Health Plan

> ⚠️ VALIDATE: All sections marked with this flag
> require confirmation against Mivan's specific
> state Medicaid contracts before treating
> as authoritative.

---

## 1. Medicaid Overview

### What Is Medicaid
- Federal-state partnership program providing health coverage to low-income individuals, families, people with disabilities, and the elderly
- Jointly funded: federal government pays a share (FMAP) of each state's Medicaid costs
- **Enrollment:** ~66.7M Medicaid + 7.1M CHIP as of recent reporting (peaked at ~94M in March 2023 at end of COVID continuous enrollment); ~87M enrolled in 2024 at its high
- **ACA Medicaid Expansion:** 40 states + DC have expanded; 138% FPL effective threshold (133% FPL statutory + 5% income disregard); ~1.4M uninsured remain in the coverage gap in the 10 non-expansion states

### Federal Match (FMAP)
- FMAP (Federal Medical Assistance Percentage) — federal share of Medicaid expenditures
- **Range:** 50%–83% by statute (based on inverse per-capita-income formula)
- **Floor:** 50% (wealthier states); **ceiling:** 76.9% (Mississippi, highest regular FMAP)
- Enhanced FMAP applies to specific populations (expansion adults, CHIP) and programs (FMAP + 23 percentage points for expansion adults)

### Waiver Programs
| Waiver | Authority | Purpose | Term |
|---|---|---|---|
| 1115 | Broad demonstration | Waives statutory Medicaid requirements; statewide scope; requires budget neutrality | 5 years; renewable |
| 1915(b) | Managed care mandate | Requires MCO enrollment; restricts freedom of choice; must be cost-effective | 2 years; renew up to 2 years |
| 1915(c) | HCBS waiver | Home/community-based services as alternative to institutional care; budget neutrality; NF level of care required | 3 years; renew up to 5 years |

### Medicaid Managed Care Structure
- **~84.8% of Medicaid enrollees** receive care through managed care plans as of 2024
- States contract with MCOs (Managed Care Organizations); pay a fixed capitation PMPM per enrollee
- MCO rationale: cost predictability for states, care coordination, quality improvement incentives
- **Capitation rates:** Must be actuarially sound per 42 CFR 438.4; built to achieve ≥85% MLR
- **MLR (42 CFR 438.8):** 85% federal standard — states may mandate binding MLR with remittance requirements; plans missing the threshold remit excess margin to the state
- **Risk corridors:** State-optional shared savings/loss mechanism; used on new populations or programs
- **T-MSIS:** Transformed Medicaid Statistical Information System — CMS national repository; states submit encounter, eligibility, and claims data; replaced legacy MSIS

### Mivan Medicaid Program
> ⚠️ VALIDATE: Mivan Medicaid state footprint and population breakdown (TANF, CHIP, expansion, ABD). (Medicaid is adjudicated on MiFCT / TriZetto Facets — see §7.)

---

## 2. Medicaid Claims Differences

### Key Differences from Commercial

| Dimension | Commercial | Medicaid MCO |
|---|---|---|
| Eligibility | Employer / individual enrollment | State eligibility determination |
| Eligibility changes | Annual open enrollment | Monthly — can change every month |
| Primary payer | Commercial plan | Medicaid MCO (capitated by state) |
| Coordination | COB with other commercial | Medicaid is always payer of last resort |
| Timely filing | State law / contract | State contract — typically 90–365 days |
| Covered services | Plan design | State Medicaid benefit package |
| Prior auth | Plan policy | State-directed PA requirements (42 CFR 438.210) |
| Encounter data | Not required | Required — submitted to state MMIS / T-MSIS |
| Claims format | 837P/837I | 837P/837I — same HIPAA format |

### Medicaid Eligibility Complexity
- **Monthly eligibility churn:** Medicaid redetermines eligibility monthly; members gain/lose coverage mid-cycle; creates claims adjudication complexity at time-of-service verification
- **Retroactive eligibility:** States may grant Medicaid up to 3 months prior to application month; creates retroactive claims obligations for MCOs
- **Spend-down members:** Eligibility based on incurring medical expenses to bring income to Medicaid level; billing complexity — member is eligible only after spend-down threshold is met
- **Dual eligibles:** ~12.1M nationally (~20% of Medicare beneficiaries); represent ~15% of Medicaid enrollees but ~33% of Medicaid spending
- **CHIP:** Children's Health Insurance Program — covers children in families above Medicaid limits; ~7.1M enrolled; separate claim adjudication rules in some states

### Encounter Data to State MMIS / T-MSIS
- **42 CFR 438.818:** MCOs must submit enrollee encounter data to the state; state validates and submits to CMS via T-MSIS
- Covers all services rendered to members regardless of direct MCO payment
- Used for rate setting, program integrity, quality reporting, and federal research
- Submission timelines are state-specific
- **Consequences of non-compliance:** CMS may defer or disallow federal matching funds; states may withhold capitation from non-compliant plans; civil monetary penalties available

---

## 3. Medicaid-Specific Benefit Structures

### EPSDT — Early Periodic Screening Diagnosis Treatment
- **Authority:** OBRA 1989; Section 1905(r) of the Social Security Act
- **Mandatory** for all Medicaid enrollees birth through 20 years 364 days
- **Scope:** States must cover any medically necessary service listed in Section 1905(a) identified during a screening — goes beyond standard Medicaid plan benefits; plan design cannot restrict EPSDT services
- **Screening components (Periodicity Schedule per AAP Bright Futures):**
  - Well-child exams and developmental/behavioral assessments
  - Immunizations
  - Vision and hearing screenings
  - Dental examinations
  - Lab tests (lead screening, hemoglobin, etc.) at age-specific intervals
- **Dental:** Mandatory under EPSDT — diagnostic, preventive, and restorative dental services required
- **Mental health:** Covered as medically necessary under EPSDT; behavioral health parity applies
- **Claims coding difference:** EPSDT indicator field (EPSDTConditionCode on 837P loop 2300 CLM05-3) identifies claim as EPSDT-triggered; affects coverage adjudication logic

### LTSS — Long Term Services and Supports
- **Home and community-based services (HCBS):** Personal care, respite, adult day, supported employment, home modifications — provided under 1915(c) HCBS waivers
- **Institutional care:** Nursing facility (NF), ICF/IID (Intermediate Care Facility for Individuals with Intellectual Disabilities)
- **MLTSS (Managed LTSS):** States increasingly integrating both HCBS and institutional LTSS into MCO contracts
- **Person-centered care plans:** Federal requirement for HCBS waiver programs; member-driven; documented annually
- **EVV (Electronic Visit Verification):** Mandated by 21st Century Cures Act §12006
  - Personal Care Services: required by January 1, 2020
  - Home Health Care Services: required by January 1, 2023
  - Captures: service type, date, GPS location, individual receiving service, provider, start/end time
  - Non-compliant states receive reduced federal Medicaid funding
- **LTSS claims billing:** Non-medical services use T-codes and S-codes; billed in units (15-minute, daily, monthly); revenue codes differ from medical claims

### Behavioral Health
- Carved-in (MCO covers BH) vs carved-out (separate BH MCO) varies by state
- BH parity requirements apply — comparable to medical/surgical benefits
- Crisis services required in managed care contracts

### Dental and Vision
- Adult dental — optional state benefit; covered in most states to some degree
- EPSDT dental — mandatory for members under 21
- Vision — state-specific; mandatory for EPSDT-eligible members

---

## 4. Medicaid Prior Authorization

### State-Directed Prior Authorization
- **42 CFR 438.210:** States must establish PA criteria; MCOs cannot arbitrarily deny or limit required services; written criteria required
- **Current timeframes (pre-2026):**
  - Standard: **14 calendar days** (may extend up to 14 additional days with justification)
  - Expedited/urgent: **72 hours**

### CMS-0057-F — Prior Authorization Reform (Effective January 1, 2026)
- Standard PA decisions: reduced to **7 calendar days** (down from 14)
- Expedited decisions: **72 hours** (unchanged)
- Plans must provide specific reason for denial
- Plans must publicly report PA metrics (approval rates, denial rates, decision times) annually
- **FHIR-based Prior Authorization API:** Required by January 1, 2027 (HL7 FHIR R4)
- Applies to Medicaid MCOs, CHIP, MA plans, and QHP issuers on FFEs

---

## 5. Medicaid Quality and Reporting

### HEDIS for Medicaid
Key Medicaid HEDIS measures:
- Well-Child Visits (1st 15 months of life; 3–6 years)
- Childhood Immunization Status
- Adolescent Well-Care Visits
- Prenatal and Postpartum Care
- Follow-up After Hospitalization for Mental Illness
- Controlling High Blood Pressure
- Childhood and Adolescent BMI Assessment
- Medication Management for Asthma

### CAHPS
- Consumer Assessment of Healthcare Providers and Systems
- Member experience surveys — required in Medicaid MCO contracts
- Domains: getting needed care, getting care quickly, communication, care coordination

### State Quality Withhold Programs
- States increasingly withhold 1–2% of capitation and return based on quality performance:
  - Mississippi: 1% withhold since SFY 2020; increasing to 2% in SFY 2026
  - California: Quality Withhold and Incentive Program launched CY 2024
  - Missouri: Performance Withhold Program tied to HEDIS targets
- **Value-based payment:** CMS encourages states to require MCOs to pass through 50–80% of capitation to providers under VBP arrangements

### State Reporting Requirements
- Encounter data submission to state MMIS + T-MSIS
- Quality measure reporting (HEDIS, CAHPS)
- Network adequacy reporting
- MLR reporting

---

## 6. Medicaid Coordination — Payer of Last Resort

### Medicaid as Last Resort
- **Federal law (42 CFR Part 433 Subpart D):** Medicaid is payer of last resort; states must have a TPL program
- **42 CFR 433.136:** "Third party" = any individual, entity, or program liable for Medicaid service costs — includes private health insurance, employer-sponsored plans, auto insurance, workers' comp, tort liability, TRICARE
- **Cost avoidance:** When other insurance is known at point of service, Medicaid denies the claim; provider bills primary payer first; preferred for known ongoing coverage
- **Pay and chase:** Medicaid pays the claim, then pursues recovery from the liable third party; used when TPL is uncertain, for trauma/injury cases; required for prenatal care (OBRA 90 prohibits cost-avoidance of prenatal claims)
- **MCO TPL obligations:** Identify TPL during eligibility verification; maintain subrogation rights; pursue TPL recovery; report savings to state
- **Data sources for TPL identification:** State HIX matching, employer reporting (Section 111 MMSEA), data brokers, provider COB forms

### Dual Eligible Members
- **Fully dual:** Medicare + full Medicaid; Medicaid covers Medicare premiums (Parts A/B), deductibles, and coinsurance
- **Partial dual:** Medicare + limited Medicaid cost-sharing assistance (QMB-only, SLMB-only, QI categories)
- **D-SNP (Dual Eligible Special Needs Plans):** MA plans designed for dual eligibles; 6.6M+ enrollees across ~1,400+ plans; require Medicaid MCO coordination agreements
- **Crossover claims:** Medicare pays first; claim crosses over to Medicaid (via Medicare's automated crossover process) for cost-sharing wrap; Medicaid pays only cost-sharing amounts
- **2025 change:** Starting January 1, 2025, D-SNPs must pay both Medicare and Medicaid portions simultaneously for aligned members in certain states — eliminates traditional crossover workflow for those populations
- **PACE:** Program of All-Inclusive Care for the Elderly — fully integrated Medicare/Medicaid for frail elderly meeting NF level of care; receives combined capitation from both programs

---

## 7. Medicaid Platform & Implementation (MiFCT)

**Medicaid claims are adjudicated by MiFCT (Mivan Facets Claims Technology / TriZetto Facets), not MiCPS.** MiCPS handles commercial claims only. MiEDI routes Medicaid claims (LOB code `MC`) to the MiFCT Medicaid intake queue. See L3 "MiFCT — Government Claims Platform" and "LOB Routing Architecture".

### Post-Adjudication Reporting — MedicaidStateReportingService
After MiFCT adjudicates a Medicaid claim, it calls `MedicaidStateReportingService` (`src/java/medicaid/`) via REST to handle state reporting obligations. This is a post-adjudication reporting service — it does not adjudicate claims.

- Third party liability (TPL) identification
- Payer of last resort calculation (42 CFR 433.139)
- Medicaid liability calculation
- **State MMIS encounter data submission**

### Encounter Data Flow
- Adjudicated Medicaid claims from MiFCT flow to `MedicaidStateReportingService`, which stages and submits encounters to state MMIS / T-MSIS
- State-specific submission requirements for Mivan's Medicaid contracts are applied during state MMIS submission

> ⚠️ VALIDATE: MiFCT (Facets) Medicaid benefit-plan configuration and the MiFCT → `MedicaidStateReportingService` integration contract (see ghost nodes MIFCT-CONFIGURATION, MIFCT-POSTADJ-INTEGRATION).

---

## Glossary — Medicaid Terms

| Term | Definition |
|---|---|
| MCO | Managed Care Organization — private plan contracted by state to provide Medicaid services |
| MMIS | Medicaid Management Information System — state claims processing and data system |
| T-MSIS | Transformed Medicaid Statistical Information System — CMS national Medicaid data repository |
| FMAP | Federal Medical Assistance Percentage — federal match rate; range 50%–83% |
| MLTSS | Managed Long Term Services and Supports — LTSS integrated into MCO contracts |
| EPSDT | Early Periodic Screening Diagnosis Treatment — comprehensive mandatory benefit for members under 21 |
| LTSS | Long Term Services and Supports — home, community, and institutional care services |
| HCBS | Home and Community-Based Services — 1915(c) waiver services as alternative to institutional care |
| ABD | Aged, Blind, and Disabled — SSI-related Medicaid eligibility category |
| TANF | Temporary Assistance for Needy Families — low-income family eligibility category |
| CHIP | Children's Health Insurance Program — coverage for children above Medicaid income limits |
| TPL | Third Party Liability — any payer that is liable before Medicaid |
| D-SNP | Dual Eligible Special Needs Plan — MA plan for Medicare-Medicaid dual eligibles |
| 1115 Waiver | Broad demonstration waiver allowing state flexibility beyond standard Medicaid rules |
| 1915(c) | HCBS waiver authority — home and community-based services |
| Spend-down | Eligibility where member incurs medical expenses to bring income to Medicaid level |
| Crossover Claim | Claim where Medicare pays first and Medicaid pays cost-sharing remainder |
| MLR | Medical Loss Ratio — percentage of premium/capitation spent on care; 85% federal standard for Medicaid MCOs |
| Capitation | Fixed PMPM payment from state to MCO regardless of services used |
| Risk Corridor | Shared savings/loss mechanism between state and MCO |
| EVV | Electronic Visit Verification — GPS/time-stamped attendance capture for HCBS personal care and home health |
| PACE | Program of All-Inclusive Care for the Elderly — fully integrated Medicare/Medicaid capitated program |
