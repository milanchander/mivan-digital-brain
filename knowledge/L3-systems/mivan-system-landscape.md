---
layer: L3
node_type: application
domain: claims
app_id: micps
last_validated: 2026-08-07
validated_by: "Digital Brain — pending SME review"
fidelity: PARTIAL
source_count_declared: 8
source_count_captured: 6
owns:
  - MiCPS high-level architecture
  - Batch feed architecture
  - Modernization architecture
  - Coexistence pattern
  - Wave 1-5 migration sequence
implements: []
links_back:
  - L1-enterprise/mivan-enterprise-context.md
  - L2-domain/commercial-claims.md
  - L2-domain/medicare-advantage.md
  - L2-domain/medicaid-managed-care.md
  - L2-domain/provider-data-lifecycle.md
  - L2-domain/health-primer.md
  - L2-domain/utilization-management.md
links_forward:
  - L4-application/micps-application-knowledge.md
  - knowledge/L2-domain/medicare-advantage.md
  - knowledge/L2-domain/medicaid-managed-care.md
ghost_nodes:
  - Complete VSAM file inventory with record layouts
  - Production JCL job schedule and dependency chain
  - CICS transaction catalog with program mappings
  - Network topology and mainframe connectivity diagrams
  - DR/failover configuration and RTO/RPO targets
---

# Mivan Health Plan — System Landscape
## Claims and Provider Applications

> **Validation flag legend:**
> `> ⚠️ VALIDATE:` marks statements requiring confirmation against actual MiCPS architecture, runbooks, or subject matter expert review before treating as authoritative.

---

## 1. MiCPS High-Level Architecture

### Overview

MiCPS (Mivan Claims Processing System) is Mivan's homegrown IBM z/OS mainframe application for commercial medical claims processing. It has been in continuous production for approximately 30 years and has been extended incrementally throughout its lifetime. It processes approximately 4 million commercial claims per day at peak.

MiCPS is composed of two distinct processing modes that operate in concert: **batch processing** (JCL-driven overnight and scheduled jobs) and **online transaction processing** (CICS-driven real-time interactions). Both modes share the same underlying DB2 and VSAM data stores.

```
┌──────────────────────────────────────────────────────────────────────┐
│                        IBM z/OS Mainframe                            │
│                                                                      │
│  ┌─────────────────────────┐   ┌─────────────────────────────────┐  │
│  │     CICS Region(s)      │   │       JES2 Batch Subsystem       │  │
│  │  (Online / Real-Time)   │   │     (Scheduled / Overnight)     │  │
│  │                         │   │                                 │  │
│  │  COBOL + CICS commands  │   │   COBOL programs invoked by JCL │  │
│  │  BMS maps (3270 UI)     │   │   Job scheduler (CA7 / TWS)     │  │
│  │  Multi-region support   │   │   Step-level dependency chains  │  │
│  └────────────┬────────────┘   └──────────────┬──────────────────┘  │
│               │                               │                      │
│               ▼                               ▼                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                    Data Layer                               │    │
│  │                                                             │    │
│  │   ┌──────────────────┐    ┌─────────────────────────────┐  │    │
│  │   │   IBM DB2        │    │         VSAM Datasets        │  │    │
│  │   │  (Structured     │    │  (Reference data, work files,│  │    │
│  │   │   claims data)   │    │   intermediate processing)   │  │    │
│  │   └──────────────────┘    └─────────────────────────────┘  │    │
│  └─────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────┘
```

---

### MiFCT — Government Claims Platform

MiFCT (Mivan Facets Claims Technology) is Mivan's implementation of TriZetto Facets — the industry-standard commercial claims processing platform used for government lines of business.

| Attribute | Detail |
|---|---|
| System Name | MiFCT — Mivan Facets Claims Technology |
| Platform | TriZetto Facets (QNXT/Facets) |
| Vendor | TriZetto (Cognizant) |
| Technology | Java-based, Oracle database |
| Lines of Business | Medicare Advantage + Medicaid |
| Deployment | On-premises (AWS migration planned) |
| Integration | REST API for external services |
| Provider Validation | Calls MiProvider validation REST API |

### Why Separate Platforms

| Dimension | MiCPS (Commercial) | MiFCT (Government) |
|---|---|---|
| Regulatory regime | State insurance law | CMS + State (federal overlay) |
| Payment model | FFS premium-funded | Capitation from CMS/State |
| Claim complexity | Standard commercial | Encounter data, HCC, RAF, MMIS |
| Compliance burden | State-specific | Federal CMS regulations |
| Upgrade cycle | In-house controlled | TriZetto release schedule |

---

### 1a. CICS — Online Transaction Processing

CICS (Customer Information Control System) manages real-time, interactive transactions on MiCPS. It functions as a sub-operating system within z/OS, managing its own memory regions, transaction routing, and concurrent user sessions. CICS supports thousands of simultaneous transactions and guarantees ACID properties — a transaction either completes fully or is rolled back.

#### MiCPS CICS Transaction Types

| Transaction | Description | Trigger |
|-------------|-------------|---------|
| Claim Inquiry | Real-time claim status lookup by claim ID or member ID | Provider portal or internal operations |
| Eligibility Check | Real-time member eligibility verification on date of service | Claim intake |
| Auth Validation | Real-time prior authorization status check | Adjudication engine |
| Manual Adjudication | Adjudicator workstation for pended/suspended claims | Operations staff |
| Fee Schedule Lookup | Interactive rate lookup for provider / CPT code combinations | Internal operations |
| Provider Data Lookup | Real-time provider NPI and network status verification | Claim intake and adjudication |
| Supervisor Override | Override or force-pay a specific claim | Supervisor role |
| Claim Adjustment / Void | Manual claim adjustment (frequency code 7 — replacement) or void (frequency code 8) initiated by operations staff; references original claim ICN; triggers downstream recalculation of accumulators and COB | Operations staff or supervisor for manual corrections; escalated provider disputes |

#### CICS Architecture Notes

- MiCPS uses **multiple CICS regions**: typically one or more application-owning regions (AORs) and a terminal-owning region (TOR) for routing
- BMS (Basic Mapping Support) maps drive the 3270 green-screen terminal interface used by operations staff
- CICS-DB2 attachment: DB2 commands embedded in CICS COBOL programs go through the DB2 pre-compiler; the load module sequence is: DB2 Pre-compiler → CICS Translator → COBOL Compiler → Link Editor
- CICS transactions are short-lived by design; long-running operations are handled in batch

