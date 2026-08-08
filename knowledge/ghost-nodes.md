---
layer: META
node_type: ghost-registry
domain: all
last_synced: 2026-08-08
validated_by: Milan Chander
fidelity: PARTIAL
---

# Ghost Node Registry
## Mivan Digital Brain — Known Knowledge Gaps

> This file is the authoritative registry of 
> knowledge that is known to be missing from 
> the Digital Brain. Absence is explicit here —
> never silent. Every ghost node must be 
> registered before it can be built.
> 
> Status legend:
> GHOST — not yet started
> IN-FLIGHT — being built now
> COMPLETE — graduated to formal layer

---

## Critical — Blocks Migration

| Node ID | Layer | What Is Missing | Knowledge Owner | Risk | Status |
|---|---|---|---|---|---|
| ADJUD-BUSINESS-RULES-SPEC | L4 | Coverage determination rules embedded in MADJDRV0 COBOL — no external specification exists; rules are inline conditional logic only | James Whitfield | Critical | GHOST |
| ACCUM-FILE-LAYOUT | L4 | Full VSAM record layout for ACCUM-FILE — annual reset logic, family vs individual accumulator structure, mid-year enrollment handling | James Whitfield | Critical | GHOST |
| DRG-GROUPER-EXTENSIONS | L4 | Custom DRG grouper modifications layered on CMS base grouper over 15 years — undocumented; annual CMS update requires manual code diff | James Whitfield | Critical | GHOST |
| COB-PAYER-AGREEMENTS | L4 | ~40 payers handled by hardcoded COBOL EVALUATE in MCOBPYR0 — not in PAYER_COB_AGREE DB2 table; no documentation of which payers or what logic applies | James Whitfield | Critical | GHOST |
| AUTH-FILE-LAYOUT | L4 | Mixed record types within AUTH-FILE KSDS — record type discriminator in byte 1 is undocumented; cloud auth service cannot be built without this | James Whitfield | Critical | GHOST |
| FEE-SCHED-LAYOUT | L4 | FEE-SCHED KSDS key structure extended twice over 15 years without schema update — incorrect key construction causes silent fallthrough to default pricing | James Whitfield | Critical | GHOST |

---

## High — Limits Domain Coverage

| Node ID | Layer | What Is Missing | Knowledge Owner | Risk | Status |
|---|---|---|---|---|---|
| MEDICARE-ADVANTAGE-DOMAIN | L2 | MA plan structure, encounter data vs claims, HCC coding, RAF scores, RADV audits, MA adjudication differences | TBD | High | COMPLETE |
| MEDICAID-DOMAIN | L2 | Medicaid managed care structure, capitation, state variation, LTSS, encounter data submission | TBD | High | COMPLETE |
| PROVIDER-DATA-LIFECYCLE | L2 | Full provider enrollment and credentialing lifecycle — CAQH, NPI, network management, sanctions, termination | TBD | High | COMPLETE |
| UTILIZATION-MANAGEMENT | L2 | Prior authorization workflow, concurrent review, retrospective review, UM criteria sets | TBD | High | GHOST |
| L6-TASK-INTELLIGENCE | L6 | Defect patterns, incident history, sprint velocity baselines, QE coverage gaps — requires real Jira and ServiceNow data | QE team | High | GHOST |
| NCCI-TABLE-MANAGEMENT | L4 | How NCCI-TABLE KSDS is loaded, versioned, and overridden — quarterly update process undocumented | Senior edit analyst | High | GHOST |
| BATCH-DEPENDENCY-COMPLETE | L3 | Complete batch job dependency chain — full map exists only in CA7 scheduler; no human-readable documentation | Operations team | High | GHOST |

---

## Medium — Limits Onboarding and Compliance

| Node ID | Layer | What Is Missing | Knowledge Owner | Risk | Status |
|---|---|---|---|---|---|
| STATE-SPECIFIC-CLAIM-RULES | L5 | State-level claim rules — prompt pay laws, timely filing by state, recoupment look-back periods | Compliance team | Medium | GHOST |
| PROVIDER-SANCTIONS | L2 | OIG and SAM exclusion checking in claims — how MiCPS handles sanctioned providers | TBD | Medium | GHOST |
| HEALTH-PRIMER | L2 | Plain English healthcare primer for non-health resources — complete beginner entry point | Digital Brain team | Medium | IN-FLIGHT |
| REGULATORY-LANDSCAPE | L2 | HIPAA transaction standards, ACA requirements, CMS regulations affecting commercial claims | TBD | Medium | GHOST |
| INTRADAY-BATCH-DETAIL | L3 | Full intraday batch cycle documentation — morning, midday, afternoon cycles | Operations team | Medium | GHOST |
| CLAIM-ADJUSTMENT-WORKFLOW | L4 | Full claim adjustment and void workflow — frequency code 7/8 processing, ICN matching, cascade impacts | TBD | Medium | GHOST |

---

## Low — Nice to Have

| Node ID | Layer | What Is Missing | Knowledge Owner | Risk | Status |
|---|---|---|---|---|---|
| MEMBER-PORTAL-INTEGRATION | L3 | MiPortal integration detail — how EOB display works, member-facing claim status | TBD | Low | GHOST |
| MIPAY-INTEGRATION | L3 | MiPay EFT/ACH integration detail — payment instruction file format, trace number generation | TBD | Low | GHOST |
| HISTORICAL-DEFECT-PATTERNS | L6 | Historical defect patterns from pre-2026 releases — tribal knowledge in QE team | QE team | Low | GHOST |

---

## Ghost Node Lifecycle

When a ghost node is completed:
1. Update status from GHOST to COMPLETE in this file
2. Add the new knowledge file to the appropriate layer
3. Update the frontmatter of the new file to reference 
   this ghost node ID
4. Commit both changes together with message:
   "Graduate ghost node [NODE-ID] to [LAYER]"

When work starts on a ghost node:
1. Update status from GHOST to IN-FLIGHT
2. Assign a knowledge owner if TBD
3. Commit with message: "Ghost node [NODE-ID] in flight"
