---
layer: L2
node_type: domain
domain: provider-data
source: web-research + manual
last_synced: 2026-08-08
validated_by: Digital Brain — pending SME review
fidelity: DRAFT
ghost_node_id: PROVIDER-DATA-LIFECYCLE
links_back:
  - knowledge/L1-enterprise/mivan-enterprise-context.md
  - knowledge/L2-domain/commercial-claims.md
links_forward:
  - knowledge/L3-systems/mivan-system-landscape.md
  - knowledge/L4-application/micps-application-knowledge.md
---

# Provider Data Management — Full Lifecycle
## Mivan Health Plan

> ⚠️ VALIDATE: All sections marked with this flag
> require confirmation against Mivan's provider
> contracting and credentialing operations before
> treating as authoritative.

---

## 1. Provider Data Overview

### Why Provider Data Matters
- Every claim requires a valid, credentialed, enrolled provider
- Bad provider data is one of the top sources of claim denials — rendering NPI not credentialed, group NPI not enrolled, taxonomy mismatch, stale contract dates
- Provider data errors also trigger post-pay audits and network adequacy failures
- Regulatory requirements: CMS network adequacy standards, MA directory accuracy rules (30-day update, 85% accuracy), credentialing accreditation (NCQA/URAC)

### Provider Data Complexity
- Providers carry multiple identities: individual NPI (Type 1), organizational NPI (Type 2), tax ID (TIN), contract ID, state Medicaid legacy ID
- Same provider may have multiple specialties (taxonomy codes), multiple locations, and multiple network participations across product lines
- Provider data changes constantly — address changes, specialty updates, contract terminations, new group affiliations, licensure renewals
- **Downstream claim impact:** fee schedule selection uses rendering NPI + taxonomy; network status check uses rendering NPI; payment routes to TIN; all three must be correct simultaneously

---

## 2. National Provider Identifier (NPI)

### NPI Structure
- **HIPAA-mandated** 10-digit numeric identifier; permanent — never reused or reassigned
- Issued by CMS via **NPPES** (National Plan and Provider Enumeration System); public lookup at npiregistry.cms.hhs.gov
- **Type 1 NPI:** Individual human providers (physicians, therapists, nurses); the "rendering" NPI; appears in Box 24J of CMS-1500 / 837P loop 2310B
- **Type 2 NPI:** Organizational entities (group practices, hospitals, clinics); the "billing" NPI; appears in Box 33a / 837P loop 2010AA

### NPI Taxonomy Codes
- Every NPI record requires at least one taxonomy code; exactly one must be designated primary
- **NUCC taxonomy code set:** 10-character alphanumeric; maintained by National Uniform Claim Committee; updated twice yearly (January and July)
- **Fee schedule selection:** Payers use rendering provider's taxonomy to identify the applicable fee schedule — wrong taxonomy = wrong rate or claim rejection
- **Network participation lookup:** Network status is typically tied to NPI + taxonomy combination; a provider may be in-network for one taxonomy and out-of-network for another
- Providers must register all applicable taxonomies in NPPES and include them on claims

### Common Taxonomy Codes
| Category | Code | Specialty |
|---|---|---|
| Primary Care | 207Q00000X | Family Medicine |
| Primary Care | 207R00000X | Internal Medicine |
| Primary Care | 208000000X | Pediatrics |
| Surgery | 208600000X | General Surgery |
| Surgery | 207X00000X | Orthopedic Surgery |
| Behavioral Health | 2084P0800X | Psychiatry |
| Behavioral Health | 1041C0700X | Clinical Social Work |
| Behavioral Health | 103T00000X | Psychologist |
| Facility | 282N00000X | Hospital |
| Facility | 314000000X | Skilled Nursing Facility |
| Facility | 261QA1903X | Ambulatory Surgical Center |
| Ancillary | 225100000X | Physical Therapy |
| Ancillary | 2085R0202X | Radiology |
| Ancillary | 291U00000X | Laboratory |

### Billing vs Rendering Provider
- **Billing provider:** Entity submitting the claim (group practice, hospital) — Type 2 NPI
- **Rendering provider:** Individual who performed the service — Type 1 NPI
- Both NPIs required on 837P professional claims
- Fee schedule lookup uses **rendering NPI + taxonomy**
- Network status check uses **rendering NPI**
- Payment routes via **billing NPI → TIN**

### Atypical Providers
- Some behavioral health, LTSS, and state Medicaid providers may lack NPIs
- Use state-assigned legacy provider IDs; submission rules vary by state Medicaid contract
  > ⚠️ VALIDATE: Mivan's handling of atypical provider IDs in MiCPS claim adjudication

---

## 3. Provider Credentialing