> ⚠️ VALIDATE: Confirm number of CICS regions, region names, and whether MiCPS uses CICS Transaction Server (TS) version and any distributed CICS (IPIC) connectivity.

---

### 1b. JCL Batch Processing

The majority of MiCPS's claims volume is processed in batch. Batch jobs run on a scheduled basis — primarily overnight during the daily batch window — and process claims end-to-end: from EDI intake through adjudication, pricing, payment calculation, and outbound feed generation.

#### Batch Processing Characteristics

| Characteristic | Description |
|---------------|-------------|
| Execution model | Non-interactive; no user input during execution |
| Scheduling | Mainframe job scheduler (CA7 or IBM TWS/OPC) manages job streams, dependencies, and execution windows |
| Volume | Bulk processing of millions of claim records per run |
| Timing | Primary batch window: overnight (approx. 10 PM – 6 AM); secondary windows for intraday cycles |
| COBOL programs | Each JCL step invokes a COBOL program; multiple steps form a job; multiple jobs form a job stream |
| Error handling | JCL condition codes (RC=0 success, RC=4 warning, RC=8+ error); downstream steps conditioned on upstream RC |
| Restart/recovery | Checkpoint/restart logic embedded in COBOL programs; ABEND handlers manage abnormal termination |

#### MiCPS Batch Job Streams (Primary)

| Job Stream | Processing Scope | Typical Window |
|-----------|-----------------|---------------|
| CLAIM-INTAKE | EDI 837 file ingestion, parsing, format validation | Early overnight |
| CLAIM-EDIT | Front-end edits (NCCI, OCE, business edits) | Post-intake |
| ELIG-VERIFY | Eligibility and benefits determination | Post-edit |
| ADJUD-MAIN | Core adjudication — coverage, auth check, pricing | Nightly core window |
| COB-PROCESS | Coordination of benefits calculation | Post-adjudication |
| PAYMENT-CALC | Cost-share application, payment amount calculation | Post-COB |
| OUTPUT-GEN | ERA/835 generation, EOB generation | Pre-morning |
| FEED-OUTBOUND | Outbound feeds to SQL Server, S3, downstream systems | End of batch window |

> ⚠️ VALIDATE: Confirm actual job stream names, execution sequence, and batch window times with the MiCPS operations team (James Whitfield or equivalent).

#### Intraday Batch Cycles

In addition to the primary overnight window, MiCPS runs **3 intraday batch cycles** each business day. These cycles execute a subset of the full batch stream — edit, eligibility, and adjudication steps only. Payment calculation and all outbound feeds (SQL Server, S3 full extracts, ERA generation) run in the overnight window only.

| Cycle | Time | Scope | Outputs |
|-------|------|-------|---------|
| Cycle 1 — Morning | ~6 AM | Processes urgent claims flagged during overnight batch for priority adjudication | Intraday CLAIMS-DELTA feed to S3 (`raw/claims/delta/`) |
| Cycle 2 — Midday | ~12 PM | Processes claim adjustments and voids submitted by operations since morning; refreshes ACCUM-FILE for high-volume providers | Updated ACCUM-FILE VSAM; no outbound feed |
| Cycle 3 — Afternoon | ~4 PM | Processes late EDI submissions received from clearinghouse after overnight cutoff | Intraday status updates to SQL Server (MiOps DB — ClaimStatus table) |

**Intraday Cycle Constraints**

- Intraday cycles run on a reduced job stream: CLAIM-EDIT → ELIG-VERIFY → ADJUD-MAIN only
- PAYMENT-CALC, OUTPUT-GEN, and FEED-OUTBOUND do not run intraday
- Claims adjudicated in an intraday cycle are held in a "payment pending" status until the overnight PAYMENT-CALC run
- ACCUM-FILE updates from Cycle 2 are applied in memory and written to VSAM; CICS regions may briefly quiesce during the ACCUM-FILE write step

> ⚠️ VALIDATE: Confirm intraday cycle times, job stream scope, and whether CICS quiesce occurs for Cycle 2 ACCUM-FILE refresh.

---

### 1c. VSAM File Usage

VSAM (Virtual Storage Access Method) is IBM's high-performance file access method on z/OS. MiCPS uses VSAM extensively for reference data, work files, and intermediate processing state that does not require the full relational capabilities of DB2.

#### VSAM Dataset Types Used in MiCPS

| Type | Full Name | Access Pattern | MiCPS Usage |
|------|-----------|---------------|------------|
| KSDS | Key Sequenced Data Set | Random by key; sequential in key order | Primary reference files — provider master, member index, fee schedule tables, auth records |
| ESDS | Entry Sequenced Data Set | Sequential only; records stored in write order | Audit/log files, claim intake staging queues, EDI raw input landing |
| RRDS | Relative Record Data Set | Direct by relative record number | Fixed-slot lookup tables — DRG rate tables, benefit accumulator arrays |

#### Key MiCPS VSAM Files

| File Name (Logical) | Type | Description | Updated By | Read By |
|--------------------|------|-------------|-----------|---------|
| PROV-MSTR | KSDS | Provider master reference — NPI, network status, specialty | MiProvider feed (nightly) | Adjudication, edit programs |
| MEMBER-IDX | KSDS | Member index — member ID to enrollment record pointer | MiMember feed (nightly) | Eligibility, adjudication |
| FEE-SCHED | KSDS | Fee schedule — CPT/HCPCS + provider key → allowed amount | Fee schedule batch load (periodic) | Pricing programs |
| AUTH-FILE | KSDS | Prior authorization records — auth number, status, dates, codes | MiAuth feed + CICS transactions | Adjudication programs |
| DRG-RATES | RRDS | DRG rate table — MS-DRG code → base rate | Annual rate load job | Institutional pricing programs |
| ACCUM-FILE | KSDS | Member accumulator file — YTD deductible and OOP max by member | Updated each adjudication cycle | Cost-share calculation |
| CLAIM-WRK | ESDS | Claim work file — intermediate claim records during adjudication pass | Adjudication programs | Output and payment programs |
| EDI-STAGE | ESDS | EDI 837 staging — raw inbound claim records pre-parse | EDI intake job | Edit and validation programs |
| AUDIT-LOG | ESDS | Audit trail — every claim state change with timestamp and program ID | All MiCPS programs | Compliance reporting, post-pay audit |

#### VSAM and Batch Window Coordination

VSAM files used by both CICS (online) and JCL (batch) require careful window management. The standard pattern in MiCPS:
- Batch window opens: CICS regions quiesce or switch to read-only mode for shared VSAM files
- Batch updates VSAM files (accumulator updates, reference file refreshes)
- Batch window closes: CICS regions resume full read/write access

