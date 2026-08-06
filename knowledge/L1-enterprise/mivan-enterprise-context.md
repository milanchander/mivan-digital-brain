---
layer: L1
domain: enterprise
source: manual
last_synced: 2026-08-06
---

# Mivan Health Plan — Enterprise Context

## 1. Organization Overview

- **Legal Name**: Mivan Health Plan, Inc.
- **Business Model**: National managed care organization; fully-insured and ASO commercial plans, Medicare Advantage, and Medicaid managed care
- **Membership**: ~150 million members across commercial, Medicare, and Medicaid lines of business
- **Geographic Footprint**: Nationwide; licensed in all 50 states and D.C.
- **Primary Business Segments**:
  - **Mivan Commercial** — employer-sponsored group plans, individual marketplace
  - **Mivan Government Programs** — Medicare Advantage and Medicaid managed care
  - **Mivan Health Services** — care management, pharmacy benefits, specialty networks

## 2. Technology Landscape

### Core Claims Platform — MiCPS

MiCPS (Mivan Claims Processing System) is Mivan's homegrown mainframe claims adjudication engine. It is the system of record for all commercial medical claims.

| Attribute | Detail |
|-----------|--------|
| System Name | MiCPS — Mivan Claims Processing System |
| Platform | IBM z/OS mainframe |
| Languages | COBOL, JCL, CICS (online transaction processing via IBM CICS), VSAM (file management — KSDS, ESDS, RRDS file types used for reference data, work files, and intermediate claims processing) |
| Database | IBM DB2 |
| Lines of Business | Commercial medical claims only (Medicare Advantage adjudicated on TriStar MA Platform; Medicaid adjudicated on StateLink MCO Platform) |
| Age | ~30 years in production; continuously extended |
| Throughput | Processes ~4 million claims per day at peak |
| Integration Style | Batch file exchange (SFTP), MQ messaging; no REST APIs |
| Documentation | Sparse; system knowledge concentrated in a small group of senior engineers |

### Surrounding Systems

| System | Purpose | Technology |
|--------|---------|-----------|
| MiEDI | EDI clearinghouse gateway — 837 intake and 835 output | IBM Sterling B2B |
| MiMember | Member eligibility and enrollment | Oracle, on-prem |
| MiProvider | Provider master data management | SQL Server, on-prem |
| MiPortal | Provider and member self-service web portal | Java / Spring, on-prem |
| MiReport | Operational and regulatory reporting | Cognos, DB2 |
| MiAuth | Prior authorization workflow | Legacy vendor platform |
| MiDataSQL | Downstream SQL Server database receiving batch feeds from MiCPS for operational reporting and provider payment reconciliation | SQL Server, on-prem |
| MiDataLake | AWS S3-based data lake receiving batch feeds from MiCPS in fixed-width and CSV formats for analytics, regulatory reporting, and ML model training | AWS S3, us-east-1 |

**Batch Integration Note:** Batch jobs run nightly and intraday via JCL, sending outbound feeds to MiDataSQL (SQL Server) and MiDataLake (S3). Feed failures are detected via job abend monitoring and trigger automated alerts to the operations team.

### Cloud Footprint (Current State)

Mivan's cloud adoption is early-stage. A shared AWS landing zone exists but hosts only non-production workloads and greenfield transformation pilots. No production claims processing runs in cloud today.

| Environment | AWS Account | Region | Purpose |
|-------------|-------------|--------|---------|
| Transformation Pilot | Mivan-Dev | us-east-1 | Cloud-native migration POCs |
| Shared Services | Mivan-Shared | us-east-1 | CI/CD, secrets, observability |
| Data Platform | Mivan-Data | us-east-1 | Snowflake integration, analytics |

## 3. Strategic Priorities

### Priority 1 — Cloud-Native Platform Migration

Migrate MiCPS function-by-function to a custom cloud-native architecture on AWS. Each migrated function is re-implemented as a microservice before the mainframe equivalent is decommissioned. Target completion: 5-year program.

- New platform stack: Java 21, Spring Boot, PostgreSQL/Aurora, Kafka, AWS EKS
- Migration approach: strangler fig pattern — incremental extraction, not big-bang rewrite
- First migrations in flight: eligibility validation, duplicate claim detection, remittance generation

### Priority 2 — AI-Native SDLC

Adopt an AI-native software development lifecycle across all engineering teams. This includes AI-assisted development, automated knowledge capture, intelligent testing, and AI-augmented operations.

- Designated as a strategic initiative by the CTO in Q1 2026
- Digital Brain is the foundational knowledge layer enabling this transformation
- Goal: reduce time-to-production for new features by 40% within 18 months