### What Is Credentialing
- Process of verifying a provider's qualifications before allowing them to treat members
- **Primary source verification (PSV):** Confirming credentials directly with the issuing organization (e.g., verifying medical license directly with the state board, not from a copy)
- **Credentialing vs privileging:** Payer credentialing = verifying qualifications for network participation; hospital privileging = authorizing specific procedures at a facility — distinct processes

### CAQH ProView
- Universal credentialing datasource operated by the Council for Affordable Quality Healthcare
- Providers self-attest and upload credentials once; payers access CAQH for PSV instead of collecting the same data independently
- **Re-attestation required every 120 days** — CAQH sends reminders at 30, 14, and 3 days before attestation expires
- If attestation lapses, the profile enters "Reattestation Required" status; payers receive a flag that the profile is not current
- **CAQH One Healthcare ID:** Provider's single login identifier across the credentialing ecosystem
- Meets data-collection requirements of NCQA, URAC, and The Joint Commission

### Credentialing Data Elements
| Element | What Is Verified |
|---|---|
| Medical license | State, expiration date, disciplinary history — PSV from state medical board |
| DEA certificate | Controlled substance prescribing authority |
| Board certification | Specialty board status (ABMS member boards) |
| Malpractice insurance | Coverage limits, open and closed claims history |
| Education & training | Medical school, residency, fellowship — PSV from institutions |
| Work history | Gap analysis — gaps > 6 months require explanation |
| Hospital affiliations | Active privileges at affiliated facilities |
| Medicare/Medicaid enrollment | Active enrollment status — no exclusion flags |

### Initial Credentialing Process
- **Timeline:** 60–90 days from application to approval (NCQA-compliant process)
- **NCQA PSV window (updated July 1, 2025):** Verification may not be older than 120 days (Credentialing Accreditation) or 90 days (Credentialing Certification) at the time of the credentialing decision
- **Provisional credentialing:** Allows a provider to see patients under supervision while full credentialing completes; time-limited; requires ongoing monitoring
- **CVO delegation:** NCQA allows payers to delegate PSV to NCQA-accredited Credentialing Verification Organizations (CVOs)

### Recredentialing
- Required every 2-3 years (varies by state and plan)
- Continuous monitoring between cycles
- Trigger events — malpractice suit, license action, exclusion listing
- Expedited recredentialing for cause

---

## 4. Provider Enrollment

### Enrollment vs Credentialing
- Credentialing — verifying qualifications
- Enrollment — adding provider to network, executing contract, setting up for payment

### Medicare and Medicaid Enrollment
- Providers must enroll in Medicare/Medicaid separately from commercial credentialing
- CMS 855 forms — Medicare enrollment application
- PECOS — Provider Enrollment Chain and Ownership System
- Medicaid enrollment — state-specific process
- Enrollment gaps cause claim denials — provider not enrolled on date of service

### Commercial Network Enrollment
- Provider contract execution
- Network tier assignment — preferred, standard, specialty tiers
- Fee schedule assignment — contract rates loaded to MiCPS FEE-SCHED VSAM
- Effective date management — when provider can start seeing members

---

## 5. Network Management

### Network Adequacy
- CMS and state requirements for provider availability
- Time and distance standards — how far members must travel to see a provider
- Specialist access standards — wait time requirements
- Network adequacy reporting — annual submission to regulators
- Consequences of inadequacy — regulatory action, member auto-assignment restrictions

### Provider Directory
- Public-facing provider search
- ACA requirement — directory accuracy
- 72-hour update requirement for directory changes
- Directory errors — regulatory penalties, member harm if wrong provider listed as in-network
- Mivan provider directory — MiPortal

### Network Tiering
- Multi-tier networks — preferred, standard, out-of-network
- Different cost-sharing by tier — incentivizes use of preferred providers
- Tier assignment criteria — quality, cost, geographic coverage
- Tier changes — notification requirements to providers

### Provider Contract Management
- Contract terms — fee schedules, performance requirements, termination clauses
- Fee schedule updates — annual or triggered by CMS rate changes
- Contract renewals — auto-renew vs active renewal
- Termination — with cause vs without cause, notice periods, member continuity requirements
- Right to audit — contractual right to audit provider billing

---

## 6. Sanctions and Exclusions

### OIG Exclusion List
- Office of Inspector General — List of Excluded Individuals/Entities (LEIE)
- Federal law prohibits payment to excluded providers
- Monthly update — payers must check monthly
- Consequences of paying excluded provider — CMS repayment demand, penalties

### SAM Exclusions
- System for Award Management — federal contractor exclusion list
- Also checked for provider exclusions
- Broader than OIG — includes more exclusion types

### State Exclusion Lists
- Each state maintains its own Medicaid exclusion list
- Must be checked for Medicaid claims
- State lists may include providers not on federal lists