> ⚠️ VALIDATE: Confirm actual VSAM dataset names (DSNs), VSAM cluster definitions, and which files are shared between CICS and batch. Several VSAM files in MiCPS are suspected to have undocumented record layouts — see Section 7 (Technical Debt).

---

### 1d. DB2 — Structured Claims Data

IBM DB2 for z/OS is MiCPS's relational database, used for persistent structured claims data, audit history, and financial records. DB2 is accessed from both CICS (online) and JCL batch programs via embedded SQL pre-compiled into COBOL.

#### Primary DB2 Tables

| Table | Description | Key Columns |
|-------|-------------|-------------|
| CLAIM_HEADER | One row per claim — top-level claim record | CLAIM_ID, MEMBER_ID, PROV_NPI, DOS_FROM, DOS_TO, BILL_AMOUNT, STATUS_CD |
| CLAIM_LINE | One row per service line | CLAIM_ID, LINE_SEQ, CPT_CD, MOD1–4, UNITS, CHARGE_AMT, ALLOWED_AMT, PAID_AMT |
| CLAIM_DIAG | Diagnosis codes per claim (up to 12 ICD-10) | CLAIM_ID, DIAG_SEQ, DIAG_CD, DIAG_TYPE |
| CLAIM_ADJUD | Adjudication result per claim/line | CLAIM_ID, LINE_SEQ, ADJUD_DT, PAY_AMT, DENIAL_CD, CARC_CD, RARC_CD |
| CLAIM_COB | COB calculation detail | CLAIM_ID, PRIMARY_PAYER_ID, PRIMARY_PAID, COB_METHOD, COB_AMT |
| CLAIM_PAYMENT | Payment record — EFT/check details | CLAIM_ID, PAYMENT_DT, PAYMENT_AMT, EFT_TRACE_NO, CHECK_NO |
| CLAIM_AUDIT | Full audit trail of all status changes | CLAIM_ID, EVENT_DT, EVENT_TYPE, PREV_STATUS, NEW_STATUS, PROGRAM_ID, USER_ID |
| OVERPAY | Overpayment records | OVERPAY_ID, CLAIM_ID, OVERPAY_AMT, RECOVERY_METHOD, STATUS, DEMAND_DT |
| COB_ACCUM | Member COB accumulator — primary payer payments YTD | MEMBER_ID, PLAN_YEAR, PRIMARY_PAYER_ID, YTD_PAID |

#### DB2 Design Notes

- DB2 tablespaces are partitioned by claim receipt date for performance and archival management
- Static SQL (pre-compiled bind packages) used throughout MiCPS COBOL — dynamic SQL is rare and limited to reporting programs
- DB2 packages are bound per program; changes to SQL require rebind of affected packages
- Row-level locking used in CICS programs; page-level locking common in batch for throughput

> ⚠️ VALIDATE: Confirm actual DB2 table names, schema/database names, and partitioning strategy. Pre-compiled bind packages mean SQL changes are non-trivial — confirm bind process and approval requirements.

---

### 1e. MiCPS Functional Modules

| Module | Processing Mode | Primary Technology | Description |
|--------|----------------|-------------------|-------------|
| Claims Intake & Editing | Batch | COBOL + JCL + ESDS | EDI 837 ingestion, parsing, front-end edits (NCCI, OCE, business rules) |
| Eligibility & Benefits | Batch + CICS | COBOL + KSDS (MEMBER-IDX) + DB2 | Member active check, benefit structure retrieval, accumulator lookup |
| Adjudication Engine | Batch | COBOL + JCL + DB2 + KSDS | Coverage determination, auth check, auto vs. manual routing |
| Pricing / Fee Schedule | Batch + CICS | COBOL + KSDS (FEE-SCHED) + RRDS (DRG-RATES) | In-network repricing, DRG grouper, UCR application |
| Claims Payment | Batch | COBOL + JCL + DB2 | Cost-share calculation, payment file generation, ERA/835 creation |
| COB | Batch | COBOL + JCL + DB2 | Primary/secondary determination, COB calculation, COB accumulator update |
| Overpayment / Recovery | Batch + CICS | COBOL + DB2 | Post-pay audit flags, demand letter generation, offset / recoupment tracking |

---

## 2. Integration Landscape

```
                          ┌───────────────────────┐
                          │   MiEDI (LOB Router)   │
  EDI Clearinghouse ─837P/I─►  IBM Sterling B2B    │
                          │  Routes by member LOB  │
                          └───┬──────────┬─────────┘
                     COM claims│          │MA / MC claims
                              ▼          ▼
                    ┌──────────────┐   ┌───────────────────────┐
  MiMember ─feed───►│    MiCPS     │   │        MiFCT          │
  (Oracle on-prem)  │   (z/OS)     │   │  (TriZetto Facets)    │
                    │  Commercial  │   │  MA + Medicaid        │
  MiProvider ─feed─►│              │   │                       │
  (SQL Server)      │              │   └───┬───────────────────┘
                    │              │       │ after adjudication (REST)
  MiAuth ─auth─────►│              │       ▼
  (vendor)          │              │   ┌───────────────────────────────┐
                    │              │   │ MaPostAdjudicationService (MA) │
                    │              │   │ MedicaidStateReportingService  │
                    │              │   └───────────────────────────────┘
                    └──────┬───────┘
                           │  ┌───────────────────────────────┐
     both platforms ───────┼─►│  Provider Validation REST API │
     (MiCPS batch /        │  │  POST /api/v1/provider/...     │
      MiFCT Option A)      │  └───────────────────────────────┘
                           │──835/ERA──► MiPortal   │──payment──► MiPay
                           │──EOB──────► Member      │──claim data─► MiReport
                           │──outbound──► SQL Server / AWS S3 (data lake)
```

### Integration Points