### Priority 3 — Knowledge Preservation and Democratization

Capture the institutional knowledge embedded in MiCPS and its senior engineers before it is lost to attrition and platform migration. Make that knowledge accessible to all engineers — including those unfamiliar with mainframe.

- Estimated 60–70% of MiCPS system knowledge exists only in the minds of ~12 senior engineers, most within 3–5 years of retirement
- Digital Brain is the primary vehicle for extracting, structuring, and perpetuating this knowledge

## 4. Transformation Mandate

### Why Now

Mivan's leadership approved the transformation program in response to compounding pain points that have reached a strategic inflection point:

| Pain Point | Impact |
|------------|--------|
| Slow release cycles | MiCPS releases take 6–9 months end-to-end due to mainframe change management, regression testing, and batch scheduling constraints |
| Tribal knowledge concentration | ~80% of COBOL/JCL expertise sits with ~12 engineers; 4 have announced retirement in 2026–2027 |
| Platform velocity ceiling | Mainframe architecture cannot support real-time APIs, event streaming, or modern ML/AI integration patterns |
| Competitive pressure | Competing payers are shipping AI-native features (real-time auth, predictive denials) that MiCPS cannot support |
| Talent pipeline | New engineering graduates do not know COBOL; recruiting and onboarding is increasingly difficult |

### Transformation Approach

- **Migration Pattern**: Strangler fig — extract and replace one functional domain at a time; coexistence layer handles routing between mainframe and cloud services during transition
- **Knowledge Strategy**: Instrument MiCPS code, JCL, and DB2 schemas before migration to capture business rules embedded in logic; this feeds L5 and L6 of the Digital Brain
- **AI-Native SDLC**: All new cloud-native services are built within an AI-augmented developer workflow from day one
- **Program Governance**: Transformation is governed by a cross-functional steering committee chaired by the CTO, with monthly executive reviews

### Digital Brain's Role in the Transformation

The Digital Brain is not a side project — it is infrastructure for the transformation itself:

1. **Knowledge extraction**: Connector ingests MiCPS COBOL modules, JCL, DB2 DDL, runbooks, and Confluence docs and structures them into L3–L6 knowledge layers
2. **Developer enablement**: The developer harness surfaces relevant MiCPS business rules, data mappings, and architectural decisions to engineers building cloud-native replacements
3. **QE enablement**: The QE harness surfaces historical defect patterns, test scenarios, and edge cases derived from 30 years of production claims processing
4. **Onboarding acceleration**: New engineers gain mainframe context without requiring pairing with senior COBOL developers

## 5. Key Stakeholders

| Name | Title | Organization | Relevance to Digital Brain |
|------|-------|-------------|---------------------------|
| Sandra Okafor | Chief Technology Officer | Mivan Technology | Executive sponsor; approved AI-native SDLC initiative |
| Marcus Delgado | VP, Claims Technology | Mivan Technology | Owns MiCPS and cloud migration program; primary Digital Brain champion |
| Priya Nair | Director, Platform Engineering | Mivan Technology | Owns AWS landing zone, EKS platform, and DevOps toolchain |
| James Whitfield | Principal Engineer, MiCPS | Mivan Technology | 28-year mainframe veteran; primary source of tribal COBOL/JCL knowledge |
| Anita Rosen | Director, QE and Test Automation | Mivan Technology | Owns QE harness requirements; driving test intelligence use cases |
| Kevin Tran | Product Manager, Transformation Program | Mivan Technology | Manages migration roadmap and program governance |
| Dr. Linda Park | VP, Government Programs | Mivan Health Plan | Stakeholder for Medicare/Medicaid knowledge domains |
| Rachel Mbeki | Chief Compliance Officer | Mivan Health Plan | HIPAA, HITRUST, and CMS compliance requirements |

## Glossary — Mivan Enterprise Terms

| Term | Definition |
|------|-----------|
| MiCPS | Mivan Claims Processing System — the core mainframe claims adjudication platform |
| MiEDI | Mivan's EDI clearinghouse gateway (IBM Sterling) |
| Strangler Fig | Migration pattern: incrementally replace legacy functions with cloud-native equivalents |
| AI-Native SDLC | Mivan's initiative to embed AI assistance throughout the software development lifecycle |
| Digital Brain | AI-native knowledge layer being built on Accenture's framework to enable the transformation |
| Transformation Program | The 5-year initiative to migrate MiCPS to cloud-native architecture |
| Coexistence Layer | Routing layer that directs traffic to either mainframe or cloud service during migration |
| Tribal Knowledge | System knowledge held informally by individuals — not documented, not transferable without them |