### Mivan Exclusion Checking Process
> ⚠️ VALIDATE: How MiCPS checks exclusion status
> at claim time — is it real-time or batch?
> Is PROV-MSTR updated with exclusion flags?

### Sanctioned Provider Claims
- Claim received for excluded provider
- MiCPS edit check — is provider excluded?
- Denial with appropriate reason code
- Retroactive exclusion — claims paid before exclusion discovered must be recovered

---

## 7. Provider Data Quality

### The Golden Record Problem
- Same provider exists in multiple systems with different data
- Deduplication — matching provider records across systems
- Master data management — single source of truth
- MiProvider as Mivan's provider master — feeds MiCPS nightly

### Common Data Quality Issues

| Issue | Claims Impact |
|---|---|
| Wrong address | Directory inaccuracy, member harm |
| Inactive NPI | Claim denial — NPI not on file |
| Wrong specialty/taxonomy | Wrong fee schedule applied |
| Missing contract | Claim paid at out-of-network rate |
| Expired credentials | Claim denial — provider not credentialed |
| Exclusion not flagged | Improper payment, compliance risk |
| Termination not processed | Claims paid after termination date |

### Provider Data Governance
- Data stewardship — who owns each data element
- Change management — how updates flow from source to MiCPS
- Audit trail — who changed what and when
- Exception reporting — claims failing due to provider data issues

---

## 8. Provider Data in MiCPS

### PROV-MSTR VSAM File
- Primary provider reference in MiCPS
- Updated nightly from MiProvider feed
- Key: NPI (10-digit)
- Contains: network status, specialty, contract ID, fee schedule pointer, exclusion flag, effective/termination dates
- Read by: adjudication, edit, pricing programs

### MiProvider System
- SQL Server on-premises
- Source of truth for provider data
- Receives updates from:
  - Credentialing system
  - Contracting system
  - CAQH ProView feed
  - OIG/SAM exclusion feeds
- Generates nightly feed to MiCPS

### Claims Impact of Provider Data Errors

| Error in PROV-MSTR | Claim Outcome |
|---|---|
| Provider not found | Denial — provider not on file |
| Network status = OON | Paid at out-of-network rate |
| Exclusion flag = Y | Denial — excluded provider |
| Wrong fee schedule pointer | Incorrect payment amount |
| Terminated — date past | Denial — provider not active on DOS |
| Wrong specialty | Wrong clinical edit applied |

> ⚠️ VALIDATE: Confirm PROV-MSTR key structure
> and all fields used by MiCPS programs.
> L3 shows NPI as the key — confirm composite
> key or single NPI key.

---

## 9. Provider Data Modernization

### Current State Pain Points
- Nightly batch refresh — 24-hour staleness window
- PROV-MSTR VSAM — no real-time lookup capability
- Provider data errors not discoverable until next batch cycle
- Manual processes for credentialing updates

### Target State
- Real-time provider data service — Wave 2
- API-driven NPI lookup replacing PROV-MSTR VSAM reads
- DynamoDB for provider reference data — sub-millisecond lookup
- Event-driven updates — provider change triggers immediate cache invalidation
- Credentialing system integration — direct feed bypassing MiProvider batch

### Migration Approach
- Provider Data Service — Wave 2 target
- Shadow mode — compare PROV-MSTR lookups vs API responses during parallel running
- Cutover gate — 99.9% match rate on provider lookups before decommissioning PROV-MSTR

---

## Glossary — Provider Data Terms

| Term | Definition |
|---|---|
| NPI | National Provider Identifier — 10-digit HIPAA-mandated provider ID |
| Type 1 NPI | Individual provider NPI |
| Type 2 NPI | Organizational provider NPI |
| NPPES | National Plan and Provider Enumeration System — CMS NPI registry |
| CAQH | Council for Affordable Quality Healthcare — universal credentialing datasource |
| PECOS | Provider Enrollment Chain and Ownership System — Medicare enrollment |
| LEIE | List of Excluded Individuals/Entities — OIG exclusion list |
| SAM | System for Award Management — federal exclusion list |
| Taxonomy Code | NUCC provider specialty classification code |
| Credentialing | Process of verifying provider qualifications |
| Privileging | Hospital process of granting clinical privileges |
| Recredentialing | Periodic re-verification of provider credentials |
| Network Adequacy | Regulatory standard for provider availability to members |
| Golden Record | Single authoritative provider record across all systems |
| PROV-MSTR | MiCPS VSAM file — provider master reference |
| MiProvider | Mivan's provider master data management system |
| Right to Audit | Contractual provision allowing payer to audit provider billing |
| Termination for Cause | Contract termination due to provider quality or compliance issue |
| Continuity of Care | Member's right to continue treatment with terminated provider |