| System | Direction | Data Exchanged | Mechanism | Frequency |
|--------|-----------|---------------|-----------|-----------|
| MiEDI (IBM Sterling) | Inbound | X12 837P/I EDI files | SFTP / MQ | Multiple times daily |
| MiMember (Oracle) | Inbound | Member enrollment and eligibility data | Batch file (fixed-width) via FTP | Nightly |
| MiProvider (SQL Server) | Inbound | Provider master — NPI, network, contracts | Batch file (fixed-width) via FTP | Nightly |
| MiAuth (vendor platform) | Inbound | Prior authorization records | Batch file via FTP + MQ (real-time for urgent) | Nightly + intraday |
| MiPortal (provider portal) | Outbound | X12 835 ERA files, claim status | SFTP to portal landing | Post-batch |
| MiPay (EFT/ACH) | Outbound | Payment instructions — payee, amount, EFT trace | Fixed-width batch file via SFTP | Nightly |
| MiReport (Cognos/DB2) | Outbound | Claim and financial data for reporting | Direct DB2 read (same z/OS) | Real-time / batch |
| SQL Server (downstream) | Outbound | Processed claim data for operational apps | Batch ETL via FTP → SQL bulk load | Nightly |
| AWS S3 (data lake) | Outbound | Claim records for analytics and modernization | Batch file via SFTP/MFT to S3 | Nightly |
| MiFCT | Outbound | Adjudicated MA/Medicaid claims | REST API | Real-time + batch |
| MaPostAdjudicationService | Called by MiFCT | Post-adjudication MA reporting | REST API | After adjudication |
| MedicaidStateReportingService | Called by MiFCT | State MMIS reporting | REST API | After adjudication |
| Provider Validation API | Inbound from MiFCT | NPI, credentialing, exclusion check | REST POST | Real-time |

> ⚠️ VALIDATE: Confirm MQ vs. SFTP usage for each integration. Several integrations are believed to use legacy FTP — confirm whether secure FTP (SFTP/FTPS) is in use for PHI transfers.

---

## LOB Routing Architecture

### MiEDI LOB Router

All inbound claims enter through MiEDI (IBM Sterling B2B). MiEDI applies LOB routing rules to determine which platform processes each claim.

Routing logic:
1. Claim received as 837P or 837I
2. MiEDI extracts member ID from Loop 2000B
3. Member LOB lookup in routing table
4. Route to appropriate platform:
   - Commercial → MiCPS intake queue
   - Medicare Advantage → MiFCT MA intake
   - Medicaid → MiFCT Medicaid intake

| LOB Code | Platform | Intake Queue |
|---|---|---|
| COM | MiCPS | MIVAN.MIEDI.COMMERCIAL.IN |
| MA | MiFCT | MIVAN.MIEDI.MA.IN |
| MC | MiFCT | MIVAN.MIEDI.MEDICAID.IN |

LOB Routing Table maintenance:
- Stored in MiEDI routing configuration
- Updated when members change LOB
- Mid-year LOB changes are handled by effective date logic in the routing table
- Routing table owner: MiEDI operations team

> ⚠️ VALIDATE: Confirm actual MiEDI queue names and routing table maintenance procedure.

### Post-Adjudication Processing

After MiFCT adjudicates government claims two Java services handle reporting obligations:

| Service | LOB | Purpose |
|---|---|---|
| MaPostAdjudicationService | MA | CMS EDPS encounter data, HCC validation, RAF calculation |
| MedicaidStateReportingService | Medicaid | TPL identification, payer of last resort, state MMIS submission |

These services are called by MiFCT via REST API after adjudication is complete. They do not participate in adjudication.

### Provider Validation Integration

Both MiCPS and MiFCT use the same provider validation service. This ensures consistent NPI, credentialing, exclusion, and network checks regardless of LOB.

Integration pattern:
- MiCPS: calls MPRVVLDR0 COBOL program (batch, via JCL)
- MiFCT: calls ProviderValidationOrchestrator REST API (Option A — direct HTTP POST)
  Endpoint: POST /api/v1/provider/validate/facets

This is the integration layer between MiFCT and the shared provider validation capability.

---

## 3. Batch Feed Architecture

### Overview

At the end of each nightly batch window, MiCPS generates outbound data feeds to downstream systems. These feeds are critical dependencies — downstream applications (operational reporting, analytics, provider portals, modernization workloads) rely on these files being delivered on time and complete.

### 3a. SQL Server Feeds

SQL Server hosts operational data stores consumed by Mivan's non-mainframe applications: provider-facing applications, operational dashboards, and business intelligence tools.

| Feed Name | Data Sent | Target Database / Table(s) | Frequency | Mechanism |
|-----------|-----------|---------------------------|-----------|-----------|
| CLAIM-STATUS-FEED | Adjudicated claim status — claim ID, status code, denial reason, paid amount | MiOps DB → ClaimStatus | Nightly | Fixed-width flat file via SFTP → SQL bulk load (BCP or SSIS) |
| PAYMENT-FEED | Payment records — EFT trace, check number, paid amount per claim | MiOps DB → Payments | Nightly | Fixed-width flat file via SFTP → SSIS |
| COB-FEED | COB calculation results — primary/secondary paid amounts per claim | MiOps DB → COBResults | Nightly | Fixed-width flat file via SFTP → SSIS |
| OVERPAY-FEED | Active overpayment records — demand status, recovery amount, recovery method | MiOps DB → Overpayments | Nightly | Fixed-width flat file via SFTP → SSIS |
| ACCUM-FEED | Member accumulator snapshot — YTD deductible and OOP max | MiOps DB → Accumulators | Nightly | Fixed-width flat file via SFTP → SSIS |

**Consuming Applications (SQL Server)**

| Application | Consumes | Purpose |
|-------------|---------|---------|
| MiPortal (provider portal) | CLAIM-STATUS-FEED, PAYMENT-FEED | Provider-facing claim status and remittance lookup |
| MiReport (Cognos) | All feeds | Operational and regulatory reporting |
| MiOps Dashboard | CLAIM-STATUS-FEED, OVERPAY-FEED | Operations supervisor dashboards |
| Finance / GL System | PAYMENT-FEED | General ledger posting |

> ⚠️ VALIDATE: Confirm SQL Server instance names, database names, target table schemas, and whether SSIS or another ETL tool (Informatica, Talend) handles the load step.

---

### 3b. AWS S3 Feeds

AWS S3 is the landing zone for the Mivan data lake and the primary target for the modernization program's analytics and cloud-native workloads.

