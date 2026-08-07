---
layer: L4
node_type: application
domain: claims
app_id: micps
last_validated: 2026-08-07
validated_by: "James Whitfield — pending review"
fidelity: DRAFT
source_count_declared: 8
source_count_captured: 2
owns:
  - ADJUD-MAIN
  - MADJDRV0
  - MELIGDR0
  - MCLMPR0
  - MOVPDUP1
  - MOVPDUP0
  - CLAIM_PAYMENT table
  - NEAR_DUP_QUEUE table
  - ADJUD-WRK VSAM file
  - ACCUM-FILE VSAM file
  - CLMPAYRC.cpy copybook
  - NDUPQREC.cpy copybook
implements:
  - L5-business-rules/claims-business-rules.md
links_back:
  - L3-systems/mivan-system-landscape.md
links_forward:
  - L5-business-rules/claims-business-rules.md
  - L6-task-intelligence/5-day-training-agenda.md
  - L6-task-intelligence/5-day-training-agenda-java-track.md
  - L6-task-intelligence/5-day-training-agenda-qe-track.md
ghost_nodes:
  - Module 7 COB program detail and rule table
  - Module 8 Provider Maintenance program inventory
  - Complete DB2 table catalog with column definitions
  - Complete VSAM file inventory with IDCAMS output
  - JCL job dependency chain and scheduler configuration
  - Hardcoded parameter audit and externalisation plan
  - Performance tuning parameters and capacity baselines
---

# MiCPS Application Knowledge
## Mivan Claims Processing System — Module-Level Reference

> **Status:** This document is a structured template. All sections marked
> `[TO BE POPULATED WITH MIVAN DOMAIN EXPERTISE]` require input from
> Mivan subject matter experts — primarily James Whitfield and the
> MiCPS operations and QE teams.
>
> **Priority:** Sections marked `⚠️ HIGH PRIORITY` contain the highest
> concentration of tribal knowledge and represent the greatest attrition
> risk. These should be populated first.

---

## Table of Contents