| Feed Name | Data Sent | S3 Path (Logical) | Format | Frequency | Downstream Consumers |
|-----------|-----------|------------------|--------|-----------|---------------------|
| CLAIMS-FULL (Commercial) | Full adjudicated commercial claim records — header, lines, diagnosis, adjudication result | s3://mivan-datalake/raw/claims/commercial/daily/ (from MiCPS) | Fixed-width (mainframe EBCDIC → ASCII converted) | Nightly | Snowflake (analytics), modernization ETL, ML feature pipelines |
| CLAIMS-FULL (MA) | Full adjudicated Medicare Advantage claim records | s3://mivan-datalake/raw/claims/ma/daily/ (from MiFCT) | CSV / Parquet | Nightly | Snowflake (analytics), CMS encounter reconciliation, RADV support |
| CLAIMS-FULL (Medicaid) | Full adjudicated Medicaid claim records | s3://mivan-datalake/raw/claims/medicaid/daily/ (from MiFCT) | CSV / Parquet | Nightly | Snowflake (analytics), state MMIS reconciliation |
| CLAIMS-DELTA | Incremental — claims adjudicated or status-changed since last run | s3://mivan-datalake/raw/claims/delta/ | Fixed-width / CSV | Nightly + intraday | Real-time analytics, modernization coexistence layer |
| ERA-FILES | X12 835 ERA files | s3://mivan-datalake/raw/era/ | X12 EDI (835) | Post-batch | ERA processing, provider remittance analytics |
| PROVIDER-SNAP | Provider master snapshot | s3://mivan-datalake/raw/provider/daily/ | Fixed-width | Nightly | Provider analytics, network adequacy reporting |
| MEMBER-ACCUM | Member accumulator snapshot | s3://mivan-datalake/raw/accumulators/daily/ | Fixed-width | Nightly | Benefit accumulator service (cloud-native target) |
| AUDIT-LOG | Claim audit trail export | s3://mivan-datalake/raw/audit/ | Fixed-width | Nightly | Compliance, post-pay audit workloads |

> **LOB path separation:** Logical LOB separation in S3 enables LOB-specific analytics, regulatory reporting, and data governance. Both MiCPS and MiFCT write to the same S3 bucket with LOB-specific path prefixes.

**File Format Notes**

Mainframe-generated files are produced in EBCDIC encoding with fixed-width record layouts. Conversion to ASCII (and optionally to CSV or Parquet) is required before downstream cloud systems can consume them.

| Format Stage | Description |
|-------------|-------------|
| Raw (mainframe output) | Fixed-width, EBCDIC, packed decimal fields, binary integers |
| Converted (S3 raw zone) | ASCII, fixed-width or CSV; EBCDIC-to-ASCII conversion applied |
| Processed (S3 curated zone) | Parquet or ORC; schema-on-read applied; downstream Snowflake / Glue |

> ⚠️ VALIDATE: Confirm S3 bucket names, path conventions, and whether EBCDIC-to-ASCII conversion happens on-mainframe or via a landing zone Lambda/Glue job.

---

### 3c. Feed Failure Handling

Feed failures are among the highest-impact operational incidents in MiCPS — a missing nightly feed causes downstream applications to operate on stale data, can prevent provider portal updates, and delays financial reconciliation.

#### Error Detection

| Detection Point | Method |
|----------------|--------|
| JCL step return code | RC ≥ 8 triggers ABEND or condition-code-based step bypass; job scheduler alerts ops |
| File size / record count check | Downstream validation job compares record count against expected range; alerts if outside threshold |
| File arrival monitoring | CA7 / TWS monitors expected file arrivals; pages oncall if file not received by deadline |
| SQL Server load validation | Post-load row count comparison; SSIS package emails on failure |
| S3 arrival check | Lambda trigger on S3 PUT event; Step Function validates file; SNS alert on anomaly |

#### Alerting

| Alert Channel | Trigger |
|--------------|---------|
| PagerDuty / on-call page | File not arrived by deadline; ABEND on critical batch job |
| Email to operations team | Non-critical warnings, count variances |
| Mainframe operator console | WTOR (Write To Operator with Reply) messages for critical batch failures |

> ⚠️ VALIDATE: Confirm alerting toolchain — whether PagerDuty, ServiceNow, or another system is used for mainframe batch alerts.

#### Retry and Recovery

| Scenario | Recovery Pattern |
|----------|----------------|
| JCL ABEND — restartable | Checkpoint/restart: re-run job from last checkpoint using RESTART= parameter in JCL |
| JCL ABEND — non-restartable | Full re-run of job stream from affected step; may require manual data cleanup first |
| File transfer failure (SFTP) | Scheduled retry job (3 attempts, 15-minute interval); manual retry by ops after third failure |
| SQL Server load failure | Re-drop and reload target table; SSIS package includes truncate-and-reload logic |
| S3 write failure | MFT tool retry; if persistent, ops manually copies file from mainframe tape/staging |
| Downstream SLA breach | Incident opened in ServiceNow; escalation to MiCPS operations manager |

---

### 3d. Feed Dependency Map

The batch feed sequence follows strict ordering — downstream jobs cannot start until upstream jobs complete and output files are validated.

```
CLAIM-INTAKE (EDI parse)
      │
      ▼
CLAIM-EDIT (front-end edits)
      │
      ▼
ELIG-VERIFY (eligibility check)
      │
      ▼
ADJUD-MAIN (adjudication)
      │
      ├──► COB-PROCESS (COB calculation)
      │         │
      │         ▼
      └──► PAYMENT-CALC (payment amount)
                │
                ▼
          OUTPUT-GEN (835/ERA + EOB generation)
                │
                ▼
          FEED-OUTBOUND (all outbound feeds)
          │
          ├──► CLAIM-STATUS-FEED ──► SQL Server (MiOps DB)
          ├──► PAYMENT-FEED ──────► SQL Server (Finance)
          ├──► COB-FEED ──────────► SQL Server
          ├──► OVERPAY-FEED ───────► SQL Server
          ├──► ACCUM-FEED ─────────► SQL Server
          ├──► CLAIMS-FULL ────────► AWS S3 (raw/claims/daily)
          ├──► CLAIMS-DELTA ───────► AWS S3 (raw/claims/delta)
          ├──► ERA-FILES ──────────► AWS S3 + MiPortal SFTP
          ├──► PROVIDER-SNAP ──────► AWS S3
          ├──► MEMBER-ACCUM ───────► AWS S3
          └──► AUDIT-LOG ──────────► AWS S3
```

**Critical Path:** ADJUD-MAIN is the longest-running job and lies on the critical path for all downstream feeds. Any ABEND or performance degradation in ADJUD-MAIN cascades to all downstream applications.

> ⚠️ VALIDATE: Confirm actual job dependency chain, including any parallel job streams that run concurrently within the batch window.

---

## 4. Data Architecture

### 4a. DB2 — Primary Claims Data Store

See Section 1d for the full DB2 table inventory. Key design characteristics:

- **Schema owner**: MiCPS application schema (single schema; no multi-tenancy)
- **Partitioning**: Date-partitioned by claim receipt date; rolling 7-year retention on primary tablespaces; archived to tape beyond 7 years (HIPAA retention)
- **Indexing**: Primary index on CLAIM_ID; secondary indexes on MEMBER_ID, PROV_NPI, DOS_FROM, STATUS_CD
- **Referential integrity**: Enforced at application level (COBOL), not DB2 FK constraints — a known design limitation

> ⚠️ VALIDATE: Confirm DB2 retention policy and archival mechanism. Confirm whether FK constraints are truly absent or whether some tables have them.

### 4b. VSAM — Reference and Intermediate Data

See Section 1c for the full VSAM file inventory. Key characteristics:

- VSAM files are the primary store for reference data that must be accessed at high speed during batch (fee schedules, member index, provider master)
- Accumulator files (ACCUM-FILE) are updated transactionally during each adjudication pass — these are the most write-intensive VSAM files
- Several VSAM files have **undocumented or partially documented record layouts** — see Section 7 (Technical Debt)
- VSAM CI (Control Interval) and CA (Control Area) sizes are tuned for MiCPS workloads; changes require IDCAMS redefine and data migration

### 4c. SQL Server — Downstream Operational Data Stores

| Database | Purpose | Primary Tables | Consuming Applications |
|----------|---------|---------------|----------------------|
| MiOps DB | Operational claim data for non-mainframe apps | ClaimStatus, Payments, COBResults, Overpayments, Accumulators | MiPortal, MiOps Dashboard |
| MiFinance DB | Financial reconciliation and GL posting | PaymentRegister, GLEntries | Finance / GL System |
| MiAnalytics DB | Pre-aggregated reporting data | ClaimSummary, DenialTrends, ProviderSummary | MiReport (Cognos), Ad-hoc BI |

SQL Server databases are refreshed nightly from MiCPS feeds. They are **read replicas of mainframe truth** — the mainframe DB2 and VSAM files are the systems of record.

### 4d. AWS S3 — Data Lake Landing Zones

| Zone | S3 Path (Logical) | Contents | Governance |
|------|------------------|----------|-----------|
| Raw | s3://mivan-datalake/raw/ | Mainframe output files — unconverted or ASCII-converted fixed-width | Restricted; PHI; no direct analyst access |
| Curated | s3://mivan-datalake/curated/ | Parquet-format processed data; schema applied; PII masked for non-prod | Controlled; analyst access via IAM roles |
| Archive | s3://mivan-datalake/archive/ | Files older than 90 days; Glacier-tiered | Compliance hold; 7-year retention |

**Governance:** All S3 buckets containing PHI are encrypted (SSE-KMS), access-logged to CloudTrail, and restricted by VPC endpoint. Direct public access is disabled. Data catalog managed in AWS Glue.

> ⚠️ VALIDATE: Confirm S3 bucket naming convention, encryption key ownership (customer-managed vs. AWS-managed), and whether Glue Data Catalog is in use or a different catalog tool.

---

## 5. Modernization Architecture

### 5a. Target Cloud-Native Architecture

The target state replaces MiCPS function-by-function with a cloud-native microservices architecture on AWS. Each migrated module becomes an independent service; the mainframe equivalent is decommissioned only after the cloud service is validated in production.

**Target Stack**

| Layer | Technology |
|-------|-----------|
| Runtime | AWS EKS (Kubernetes) |
| Languages | Java 21 (Spring Boot), Python (data / ML pipelines) |
| Databases | Amazon Aurora PostgreSQL (transactional), Amazon DynamoDB (accumulator / reference data at scale) |
| Messaging | Amazon MSK (Kafka) — event streaming between services |
| API | REST (OpenAPI 3.x); AWS API Gateway for external-facing |
| File processing | AWS Lambda + S3 events; AWS Glue for ETL |
| Secrets | AWS Secrets Manager |
| Observability | Amazon CloudWatch + Datadog |
| CI/CD | GitHub Actions + AWS CodePipeline |

### 5b. Migration Sequence (Function-by-Function)

Modules are migrated in order of increasing business complexity. Earlier migrations (lower-risk) build team confidence and establish cloud infrastructure patterns before tackling the adjudication core.

| Wave | Module | Rationale |
|------|--------|-----------|
| Wave 1 (In Flight) | Eligibility Validation | Well-defined inputs/outputs; reference data-driven; low denial risk |
| Wave 1 (In Flight) | Duplicate Claim Detection | Rule-based; self-contained; high ROI (reduces duplicate pay) |
| Wave 1 (In Flight) | Remittance Generation (835) | Output-only; does not touch adjudication logic |
| Wave 2 | Member Accumulator Service | High-value; replaces ACCUM-FILE VSAM; enables real-time accumulator queries |
| Wave 2 | Provider Data Service | Replaces MiProvider SQL Server feed dependency; enables real-time NPI lookup |
| Wave 3 | Claims Intake & Editing | EDI parsing and NCCI/OCE edits; complex but well-documented via standards |
| Wave 3 | Pricing / Fee Schedule | Fee schedule service; replaces FEE-SCHED VSAM; enables API-driven repricing |
| Wave 4 | COB Engine | Complex; requires cross-payer data; phased by COB method |
| Wave 5 | Adjudication Engine Core | Highest complexity; most tribal knowledge; last to migrate |
| Wave 5 | Overpayment & Recovery | Dependent on adjudication; migrated as companion to Wave 5 |

**Scope notes:**
- Waves 1–5 apply to **MiCPS commercial** migration only.
- **MiFCT modernization is a separate program** (AWS deployment of TriZetto Facets) and is **not in scope** for this wave plan.
- The **Provider Data Service (Wave 2)** serves **both** MiCPS and MiFCT — MiCPS via the MPRVVLDR0 COBOL batch path and MiFCT via the Option A REST endpoint (`POST /api/v1/provider/validate/facets`).

### 5c. Coexistence Pattern

During migration, mainframe and cloud services must coexist. The coexistence layer routes traffic to the appropriate system and ensures data consistency between the two platforms.

```
                    ┌─────────────────────────┐
                    │   Coexistence Router    │
                    │  (API Gateway + Lambda) │
                    └────────┬────────────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
              ▼                             ▼
   ┌──────────────────┐         ┌──────────────────────┐
   │  MiCPS Mainframe │         │  Cloud-Native Service │
   │  (z/OS)          │         │  (EKS / Spring Boot)  │
   └──────────────────┘         └──────────────────────┘
```

**Routing Logic**

| Condition | Route To |
|-----------|---------|
| Module not yet migrated | Mainframe (MiCPS) |
| Module migrated and validated | Cloud-native service |
| Cloud service unhealthy (circuit breaker open) | Fallback to mainframe |
| Shadow mode (parallel validation) | Both — mainframe authoritative; cloud result compared |