1. [Claims Intake & Editing](#module-1-claims-intake--editing)
2. [Eligibility & Benefits](#module-2-eligibility--benefits)
3. [Adjudication Engine](#module-3-adjudication-engine)
4. [Pricing / Fee Schedule](#module-4-pricing--fee-schedule)
5. [Claims Payment](#module-5-claims-payment)
6. [Coordination of Benefits (COB)](#module-6-coordination-of-benefits-cob)
7. [Overpayment & Recovery](#module-7-overpayment--recovery)

---

## Module 1: Claims Intake & Editing

### 1.1 Module Overview

**Purpose:** Receives inbound X12 837P and 837I EDI files from the MiEDI clearinghouse gateway, parses and validates claim records, applies front-end editing rules, and routes clean claims into the adjudication queue.

**Scope:**
- EDI 837P (professional) and 837I (institutional) ingestion
- Syntax and HIPAA compliance validation
- NCCI PTP and MUE edits
- Clinical code-pair edits (sex, age, diagnosis-procedure conflicts)
- Payer-specific business edits
- Claim routing to adjudication or rejection back to provider

**Processing Mode:** Batch (JCL-driven overnight)

**Position in Pipeline:** First module — no upstream MiCPS dependency. Downstream: Eligibility & Benefits.

---

### 1.2 Key COBOL Programs

> ⚠️ HIGH PRIORITY — All entries [VALIDATE WITH SME]

| Program Name | Function | Calls / Called By | Notes |
|-------------|----------|------------------|-------|
| `MEDIPRS0` | EDI 837 parser — reads EDI-STAGE ESDS, extracts loop/segment data, writes parsed claim records to CLAIM-WRK ESDS | First program in CLAIM-INTAKE job stream | Handles both 837P and 837I; record type determined by CLM05 bill type [VALIDATE WITH SME] |
| `MFMTVAL0` | Format validation — HIPAA syntax checks, required field presence, NPI format validation | Called after MEDIPRS0 | Rejects written to REJECT-FILE ESDS with TA1/999 reason codes [VALIDATE WITH SME] |
| `MNCCIED0` | NCCI edit engine — applies PTP and MUE edits against NCCI-TABLE KSDS | Called after MFMTVAL0 | NCCI table loaded quarterly from CMS update; override logic via NCCI-OVRD KSDS [VALIDATE WITH SME] |
| `MCLINDT0` | Clinical edit engine — sex/age/diagnosis-procedure conflict edits | Called after MNCCIED0 | Edit rules in DB2 CLINICAL_EDIT table; updated with each ICD-10/CPT annual release [VALIDATE WITH SME] |
| `MBUSNED0` | Business edit engine — payer-specific edits, auth required flags, frequency limits | Called after MCLINDT0 | Mix of DB2 table-driven and hardcoded COBOL logic for legacy plan codes [VALIDATE WITH SME] |
| `MRJCTWR0` | Rejection writer — generates 999 rejection response and writes to provider rejection queue | Called for any claim failing edits | Rejection reason codes mapped to X12 999 error codes [VALIDATE WITH SME] |

---

### 1.3 Key DB2 Tables

> All entries [VALIDATE WITH SME]

| Table Name | Purpose | Key Fields | Relationships |
|-----------|---------|-----------|--------------|
| `EDI_RECEIPT` | Claim receipt log — every 837 received with timestamp | CLAIM_ID, RECEIPT_DT, TRADING_PARTNER_ID, FILE_ID | Used for timely filing determination; CLAIM_ID joins to CLAIM_HEADER |
| `CLINICAL_EDIT` | Clinical edit rules — sex/age/procedure conflict definitions | EDIT_CD, PROC_CD, DIAG_CD, SEX_CD, AGE_MIN, AGE_MAX | Read by MCLINDT0; updated annually at ICD-10/CPT release |
| `NCCI_OVERRIDE` | Approved NCCI edit overrides by plan or provider | NPI, PROC_CD_1, PROC_CD_2, OVERRIDE_REASON, EFFECTIVE_DT | Read by MNCCIED0 after standard NCCI check; no expiry enforcement — see Known Complexity |
| `REJECT_LOG` | All rejected claims with reason codes | CLAIM_ID, REJECT_DT, EDIT_TYPE, REJECT_REASON_CD | Written by MRJCTWR0; feeds provider portal rejection display via MiPortal batch extract |

---

### 1.4 Batch Jobs

> All entries [VALIDATE WITH SME]

| JCL Job Name | Function | Schedule | Upstream Dependency | Downstream Dependency |
|-------------|---------|---------|--------------------|--------------------|
| `MINTAKE0` | EDI file intake and parsing — invokes MEDIPRS0 and MFMTVAL0 | Nightly — first job in batch stream | EDI file arrival from MiEDI (CA7 file trigger) | `MEDITV00` (edit validation) |
| `MEDITV00` | Edit validation — NCCI, clinical, and business edits (MNCCIED0, MCLINDT0, MBUSNED0) | Nightly — after MINTAKE0 | `MINTAKE0` completion | `MELIGV00` (eligibility verification) |
| `MNCCILD0` | NCCI table load — loads quarterly CMS NCCI update into NCCI-TABLE KSDS | Quarterly — manual trigger by edit analyst | Approved CMS NCCI file delivered to staging | None — reference data update only |

---

### 1.5 Known Complexity Areas

> ⚠️ HIGH PRIORITY — All entries [VALIDATE WITH SME]

| Area | Description | Knowledge Owner | Risk |
|------|-------------|----------------|------|
| NCCI override management | NCCI-OVRD KSDS contains plan- and provider-specific overrides accumulated over 15+ years; no expiry date enforcement; some overrides may no longer be valid but remain active [VALIDATE WITH SME] | Senior edit analyst | High |
| MBUSNED0 legacy plan logic | Several legacy commercial plan codes have hardcoded business edit bypasses in MBUSNED0 — these plans predate the DB2 edit table and were never migrated to table-driven rules [VALIDATE WITH SME] | James Whitfield | High |
| Split claim trigger logic | Claims that span two benefit years are split by MFMTVAL0 using hardcoded calendar year logic — leap year handling has a known defect that surfaces every 4 years [VALIDATE WITH SME] | QE team | Medium |

---

### 1.6 Modernization Status

| Attribute | Detail |
|-----------|--------|
| Migration Wave | Wave 3 (planned) |
| Current Status | Pending |
| Cloud Target | Java 21 / Spring Boot — Claims Intake Service on EKS |
| Key Dependency | NCCI/MUE table management strategy must be defined before migration |
| Blocker | MBUSNED0 hardcoded legacy plan edit bypasses must be fully documented and converted to DB2 CLINICAL_EDIT/business rules before the cloud intake service can be designed; NCCI-OVRD KSDS override inventory requires audit and expiry date backfill [VALIDATE WITH SME] |

---

---

## Module 2: Eligibility & Benefits

### 2.1 Module Overview

**Purpose:** Verifies that the member was actively covered on the date of service, retrieves the member's benefit structure (deductible, copay, coinsurance, OOP max, plan exclusions), and updates accumulator state for use in cost-share calculation.

**Scope:**
- Member active status check against enrollment effective and termination dates
- Plan and product identification (HMO, PPO, HDHP)
- Benefit structure retrieval (coverage tiers, cost-share parameters)
- Year-to-date accumulator lookup (deductible met, OOP max reached)
- COB indicator check — flag claims with other coverage for COB module
- Routing of ineligible claims to denial

**Processing Mode:** Batch (JCL) + CICS (real-time eligibility query from provider portal)

**Position in Pipeline:** Upstream: Claims Intake & Editing. Downstream: Adjudication Engine.

---

### 2.2 Key COBOL Programs

> ⚠️ HIGH PRIORITY — All entries [VALIDATE WITH SME]

| Program Name | Function | Calls / Called By | Notes |
|-------------|----------|------------------|-------|
| `MELIGDR0` | Eligibility driver — reads CLAIM-WRK ESDS, calls member lookup and benefit retrieval subprograms | Called by `MELIGV00` JCL job | Passes eligibility result and benefit parameters back to CLAIM-WRK for downstream modules [VALIDATE WITH SME] |
| `MMEMBLK0` | Member lookup — reads MEMBER-IDX KSDS by member ID; returns enrollment record pointer | Called by MELIGDR0 | Member not found → routes to DENY with CO-31; found → retrieves effective/termination dates [VALIDATE WITH SME] |
| `MBENFET0` | Benefit retrieval — reads DB2 BENEFIT_PARAMS table by plan code and product; returns cost-share parameters | Called by MELIGDR0 after MMEMBLK0 | Deductible, OOP max, copay by service type, in/out of network tiers [VALIDATE WITH SME] |
| `MACCUML0` | Accumulator lookup — reads ACCUM-FILE KSDS; returns YTD deductible-met and OOP-max-reached flags | Called by MELIGDR0 after MBENFET0 | Most write-intensive read in eligibility pass; ACCUM-FILE concurrency issue documented in L3 [VALIDATE WITH SME] |
| `MRETROE0` | Retroactive termination handler — checks for retroactive membership terminations posted since last batch; flags affected claims for reprocess | Called by MELIGDR0 when termination date < DOS | Retroactive lookback window is hardcoded at 90 days — claims beyond 90 days are not reprocessed automatically [VALIDATE WITH SME] |
| `MCOBFLG0` | COB flag check — reads MEMBER-IDX COB indicator; flags claim for COB module if other coverage exists | Called by MELIGDR0 | COB indicator set by MiMember nightly feed; real-time COB updates not supported [VALIDATE WITH SME] |

---

### 2.3 Key DB2 Tables

> All entries [VALIDATE WITH SME]

| Table Name | Purpose | Key Fields | Relationships |
|-----------|---------|-----------|--------------|
| `BENEFIT_PARAMS` | Plan and product benefit structure — cost-share parameters by service type | PLAN_CD, PRODUCT_CD, SERVICE_TYPE_CD, DEDUCTIBLE_AMT, OOP_MAX_AMT, COPAY_AMT, COINS_PCT, IN_NETWORK_IND | Primary input to MBENFET0; joins to CLAIM_HEADER via PLAN_CD |
| `PLAN_YEAR` | Plan year effective dates by plan code | PLAN_CD, PLAN_YEAR_START_DT, PLAN_YEAR_END_DT | Used for accumulator reset logic and benefit year determination; referenced by MACCURS0 |
| `RETRO_TERM_LOG` | Retroactive termination events posted by MiMember feed | MEMBER_ID, TERM_DT, POSTED_DT, REPROCESS_STATUS | Written by MMEMLD00 from MiMember SFTP feed; read by MRETROE0 during eligibility pass |

---

### 2.4 Batch Jobs

> All entries [VALIDATE WITH SME]

| JCL Job Name | Function | Schedule | Upstream Dependency | Downstream Dependency |
|-------------|---------|---------|--------------------|--------------------|
| `MMEMLD00` | MiMember enrollment file load — refreshes MEMBER-IDX KSDS from nightly MiMember SFTP feed | Nightly — start of batch window | MiMember SFTP file arrival | `MELIGV00` |
| `MELIGV00` | Eligibility and benefits verification — invokes MELIGDR0 and all subprograms | Nightly — after MEDITV00 | `MEDITV00` completion + `MMEMLD00` completion (MEMBER-IDX refreshed) | `MADJMN00` (adjudication) |
| `MACCURS0` | Annual accumulator reset — zeros YTD accumulators in ACCUM-FILE at plan year start per PLAN_YEAR table | Annual — plan year start date; manual trigger by operations with DBA approval | DBA approval + CICS quiesce (requires exclusive VSAM access) | All downstream modules — highest-impact job in MiCPS batch calendar |

---

### 2.5 Known Complexity Areas

> ⚠️ HIGH PRIORITY — All entries [VALIDATE WITH SME]

| Area | Description | Knowledge Owner | Risk |
|------|-------------|----------------|------|
| MACCURS0 annual reset | Plan year reset updates every record in ACCUM-FILE — longest-running single job in MiCPS; requires exclusive VSAM access; CICS must be fully quiesced; any abend during reset leaves accumulators in partially zeroed state requiring manual DBA recovery [VALIDATE WITH SME] | DBA + operations | Critical |
| Family accumulator logic | Family deductible and OOP max tracking embedded in ACCUM-FILE record structure alongside individual accumulators; layout partially undocumented; family vs. individual threshold logic lives in MACCUML0 and is not in any design document [VALIDATE WITH SME] | James Whitfield | Critical |
| Newborn auto-coverage | 30-day newborn auto-coverage implemented as hardcoded date logic in MMEMBLK0 — if member age < 31 days and no enrollment record found, auto-coverage flag is set; edge cases around premature birth dates are unhandled [VALIDATE WITH SME] | Senior eligibility SME | High |
| Retroactive termination window | MRETROE0 lookback window is hardcoded at 90 days — claims older than 90 days affected by a retroactive termination are not automatically reprocessed and require manual intervention; no alerting when claims fall outside window [VALIDATE WITH SME] | Operations team | High |

---

### 2.6 Modernization Status

| Attribute | Detail |
|-----------|--------|
| Migration Wave | Wave 1 (in flight) |
| Current Status | In flight — Eligibility Validation service being built |
| Cloud Target | Java 21 / Spring Boot — Eligibility Service on EKS; DynamoDB for accumulator state |
| Key Dependency | ACCUM-FILE VSAM layout must be fully documented before cloud accumulator service can be built |
| Blocker | ACCUM-FILE VSAM layout (including family accumulator record structure) must be fully documented before the cloud DynamoDB accumulator service can be designed; MACCUML0 family threshold logic requires paired reverse-engineering sessions with James Whitfield [VALIDATE WITH SME] |

---

---

## Module 3: Adjudication Engine

### 3.1 Module Overview

**Purpose:** The core decision engine of MiCPS. Determines whether each claim is covered, checks prior authorization status, applies medical necessity screening, routes claims to auto-adjudication or manual review queues, and produces an adjudication decision (pay, deny, pend, suspend) for each claim and service line.

**Scope:**
- Coverage determination (plan exclusions, benefit limitations)
- Prior authorization validation
- Medical necessity screening
- Auto-adjudication vs. manual review routing
- Denial code assignment (CARC / RARC)
- Pend and suspend queue management
- Manual adjudicator workstation (CICS)

**Processing Mode:** Batch (JCL) — primary volume. CICS — manual adjudicator interface.

**Position in Pipeline:** Upstream: Eligibility & Benefits. Downstream: Pricing / Fee Schedule (for approved claims), COB.

> ⚠️ HIGH PRIORITY — This is the highest-complexity module in MiCPS. The majority of tribal knowledge risk is concentrated here.

---

### 3.2 Key COBOL Programs

> ⚠️ [VALIDATE WITH JAMES WHITFIELD] — Program names, call chains, and behavioral notes below are based on typical IBM z/OS mainframe adjudication patterns and must be validated against actual MiCPS source code.

| Program Name | Function | Calls / Called By | Notes |
|-------------|----------|------------------|-------|
| MADJDRV0 | Main adjudication driver — reads CLAIM-WRK ESDS sequentially, determines processing path per claim, calls subprograms | Called by JCL ADJUD-MAIN step 1; calls MCOVDET0, MAUTHCK0, MROUTNG0 | Single driver pattern; controls overall adjudication loop |
| MCOVDET0 | Coverage determination — evaluates plan exclusions, benefit limitations, service type coverage | Called by MADJDRV0 | Table-driven via DB2 COVERAGE_POLICY table + inline COBOL EVALUATE for edge cases |
| MAUTHCK0 | Prior authorization validation — reads AUTH-FILE KSDS by auth number; validates procedure, provider, date range match | Called by MADJDRV0 | AUTH-FILE key structure: NPI + AUTH-NUMBER + DOS; mismatches written to DENY work file |
| MROUTNG0 | Auto-adjudication routing — evaluates 12 routing conditions; routes to auto-pay, manual pend, or suspend | Called by MADJDRV0 after MCOVDET0 and MAUTHCK0 | Routing conditions are hardcoded COBOL IF logic — primary tribal knowledge risk |
| MDENCD00 | Denial code assignment — maps denial reason to CARC/RARC code pair | Called by MADJDRV0 for denied claims | CARC/RARC lookup table in DB2 DENIAL_CODE_MAP; some legacy denials use hardcoded CARC |
| MPENDMG0 | Pend queue management — writes pended claims to PEND_QUEUE DB2 table with reason code and SLA date | Called by MROUTNG0 for pend-routed claims | SLA date calculated as receipt date + 30 days; no escalation logic currently — manual supervisor follow-up |
| MSUSPMG0 | Suspend queue management — writes suspended claims to SUSPENSE DB2 table; sets release condition code | Called by MROUTNG0 for suspend-routed claims | Release conditions: COB-PENDING, AUTH-PENDING, ELIG-PENDING; released by nightly MSUSPRL0 when condition clears |
| MSUSPRL0 | Suspend release — evaluates suspended claims nightly; releases to adjudication when condition is met | Called by JCL ADJUD-SUSP step | Runs after ACCUM-FILE refresh and AUTH-FILE refresh; high failure risk if upstream refresh jobs are late |
| MADJAUD0 | Adjudication audit writer — writes every claim state change to CLAIM_AUDIT DB2 table | Called by MADJDRV0 at each state transition | Critical for compliance; every CARC assignment, routing decision, and override is logged |

---

### 3.3 Key DB2 Tables

> ⚠️ [VALIDATE WITH JAMES WHITFIELD] — Table names, key fields, and relationships below are based on typical mainframe claims adjudication patterns and must be validated against actual MiCPS DB2 schema.

| Table Name | Purpose | Key Fields | Relationships |
|-----------|---------|-----------|--------------|
| COVERAGE_POLICY | Plan-level coverage rules — covered services, exclusions, benefit limitations by plan code | PLAN_CD, SERVICE_TYPE_CD, COVERAGE_IND, LIMIT_UNITS, LIMIT_PERIOD | Joined to CLAIM_HEADER by PLAN_CD; primary input to MCOVDET0 |
| DENIAL_CODE_MAP | CARC/RARC lookup — maps internal denial reason code to external CARC/RARC pair | DENIAL_REASON_CD, CARC_CD, RARC_CD, EFFECTIVE_DT | Read by MDENCD00; updated when new CARC/RARC codes published by WPC |
| PEND_QUEUE | Active pended claims awaiting manual review | CLAIM_ID, PEND_REASON_CD, PEND_DT, SLA_DT, ADJUDICATOR_ID, STATUS_CD | Child of CLAIM_HEADER; updated by MPENDMG0 and manual adjudicator CICS transaction |
| SUSPENSE | Active suspended claims awaiting automated condition clearance | CLAIM_ID, SUSPEND_REASON_CD, SUSPEND_DT, RELEASE_CONDITION_CD, RELEASE_DT | Child of CLAIM_HEADER; updated by MSUSPMG0 and released by MSUSPRL0 |
| CLAIM_ADJUD | Final adjudication result per claim and service line | CLAIM_ID, LINE_SEQ, ADJUD_DT, ADJUD_RESULT_CD, PAY_AMT, DENIAL_CD, CARC_CD, RARC_CD, PROGRAM_ID | Parent: CLAIM_HEADER; Child: CLAIM_LINE; written by MADJDRV0 at adjudication completion |
| CLAIM_AUDIT | Full audit trail — every state change, routing decision, and override | CLAIM_ID, EVENT_DT, EVENT_TYPE_CD, PREV_STATUS_CD, NEW_STATUS_CD, PROGRAM_ID, USER_ID, TERMINAL_ID | Append-only; written by MADJAUD0; never updated — insert only |

---

### 3.4 Batch Jobs

> ⚠️ [VALIDATE WITH JAMES WHITFIELD] — JCL job names, schedules, and dependencies below are based on typical mainframe batch patterns and must be validated against actual CA7/TWS schedule definitions.

| JCL Job Name | Function | Schedule | Upstream Dependency | Downstream Dependency |
|-------------|---------|---------|--------------------|--------------------|
| MADJMN00 | Main adjudication run — processes all clean claims from CLAIM-WRK; calls MADJDRV0 | Nightly — starts after MELIGV00 completes | MELIGV00 (eligibility verify) completion + ACCUM-FILE refresh + AUTH-FILE refresh | MPRICNG0 (pricing), MCOBPRC0 (COB) |
| MADJSUSP | Suspend release job — evaluates and releases suspended claims back to adjudication queue | Nightly — runs before MADJMN00 | AUTH-FILE nightly refresh, MEMBER-IDX refresh | MADJMN00 |
| MADJPND0 | Pend report and SLA monitoring — generates daily pend queue report; flags claims past SLA date | Nightly — post MADJMN00 | MADJMN00 completion | Operations team email distribution |
| MADJREG0 | Adjudication regulatory update job — loads updated COVERAGE_POLICY and DENIAL_CODE_MAP from change-controlled input files | On-demand (regulatory change events) + annual (CMS update cycle) | Approved change file in DASD staging area | None — reference table update only |

---

### 3.5 Known Complexity Areas

> ⚠️ [VALIDATE WITH JAMES WHITFIELD] — Complexity descriptions below are based on code analysis patterns and SME interviews. All entries require confirmation against actual MiCPS source.

| Area | Description | Knowledge Owner | Risk |
|------|-------------|----------------|------|
| MROUTNG0 routing conditions | 12 hardcoded IF conditions determine auto-pay vs. pend vs. suspend routing; no external specification; logic has been modified incrementally over 20+ years without documentation | James Whitfield | Critical |
| COVERAGE_POLICY table gaps | Some legacy plan codes have no COVERAGE_POLICY rows — MCOVDET0 falls through to hardcoded COBOL EVALUATE logic for these plans; the list of affected plan codes is undocumented | James Whitfield | Critical |
| MAUTHCK0 auth matching tolerance | Auth validation has undocumented date tolerance logic — claims within N days of auth expiry are auto-approved rather than denied; N is hardcoded in MAUTHCK0 and its value is unknown | James Whitfield | Critical |
| MSUSPRL0 release condition race condition | If AUTH-FILE or MEMBER-IDX refresh jobs run late, MSUSPRL0 evaluates against stale data and may incorrectly release or hold suspended claims; no compensating control exists | Operations team | High |
| Manual adjudicator CICS override | CICS transaction MADJ allows a supervisor to force-pay or force-deny any claim bypassing all edit and adjudication logic; override audit trail exists in CLAIM_AUDIT but override reason is free-text and unstructured | Operations supervisors | High |
| CLAIM_AUDIT volume | CLAIM_AUDIT is append-only and has never been purged; estimated 8–10 billion rows; table scans are prohibited; all access must be via CLAIM_ID index; reporting against CLAIM_AUDIT requires offline extract | DBA team | Medium |

---

### 3.6 Modernization Status

| Attribute | Detail |
|-----------|--------|
| Migration Wave | Wave 5 (planned — last to migrate) |
| Current Status | Pending |
| Cloud Target | Java 21 / Spring Boot — Adjudication Engine Service on EKS; Aurora PostgreSQL |
| Key Dependency | All upstream modules (Waves 1–4) must be stable in production before adjudication migration begins |
| Blocker | Primary blocker: MROUTNG0 routing logic must be fully reverse-engineered and converted to a documented business rule specification before the cloud adjudication engine can be designed. Estimated effort: 6–8 weeks of paired sessions between James Whitfield and a senior Java architect. This work must begin in 2026 before James's retirement in 2027. |

---

---

## Module 4: Pricing / Fee Schedule

### 4.1 Module Overview

**Purpose:** Applies the correct contracted rate or UCR pricing to adjudicated claims, executes DRG grouper logic for institutional inpatient claims, calculates outlier payments, and applies any carve-out pricing for high-cost items.

**Scope:**
- In-network professional repricing (contracted CPT/HCPCS rates from FEE-SCHED VSAM)
- DRG assignment and institutional inpatient pricing (DRG-RATES VSAM + custom grouper logic)
- Out-of-network UCR pricing
- Multiple procedure reduction
- Outlier payment calculation for institutional claims
- Carve-out item pricing (high-cost implants, drugs)

**Processing Mode:** Batch (JCL). CICS for interactive fee schedule lookup.

**Position in Pipeline:** Upstream: Adjudication Engine (approved claims only). Downstream: Claims Payment.

---

### 4.2 Key COBOL Programs

> ⚠️ HIGH PRIORITY — All entries [VALIDATE WITH SME]

| Program Name | Function | Calls / Called By | Notes |
|-------------|----------|------------------|-------|
| `MPRICDR0` | Pricing driver — determines pricing path per claim type (professional/institutional, in/out of network) | Called by JCL `MPRICNG0`; calls MFEELKP0, MDRGGRP0, MUCRPRC0, MMPRDC0 as appropriate | Routes to correct pricer subprogram based on claim type and network status [VALIDATE WITH SME] |
| `MFEELKP0` | Fee schedule lookup — reads FEE-SCHED KSDS by NPI + CPT/HCPCS composite key; returns contracted allowed amount | Called by MPRICDR0 for professional in-network claims | No contracted rate found → falls through to MPFS percentage logic; fallback percentage is hardcoded [VALIDATE WITH SME] |
| `MDRGGRP0` | DRG grouper — assigns MS-DRG based on principal diagnosis, procedures, CCs/MCCs, age, and discharge status | Called by MPRICDR0 for institutional inpatient claims | Custom COBOL grouper — not a vendor product; contains Mivan-specific DRG modifications layered on CMS base grouper; annual CMS update requires manual code change [VALIDATE WITH SME] |
| `MDRGPRC0` | DRG pricer — reads DRG-RATES RRDS by DRG slot; applies base rate × relative weight; calculates outlier | Called by MPRICDR0 after MDRGGRP0 | Outlier threshold is per-hospital in DB2 HOSPITAL_PARAMS; default threshold hardcoded for hospitals without a specific record [VALIDATE WITH SME] |
| `MUCRPRC0` | UCR pricer — applies out-of-network UCR pricing using percentile lookup from DB2 UCR_TABLE | Called by MPRICDR0 for out-of-network professional claims | UCR table loaded from FAIR Health data annually; geographic area mapping is a known complexity area [VALIDATE WITH SME] |
| `MMPRDC0` | Multiple procedure reduction — applies percentage reduction to secondary procedures per CMS MPPR rules | Called by MPRICDR0 after MFEELKP0 for multi-procedure professional claims | Reduction percentages hardcoded per procedure category [VALIDATE WITH SME] |

---

### 4.3 Key DB2 Tables

> All entries [VALIDATE WITH SME]

| Table Name | Purpose | Key Fields | Relationships |
|-----------|---------|-----------|--------------|
| `HOSPITAL_PARAMS` | Hospital-specific parameters — outlier threshold, base rate modifier, per diem rates | HOSP_NPI, DRG_OUTLIER_THRESHOLD, BASE_RATE_MODIFIER, PER_DIEM_ICU, PER_DIEM_MEDSURG | Read by MDRGPRC0; hospitals without a record fall through to hardcoded defaults |
| `UCR_TABLE` | UCR allowed amounts by CPT, geographic area, and percentile | CPT_CD, GEO_AREA_CD, PERCENTILE, UCR_ALLOWED_AMT, EFFECTIVE_DT | Read by MUCRPRC0; loaded annually from FAIR Health; geographic area mapping gap documented in Known Complexity |
| `FEE_SCHED_AUDIT` | Audit log of fee schedule lookups — supports disputed claim repricing and contract validation | CLAIM_ID, CPT_CD, NPI, SCHED_USED, ALLOWED_AMT, LOOKUP_DT | Written by MFEELKP0; used by provider contract dispute resolution workflow |

---

### 4.4 Batch Jobs

> All entries [VALIDATE WITH SME]

| JCL Job Name | Function | Schedule | Upstream Dependency | Downstream Dependency |
|-------------|---------|---------|--------------------|--------------------|
| `MPRICNG0` | Pricing run — applies fee schedule and DRG pricing to all approved claims | Nightly — after MADJMN00 | `MADJMN00` completion | `MCOBPRC0` (COB processing), `MPYMTCL0` (payment calculation) |
| `MFEELDS0` | Fee schedule load — loads updated contracted rates into FEE-SCHED KSDS from approved contract files | On-demand — contract change events; requires DBA and operations sign-off | Approved contract rate file delivered to DASD staging | None — reference data update only |
| `MDRGLDS0` | DRG rate load — loads annual CMS DRG relative weights and Mivan base rates into DRG-RATES RRDS | Annual — October (aligned to CMS IPPS update cycle); manual trigger | Approved DRG rate file; manual trigger by operations | None — reference data update only |

---

### 4.5 Known Complexity Areas

> ⚠️ HIGH PRIORITY — All entries [VALIDATE WITH SME]

| Area | Description | Knowledge Owner | Risk |
|------|-------------|----------------|------|
| MDRGGRP0 custom grouper | Custom COBOL DRG grouper contains Mivan-specific modifications to CMS base grouper accumulated over 15 years; annual CMS IPPS update requires manual code diff and selective merge; no automated regression suite; high risk of silent mis-grouping after each update [VALIDATE WITH SME] | James Whitfield | Critical |
| FEE-SCHED KSDS key structure | Fee schedule VSAM key is a composite of NPI prefix + specialty code + CPT code + effective date; key structure has been extended twice and is partially undocumented; incorrect key construction causes silent fallthrough to default MPFS percentage pricing with no error logged [VALIDATE WITH SME] | James Whitfield | Critical |
| UCR geographic area mapping | CPT billing ZIP-to-GEO_AREA_CD mapping table in DB2 has not been updated since 2019; rural ZIP codes added since 2019 fall through to a default geographic area that may not be contractually appropriate [VALIDATE WITH SME] | Senior pricing analyst | High |
| MMPRDC0 hardcoded reduction pcts | Multiple procedure reduction percentages are hardcoded by procedure category in MMPRDC0 rather than table-driven; CMS MPPR policy changes require a code change rather than a table update [VALIDATE WITH SME] | James Whitfield | High |

---

### 4.6 Modernization Status

| Attribute | Detail |
|-----------|--------|
| Migration Wave | Wave 3 (planned) |
| Current Status | Pending |
| Cloud Target | Java 21 / Spring Boot — Fee Schedule Service on EKS; Aurora PostgreSQL for contracted rates |
| Key Dependency | FEE-SCHED VSAM and DRG-RATES RRDS layouts must be fully reverse-engineered before migration |
| Blocker | MDRGGRP0 custom DRG grouper extensions must be fully reverse-engineered and documented before the cloud pricing service can be designed; FEE-SCHED KSDS composite key structure requires complete layout documentation; both require paired sessions with James Whitfield [VALIDATE WITH SME] |

---

---

## Module 5: Claims Payment

### 5.1 Module Overview

**Purpose:** Calculates the final member cost-share (deductible, copay, coinsurance, OOP max) for each adjudicated claim, determines the net payer payment amount, generates the X12 835 ERA (Electronic Remittance Advice), triggers the EFT payment instruction file, and generates the member EOB.

**Scope:**
- Cost-share calculation (deductible, copay, coinsurance, OOP max application)
- Accumulator update (write back to ACCUM-FILE after cost-share applied)
- Net payer payment amount calculation
- X12 835 ERA file generation
- EFT/ACH payment instruction file generation (to MiPay)
- Member EOB generation
- Payment register update (DB2)

**Processing Mode:** Batch (JCL).

**Position in Pipeline:** Upstream: Pricing / Fee Schedule + COB (if applicable). Downstream: Output feeds (SQL Server, S3, MiPortal, MiPay).

---

### 5.2 Key COBOL Programs

> All entries [VALIDATE WITH SME]

| Program Name | Function | Calls / Called By | Notes |
|-------------|----------|------------------|-------|
| `MPYMTDR0` | Payment driver — reads priced claims from CLAIM-WRK; orchestrates cost-share calculation and payment record creation | Called by JCL `MPYMTCL0`; calls MCOSTSH0, MACCUPD0, MPYMREC0 in sequence | Single driver pattern; controls payment loop [VALIDATE WITH SME] |
| `MCOSTSH0` | Cost-share calculator — applies deductible, copay, coinsurance, and OOP max to calculate member responsibility and net payer payment amount | Called by MPYMTDR0 | Reads ACCUM-FILE for current YTD accumulator state; complex logic for in/out-of-network cost-share tiers [VALIDATE WITH SME] |
| `MACCUPD0` | Accumulator updater — writes updated YTD deductible and OOP max back to ACCUM-FILE after cost-share applied | Called by MPYMTDR0 after MCOSTSH0 | Most critical write operation in MiCPS — ACCUM-FILE integrity depends on this completing without ABEND; checkpoint every 10,000 records [VALIDATE WITH SME] |
| `MPYMREC0` | Payment record writer — writes final payment record to CLAIM_PAYMENT DB2 table and payment register | Called by MPYMTDR0 after MACCUPD0 | Generates internal payment sequence number used as EFT trace base [VALIDATE WITH SME] |
| `M835GEN0` | 835 ERA generator — reads CLAIM_PAYMENT and CLAIM_ADJUD; generates X12 835 ERA file per trading partner | Called by JCL `MOUGEN00` after MPYMTCL0 | Generates one 835 file per provider NPI per payment cycle; 835 version 005010X221A1; custom format variations for select large provider groups — see Known Complexity [VALIDATE WITH SME] |
| `MEFTGEN0` | EFT instruction file generator — creates fixed-width ACH payment instruction file for MiPay | Called by JCL `MOUGEN00` after M835GEN0 | EFT trace number = payment date (YYMMDD) + sequential counter; counter resets daily [VALIDATE WITH SME] |

---

### 5.3 Key DB2 Tables

> All entries [VALIDATE WITH SME]

| Table Name | Purpose | Key Fields | Relationships |
|-----------|---------|-----------|--------------|
| `CLAIM_PAYMENT` | Final payment record per claim — authoritative payer payment amount | CLAIM_ID, PAYMENT_DT, PAYMENT_AMT, MEMBER_RESP_AMT, EFT_TRACE_NO, CHECK_NO, PAYMENT_STATUS_CD | Written by MPYMREC0; read by M835GEN0 and MEFTGEN0; joins to CLAIM_HEADER via CLAIM_ID |
| `PAYMENT_REGISTER` | Daily payment register — aggregate totals by provider for finance reconciliation | PAYMENT_DT, PROV_NPI, TOTAL_PAID_AMT, CLAIM_COUNT, EFT_BATCH_NO | Written by MPYMREC0; feeds finance GL system via nightly extract |
| `ERA_CONTROL` | 835 ERA file control record — tracks ERA generation per provider per payment cycle | ERA_FILE_ID, PROV_NPI, GENERATION_DT, CLAIM_COUNT, TOTAL_AMT, FILE_STATUS | Written by M835GEN0; used for ERA reconciliation and reissue workflow |

---

### 5.4 Batch Jobs

> All entries [VALIDATE WITH SME]

| JCL Job Name | Function | Schedule | Upstream Dependency | Downstream Dependency |
|-------------|---------|---------|--------------------|--------------------|
| `MPYMTCL0` | Payment calculation — cost-share, accumulator update, and payment record creation | Nightly — after MCOBPRC0 | `MCOBPRC0` completion | `MOUGEN00` (output generation) |
| `MOUGEN00` | Output generation — 835 ERA file and EFT ACH instruction file creation | Nightly — after MPYMTCL0 | `MPYMTCL0` completion | `MFEEDOB0` (outbound feeds to MiDataSQL and MiDataLake) |
| `MEFTTRN0` | EFT transmission — transmits ACH file to MiPay via SFTP | Nightly — after MOUGEN00; EFT file validation step must pass | `MOUGEN00` completion + EFT file checksum validation | MiPay ACH processing |

---

### 5.5 Known Complexity Areas

> All entries [VALIDATE WITH SME]

| Area | Description | Knowledge Owner | Risk |
|------|-------------|----------------|------|
| OOP max cross-tier tracking | OOP max accumulator tracks in-network and out-of-network spending separately; ACA requires combined OOP max for embedded plans; MCOSTSH0 has separate logic paths for pre-ACA and post-ACA plan codes — pre-ACA plans still active for grandfathered groups [VALIDATE WITH SME] | Senior payment SME | High |
| Family OOP max embedded logic | Family OOP max reached flag in ACCUM-FILE triggers a plan-pays-100% condition in MCOSTSH0; edge case when individual OOP max is reached but family is not uses a different calculation path that is only partially documented [VALIDATE WITH SME] | James Whitfield | High |
| M835GEN0 trading partner variations | Several large provider groups have custom 835 format requirements negotiated into their contracts (loop ordering variations, custom REF segments); implemented as hardcoded provider NPI checks in M835GEN0 — not in any configuration table [VALIDATE WITH SME] | EDI operations team | Medium |
| MACCUPD0 checkpoint/restart | ACCUM-FILE write checkpoints every 10,000 records; if ABEND occurs mid-run, restart logic re-reads from last checkpoint but duplicate-write protection relies on a flag byte in ACCUM-FILE record that must be manually reset after abend recovery [VALIDATE WITH SME] | James Whitfield | High |

---

### 5.6 Modernization Status

| Attribute | Detail |
|-----------|--------|
| Migration Wave | Wave 1 (in flight — partial) |
| Current Status | In flight — Remittance Generation (835) being extracted as a standalone cloud service |
| Cloud Target | Java 21 — ERA Generation Service; S3 output; downstream EFT via AWS payment integration |
| Key Dependency | Accumulator service (Wave 2) must be live before full payment module migration |
| Blocker | 835 ERA generation approach must be decided — rebuild in Java (full control, Wave 1 target) vs. retain M835GEN0 with a cloud wrapper (lower risk, defers complexity); trading partner custom format variations in M835GEN0 must be fully inventoried before either path is viable; MACCUPD0 checkpoint/restart logic must be replicated or superseded by the Wave 2 DynamoDB accumulator service [VALIDATE WITH SME] |

---

---

## Module 6: Coordination of Benefits (COB)

### 6.1 Module Overview

**Purpose:** Determines the correct order of payment when a member has coverage under more than one health plan, calculates the secondary payer's liability, and adjusts the MiCPS payment accordingly. Applies NAIC COB rules and Mivan-specific COB agreements.

**Scope:**
- COB order determination (birthday rule, active/inactive, subscriber/dependent)
- Primary vs. secondary payment calculation
- COB method application (Standard, Non-Duplication, MOB, or Carve-Out)
- COB accumulator update
- Handling of Medicare Secondary Payer (MSP) scenarios
- Hardcoded payer-specific COB agreements

**Processing Mode:** Batch (JCL).

**Position in Pipeline:** Upstream: Adjudication Engine. Downstream: Claims Payment.

> ⚠️ HIGH PRIORITY — COB edge cases and payer-specific COB agreements are a concentration of tribal knowledge.

---

### 6.2 Key COBOL Programs

> ⚠️ HIGH PRIORITY — All entries [VALIDATE WITH SME]

| Program Name | Function | Calls / Called By | Notes |
|-------------|----------|------------------|-------|
| `MCOBDR00` | COB driver — processes all COB-flagged claims; determines COB order and routes to appropriate calculation method | Called by JCL `MCOBPRC0`; calls MCOBORD0, MCOBPYR0, then MCOBSTD0/MCOBNOD0/MCOBMOB0 | Reads COB flag set by MCOBFLG0 in eligibility pass [VALIDATE WITH SME] |
| `MCOBORD0` | COB order determination — applies birthday rule, active employment rule, and custody rule | Called by MCOBDR00 | Birthday rule implemented as date comparison; gender rule logic still present in code but bypassed by a condition flag — not yet removed [VALIDATE WITH SME] |
| `MCOBSTD0` | Standard COB calculator — calculates secondary liability under standard COB method | Called by MCOBDR00 based on payer agreement lookup | Most common COB method for Mivan commercial plans [VALIDATE WITH SME] |
| `MCOBNOD0` | Non-duplication COB calculator — compares primary paid to secondary allowable; pays zero if primary paid ≥ secondary allowable | Called by MCOBDR00 for non-duplication payer agreements | [VALIDATE WITH SME] |
| `MCOBMOB0` | MOB (Maintenance of Benefits) calculator | Called by MCOBDR00 for MOB payer agreements | Least common method; used for specific self-funded employer groups [VALIDATE WITH SME] |
| `MCOBPYR0` | Payer agreement lookup — determines which COB method applies for a given primary payer | Called by MCOBDR00 before calculation subprogram | Reads PAYER_COB_AGREE DB2 table first; falls through to hardcoded COBOL EVALUATE for payers not in table — primary tribal knowledge risk [VALIDATE WITH SME] |
| `MCOBAUD0` | COB audit writer — writes full COB calculation detail to CLAIM_COB DB2 table | Called by MCOBDR00 after calculation | Full calculation detail preserved for provider dispute resolution [VALIDATE WITH SME] |

---

### 6.3 Key DB2 Tables

> All entries [VALIDATE WITH SME]

| Table Name | Purpose | Key Fields | Relationships |
|-----------|---------|-----------|--------------|
| `PAYER_COB_AGREE` | COB method by primary payer — for payers with formal coordination agreements | PRIMARY_PAYER_ID, COB_METHOD_CD, EFFECTIVE_DT, NOTES | Read by MCOBPYR0; incomplete — many payers handled by hardcoded COBOL fallthrough; see Known Complexity |
| `CLAIM_COB` | COB calculation results per claim — full detail for dispute resolution | CLAIM_ID, PRIMARY_PAYER_ID, PRIMARY_PAID_AMT, COB_METHOD_CD, COB_AMT, SECONDARY_LIABILITY_AMT | Written by MCOBAUD0; joins to CLAIM_HEADER via CLAIM_ID |
| `COB_ACCUM` | Member YTD COB accumulator — tracks primary payer payments for MOB method calculations | MEMBER_ID, PLAN_YEAR, PRIMARY_PAYER_ID, YTD_PAID_AMT | Updated by MCOBDR00 after each COB calculation |

---

### 6.4 Batch Jobs

> All entries [VALIDATE WITH SME]

| JCL Job Name | Function | Schedule | Upstream Dependency | Downstream Dependency |
|-------------|---------|---------|--------------------|--------------------|
| `MCOBPRC0` | COB processing run — applies COB order determination and calculates secondary liability for all COB-flagged claims | Nightly — after MADJMN00 | `MADJMN00` completion | `MPYMTCL0` (payment calculation) |
| `MCOBPYR0` | Payer agreement table refresh — loads updated COB method agreements from contracts team into PAYER_COB_AGREE | On-demand — when new payer agreements are executed | Approved payer agreement file from contracts team | None — reference data update only |

---

### 6.5 Known Complexity Areas

> ⚠️ HIGH PRIORITY — All entries [VALIDATE WITH SME]

| Area | Description | Knowledge Owner | Risk |
|------|-------------|----------------|------|
| Hardcoded payer fallthrough | MCOBPYR0 falls through to hardcoded COBOL EVALUATE for ~40 payers not in PAYER_COB_AGREE; these include some of the highest-volume COB payers; the hardcoded logic predates the DB2 table and was never migrated [VALIDATE WITH SME] | James Whitfield | Critical |
| Gender rule legacy code | MCOBORD0 contains gender rule logic gated by a GENDER-RULE-ACTIVE flag in PAYER_COB_AGREE; flag is Y for 3 legacy self-funded plans that have never been updated; legal confirmation of retirement pending [VALIDATE WITH SME] | Compliance + James Whitfield | High |
| MSP determination | MSP scenarios handled by a separate condition in MCOBDR00 that checks a hardcoded list of Medicare payer IDs; list has not been updated since 2021; new Medicare Advantage plan IDs may not be recognized, causing MSP claims to process under standard COB incorrectly [VALIDATE WITH SME] | Senior COB analyst | High |
| MOB accumulator accuracy | COB_ACCUM YTD data depends on primary payer EOB data being received and loaded correctly; if the primary payer's 835 is not available, MCOBMOB0 calculates based on member-reported amounts which are unvalidated [VALIDATE WITH SME] | Senior COB analyst | Medium |

---

### 6.6 Modernization Status

| Attribute | Detail |
|-----------|--------|
| Migration Wave | Wave 4 (planned) |
| Current Status | Pending |
| Cloud Target | Java 21 / Spring Boot — COB Engine Service on EKS; Aurora PostgreSQL |
| Key Dependency | Hardcoded payer COB agreements must be extracted and externalized to configuration before migration |
| Blocker | ~40 hardcoded payer COB agreements in MCOBPYR0 EVALUATE block must be fully extracted and migrated to PAYER_COB_AGREE configuration before the cloud COB engine can be designed; gender rule retirement must be legally confirmed and the MCOBORD0 code path formally decommissioned; MSP payer ID list must be refreshed against current CMS Medicare Advantage plan registry [VALIDATE WITH SME] |

---

---

## Module 7: Overpayment & Recovery

### 7.1 Module Overview

**Purpose:** Identifies claims that were paid in error or at an incorrect amount, generates demand notifications to providers, tracks recovery status, and applies offset logic to reduce future remittances until the overpayment is recovered.

**Scope:**
- Post-payment audit rules (duplicate detection, retroactive eligibility, COB mismatch, pricing error)
- Overpayment record creation and tracking
- Demand letter generation
- Offset / recoupment calculation and application to future remittances
- Recovery status tracking
- Reporting for compliance and finance

**Processing Mode:** Batch (JCL) + CICS (supervisor review and override interface).

**Position in Pipeline:** Post-payment module. Runs after Claims Payment. Can trigger adjustments to future payment calculations.

---

### 7.2 Key COBOL Programs

> All entries [VALIDATE WITH SME]

| Program Name | Function | Calls / Called By | Notes |
|-------------|----------|------------------|-------|
| `MOVPDR00` | Overpayment audit driver — post-payment rules engine; evaluates 8 overpayment detection rules and identifies claims meeting overpayment criteria | Called by JCL `MOVPAUD0`; calls MOVPDUP0, MOVPCOB0, MOVPDEM0 | Runs after MPYMTCL0; writes confirmed overpayments to OVERPAY and OVERPAY_AUDIT [VALIDATE WITH SME] |
| `MOVPDUP0` | Duplicate payment detector — identifies claims paid more than once | Called by MOVPDR00 | Compares CLAIM_PAYMENT records on member ID + provider NPI + DOS + CPT + amount; exact match only — near-duplicate logic not implemented [VALIDATE WITH SME] |
| `MOVPCOB0` | COB overpayment detector — identifies claims where COB was not applied or applied incorrectly | Called by MOVPDR00 | Cross-references CLAIM_COB against updated COB data; retroactive COB data receipt triggers reanalysis [VALIDATE WITH SME] |
| `MOVPDEM0` | Demand letter generator — creates demand letter trigger record in DB2 and notifies MiDocs for document generation | Called by MOVPDR00 for confirmed overpayments | Document generation handled by MiDocs (downstream system); MOVPDEM0 writes trigger record only — does not generate the letter [VALIDATE WITH SME] |
| `MOVPOFS0` | Offset calculator — reduces future remittances by overpayment recovery amount | Called by MPYMTDR0 during payment calculation when an active overpayment offset exists | Tightly coupled to MPYMTDR0 — reads OVERPAY table and reduces CLAIM_PAYMENT amount before writing; any ABEND corrupts the payment run [VALIDATE WITH SME] |
| `MOVPSTS0` | Recovery status updater — tracks partial recovery across multiple remittance cycles | Called by MOVPOFS0 after each offset application | Updates OVERPAY_RECOVERY ledger; closes overpayment record when fully recovered [VALIDATE WITH SME] |

---

### 7.3 Key DB2 Tables

> All entries [VALIDATE WITH SME]

| Table Name | Purpose | Key Fields | Relationships |
|-----------|---------|-----------|--------------|
| `OVERPAY` | Overpayment master record — one row per identified overpayment | OVERPAY_ID, CLAIM_ID, OVERPAY_AMT, RECOVERY_METHOD_CD, STATUS_CD, DEMAND_DT, RECOVERY_START_DT | Written by MOVPDR00; read by MOVPOFS0 during payment calculation; joins to CLAIM_HEADER via CLAIM_ID |
| `OVERPAY_RECOVERY` | Partial recovery ledger — one row per remittance offset applied | OVERPAY_ID, RECOVERY_DT, RECOVERY_AMT, REMAINING_AMT, ERA_FILE_ID | Written by MOVPSTS0; used for recovery reconciliation and finance reporting |
| `OVERPAY_AUDIT` | Full audit log of all overpayment status changes | OVERPAY_ID, EVENT_DT, EVENT_TYPE_CD, USER_ID, NOTES | Append-only; written by MOVPDR00 and CICS supervisor override transaction |

---

### 7.4 Batch Jobs

> All entries [VALIDATE WITH SME]

| JCL Job Name | Function | Schedule | Upstream Dependency | Downstream Dependency |
|-------------|---------|---------|--------------------|--------------------|
| `MOVPAUD0` | Post-payment overpayment audit — runs MOVPDR00 rules engine against all newly paid claims | Nightly — after MPYMTCL0 | `MPYMTCL0` completion | MOVPDEM0 trigger records written to MiDocs queue for demand letter generation |
| `MOVPRPT0` | Overpayment recovery report — daily and monthly recovery status summary for finance and compliance | Nightly | `MOVPAUD0` completion | Finance and compliance distribution (MiReport extract) |

---

### 7.5 Known Complexity Areas

> All entries [VALIDATE WITH SME]

| Area | Description | Knowledge Owner | Risk |
|------|-------------|----------------|------|
| MOVPOFS0 coupling to payment | Offset logic reads OVERPAY table inside the MPYMTDR0 payment loop — any ABEND in MOVPOFS0 can corrupt the payment run for all claims in the current batch; no isolation between offset logic and clean payment processing [VALIDATE WITH SME] | James Whitfield | Critical |
| Near-duplicate detection gap | MOVPDUP0 detects exact duplicates only; near-duplicates (same claim, slightly different charge amount or date) are not caught; estimated $2–4M annual leakage based on post-payment audit findings [VALIDATE WITH SME] | Senior overpayment analyst | High |
| State recoupment look-back limits | Commercial recoupment look-back periods vary by state (12–36 months); limits are hardcoded per state code in MOVPOFS0; last updated 2020; several states have updated their laws since, creating compliance exposure [VALIDATE WITH SME] | Compliance team | High |
| CICS supervisor override | CICS supervisor override transaction writes directly to OVERPAY_AUDIT and can change overpayment STATUS_CD to WAIVED without a corresponding financial adjustment to CLAIM_PAYMENT — reconciliation gap between audit and payment tables [VALIDATE WITH SME] | Operations + James Whitfield | Medium |

---

### 7.6 Modernization Status

| Attribute | Detail |
|-----------|--------|
| Migration Wave | Wave 5 (planned — companion to Adjudication Engine) |
| Current Status | Pending |
| Cloud Target | Java 21 / Spring Boot — Overpayment & Recovery Service on EKS; Aurora PostgreSQL |
| Key Dependency | Adjudication Engine must migrate first (shared DB2 tables); offset logic must be decoupled from payment module before migration |
| Blocker | MOVPOFS0 must be decoupled from the MPYMTDR0 payment loop before migration — offset logic running inside the payment batch is not viable in a cloud microservices architecture; state-specific recoupment look-back rules must be refreshed against current state law before being externalized to configuration; near-duplicate detection requires a net-new rule specification [VALIDATE WITH SME] |

---

## Document Metadata

| Field | Value |
|-------|-------|
| Template created | 2026-08-06 |
| Primary SME target | James Whitfield — Principal Engineer, MiCPS |
| Secondary SME targets | MiCPS operations team, QE team (Anita Rosen) |
| Estimated population effort | 3–5 working sessions per module; 7 modules |
| Priority order | Module 3 (Adjudication) → Module 4 (Pricing) → Module 6 (COB) → Module 2 (Eligibility) → Module 1 (Intake) → Module 5 (Payment) → Module 7 (Overpayment) |
| Format for population | Replace `[TO BE POPULATED WITH MIVAN DOMAIN EXPERTISE]` and placeholder rows in tables with actual values; remove question blocks once answered |
| Related documents | L3: `mivan-system-landscape.md` · L5: `claims-business-rules.md` · L1: `mivan-enterprise-context.md` |