**Shadow Mode:** Before cutover, newly built cloud services run in shadow mode — processing real claims in parallel with MiCPS. Cloud outputs are compared to mainframe outputs; discrepancies are investigated before the cloud service becomes authoritative.

**Data Synchronization:** During coexistence, the cloud-native services read from the same S3 feeds and SQL Server databases that MiCPS populates. Post-cutover, the cloud service becomes the source of truth and the S3/SQL feeds are generated by the cloud service instead.

### 5d. How Batch Feeds Evolve During Migration

| Migration Phase | SQL Server Feeds | AWS S3 Feeds |
|----------------|-----------------|--------------|
| Pre-migration (today) | Generated by MiCPS JCL batch; SFTP → SQL bulk load | Generated by MiCPS JCL batch; fixed-width files landed to S3 raw zone |
| Wave 1–2 (partial migration) | MiCPS generates most feeds; migrated modules write directly to Aurora/DynamoDB and publish events to Kafka; Kafka consumers update SQL Server | MiCPS generates base files; cloud services publish delta events to S3 |
| Wave 3–4 (mid-migration) | Hybrid: MiCPS and cloud services both contribute to SQL Server via event-driven Kafka consumers | Cloud services write curated data directly to S3; MiCPS feeds for non-migrated modules only |
| Wave 5+ (post-adjudication migration) | Cloud-native services are the source of truth; SQL Server updated via Kafka / CDC from Aurora | Cloud services generate all S3 output; MiCPS batch feeds deprecated module by module |
| Full cutover | SQL Server fed entirely by cloud event streams | S3 data lake fed entirely by cloud services; Glue catalogs structured data |

> ⚠️ VALIDATE: Confirm coexistence router implementation approach — whether API Gateway + Lambda, AWS App Mesh, or a custom Java routing service is planned.

---

## 6. Development & Release Toolchain

### Current State (Mainframe-First)

| Tool | Purpose | Notes |
|------|---------|-------|
| ISPF (Interactive System Productivity Facility) | Primary z/OS IDE — editing, browsing, submitting JCL | 3270 green-screen interface; all current MiCPS developers use ISPF daily |
| IBM Endevor | Source code management and change management for z/OS | Centralized SCM; controls promotion of code through DEV → TEST → PROD environments; predecessor to Git in maturity model |
| CA7 / IBM TWS | Job scheduler | Manages batch job streams, dependencies, calendars, and SLA monitoring |
| SCLM (Software Configuration Library Manager) | Alternative SCM for some MiCPS modules (legacy) | Some older modules not yet migrated to Endevor |
| File-AID / XPEDITER | Mainframe debugging and file browsing tools | XPEDITER used for interactive COBOL debugging; File-AID for VSAM and sequential file inspection |
| IBM OMEGAMON | Performance monitoring for CICS, DB2, and batch | Real-time and historical performance metrics for the z/OS environment |

> ⚠️ VALIDATE: Confirm whether Endevor or SCLM is the primary SCM for MiCPS. Confirm CA7 vs. TWS for job scheduling.

### Target State (Hybrid / Cloud-Native)

| Tool | Purpose |
|------|---------|
| GitHub (Enterprise) | Source code management for all cloud-native services and COBOL modules (via Endevor-Git bridge) |
| GitHub Actions | CI/CD pipeline — build, test, security scan, deploy |
| IBM DBB (Dependency Based Build) | Mainframe-aware build tool; integrates with GitHub Actions for COBOL CI/CD |
| Endevor ↔ Git Bridge | Synchronizes Endevor inventory with GitHub repositories; enables COBOL code in Git-based workflows |
| Jira | Work item tracking — epics, stories, bugs, tech debt items |
| SonarQube | Static analysis — code quality gates for Java; COBOL support via plugins |
| AWS CodePipeline | Deployment pipeline for cloud-native EKS workloads |
| Harness | Optional deployment orchestration for canary / blue-green releases |

### Testing Frameworks

| Layer | Tool / Approach | Notes |
|-------|----------------|-------|
| COBOL unit testing | IBM Z Unit Testing Framework (ZUnit) | Mainframe-native unit testing; integrates with DBB |
| COBOL integration testing | Batch regression: compare output files against expected results (golden file testing) | Primary QE method for MiCPS today |
| Java unit testing | JUnit 5 + Mockito | Standard for cloud-native services |
| Java integration testing | Spring Boot Test + Testcontainers | Spins up Aurora, Kafka containers for integration tests |
| End-to-end / regression | Custom QE harness (Digital Brain QE harness) | Claim scenarios driven through full pipeline; compare mainframe vs. cloud outputs during shadow mode |
| Performance testing | IBM zPCR for mainframe; Gatling / k6 for cloud services | |

### Jira Project Structure

| Project Key | Scope |
|------------|-------|
| MICPS | MiCPS mainframe changes — bug fixes, regulatory updates, config changes |
| MIGRATE | Cloud-native migration work — epics per wave, stories per module |
| INFRA | AWS infrastructure and platform engineering |
| DIGITAL-BRAIN | Digital Brain project — connectors, harness, knowledge layer |

---

## 7. Known Technical Debt

This section documents the highest-risk areas of technical debt in MiCPS. These are the primary targets for knowledge extraction by the Digital Brain project.

### 7a. Tribal Knowledge Concentration

| Area | Knowledge Owner(s) | Risk Level | Notes |
|------|------------------|------------|-------|
| Adjudication Engine (ADJUD-MAIN) core logic | James Whitfield (28 years) | Critical | Business rules for coverage determination embedded in COBOL logic; no external documentation; James retiring 2027 |
| DRG Pricing and Grouper logic | James Whitfield + 1 other | Critical | Custom DRG grouper modifications not in standard CMS tables; modification history unknown |
| COB calculation edge cases | Retiring engineer (name TBD) | High | Non-standard COB scenarios handled by hardcoded COBOL conditions; no specification document |
| VSAM file record layouts (undocumented) | James Whitfield | Critical | 3–4 key VSAM files have no current COPYBOOK or layout documentation; decipherable only by reading COBOL programs |
| Batch job dependency chain | Operations team | High | Complete dependency map exists only in CA7 scheduler; no human-readable documentation |
| Fee schedule override logic | 2 senior engineers | High | Manual fee schedule overrides applied via a separate KSDS file; override logic undocumented |

### 7b. Undocumented VSAM File Structures

| File | Issue | Impact |
|------|-------|--------|
| FEE-SCHED | Record layout partially documented; sections added over 15 years without schema update | Fee schedule migration to cloud will require reverse-engineering |
| AUTH-FILE | Mixed record types within single KSDS — record type discriminator in byte 1, not documented | Auth validation cloud service cannot be built without understanding record format |
| ACCUM-FILE | Annual reset logic and mid-year enrollment handling are encoded in file structure; no spec | Accumulator service migration is blocked until layout is fully documented |
| DRG-RATES | RRDS slot layout has been modified for custom DRG extensions; original RRDS definition was for CMS standard DRGs | DRG pricing migration requires full reverse engineering + validation against CMS tables |

### 7c. Hardcoded Parameters and Undocumented Dependencies

| Issue | Location | Risk |
|-------|---------|------|
| Hardcoded cutoff dates | Multiple COBOL programs contain hardcoded regulatory dates (e.g., ICD-10 transition date, ACA effective dates) | Regulatory changes may silently fail if hardcoded dates are not updated |
| Hardcoded payer IDs | COB programs hardcode payer IDs for specific coordination agreements | Adding new COB partners requires code change + release cycle |
| JCL hardcoded DSNs | Several JCL jobs reference dataset names (DSNs) with hardcoded date suffixes; automated by a preprocessing script that is itself undocumented | DSN generation failure breaks entire batch stream |
| Implicit job sequencing | Some jobs depend on a previous job's output file being present on DASD (disk); dependency not declared in CA7 — detected only by ABEND when file is missing | Batch stream failures are difficult to diagnose without knowing the implicit dependency |
| CICS transaction timeouts | CICS transaction timeouts are set per-transaction in the CICS CSD (Control System Definition); not in source code; no documentation | Timeout values may be inappropriate for cloud-integrated transactions |

#### ACCUM-FILE Concurrency Issue

| Attribute | Detail |
|-----------|--------|
| Issue | ACCUM-FILE (KSDS) is updated by both CICS online transactions (real-time accumulator queries during eligibility checks) and JCL batch (adjudication cycle accumulator updates), creating z/OS enqueue conflicts |
| Symptom | During batch window open/close transitions, CICS transactions attempting to read ACCUM-FILE while batch holds an exclusive enqueue cause CICS transaction timeouts and occasional **ABEND X522** (deadlock) |
| Current mitigation | CICS regions are quiesced for ACCUM-FILE access during peak batch window; real-time accumulator queries during this window return **cached values that may be up to 24 hours stale** |
| Risk | High — any CICS quiesce failure during batch exposes stale accumulator data to real-time eligibility checks, potentially causing incorrect cost-share calculations for members who have met their deductible or OOP max |
| Modernization driver | This concurrency issue is a primary driver for the Wave 2 migration of the accumulator function to **Amazon DynamoDB** — DynamoDB eliminates the enqueue conflict by providing a cloud-native accumulator service with real-time read/write without batch window coordination |

### 7d. Highest Complexity Modules (Migration Risk)

| Module | Complexity Driver | Estimated Migration Effort |
|--------|-----------------|--------------------------|
| Adjudication Engine | 30 years of accumulated business rules; no specification; highest tribal knowledge | Very High (Wave 5) |
| COB Engine | Non-standard COB scenarios; hardcoded payer logic; edge cases in COBOL conditions | High (Wave 4) |
| DRG Pricing / Grouper | Custom grouper extensions; undocumented RRDS layout; annual CMS update dependency | High (Wave 3) |
| Claims Intake & Editing | NCCI edit tables managed as VSAM — update cycle and override logic undocumented | Medium-High (Wave 3) |
| Overpayment / Recovery | Recovery offset logic tightly coupled to payment module; shared DB2 tables | Medium (Wave 5) |

---

## Glossary — MiCPS and Mainframe Terms

| Term | Definition |
|------|-----------|
| MiCPS | Mivan Claims Processing System — the core mainframe claims adjudication platform |
| z/OS | IBM's operating system for mainframe (zSeries) hardware |
| COBOL | Common Business-Oriented Language — primary application language in MiCPS |
| JCL | Job Control Language — IBM scripting language for submitting and controlling batch jobs on z/OS |
| CICS | Customer Information Control System — IBM's online transaction processing subsystem |
| VSAM | Virtual Storage Access Method — IBM's high-performance file access method on z/OS |
| KSDS | Key Sequenced Data Set — VSAM type for keyed random and sequential access |
| ESDS | Entry Sequenced Data Set — VSAM type for sequential/append-only access (logs, queues) |
| RRDS | Relative Record Data Set — VSAM type for direct access by slot number (lookup tables) |
| DB2 | IBM's relational database for z/OS — MiCPS's primary structured data store |
| ISPF | Interactive System Productivity Facility — primary z/OS developer interface (3270 green screen) |
| Endevor | Broadcom's mainframe SCM and change management product |
| CA7 / TWS | Job scheduling tools for z/OS batch — manage job streams, dependencies, SLAs |
| BMS | Basic Mapping Support — CICS facility for defining 3270 terminal screen maps |
| JES2 | Job Entry Subsystem 2 — z/OS component that manages batch job queuing and output |
| IDCAMS | IBM utility program for defining, managing, and maintaining VSAM datasets |
| ABEND | Abnormal End — mainframe term for a program crash / abnormal termination |
| DSN | Data Set Name — the identifier for a file on z/OS DASD (disk) storage |
| DASD | Direct Access Storage Device — mainframe disk storage |
| EBCDIC | Extended Binary Coded Decimal Interchange Code — IBM's character encoding (vs. ASCII) |
| DBB | IBM Dependency Based Build — modern build tool for COBOL that integrates with Git/GitHub |
| ZUnit | IBM's unit testing framework for COBOL on z/OS |
| Strangler Fig | Migration pattern: incrementally replace legacy functions with cloud-native equivalents |
| Shadow Mode | Running cloud-native service in parallel with mainframe to validate outputs before cutover |
| Coexistence Router | API gateway / routing layer that directs traffic to mainframe or cloud service during migration |
| MiFCT | Mivan Facets Claims Technology — TriZetto Facets implementation for MA and Medicaid |
| TriZetto Facets | Commercial claims processing platform by TriZetto (Cognizant) |
| LOB Router | MiEDI routing rules that direct claims to MiCPS or MiFCT based on member LOB |
| Post-Adjudication Service | Java service called after MiFCT adjudication to handle CMS/state reporting |
| Option A Integration | Direct REST API call from Facets to provider validation service |
