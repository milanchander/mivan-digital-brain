# Mivan Digital Brain — Technical Overview

*For external technical review. Last updated: 2026-08-10.*

This document summarizes the current state of the Mivan Digital Brain repository.
It is descriptive, not aspirational: where something is scaffolding or planned,
it says so. Where knowledge is unverified, that is flagged. The authoritative
sources are the files referenced throughout; this is a reading guide over them.

---

## 1. What it is and what problem it solves

The Mivan Digital Brain is an AI-native knowledge layer for Mivan Health Plan's
claims and provider domains, instantiated from Accenture's Digital Brain
framework (referred to internally as **CKF** — the canonical CKF specification is
not held in this repository, so §9 assesses alignment against the framework
principles that are observable in the artifacts).

Problem addressed: Mivan's commercial claims run on **MiCPS**, ~15 years of
accreted IBM Enterprise COBOL whose behaviour is documented almost entirely in
source and in a small number of subject-matter experts (principally James
Whitfield). Modernization and day-to-day development are bottlenecked on this
undocumented, tribal knowledge. The Digital Brain captures that knowledge as
structured, layered, provenance-tracked Markdown, makes explicit what is *not*
yet known (ghost nodes), and exposes it to developers and QE through a portal
chat and a set of Claude Code skills.

Two design commitments distinguish it:
- **Absence is explicit.** Missing knowledge is registered as a ghost node, never
  silently omitted.
- **OBSERVABLE vs INFERRED.** Extracted knowledge separates what is
  deterministically true from source from what is a hypothesis requiring SME
  confirmation.

Domain scope is deliberately limited to **claims** and **provider**.

---

## 2. Architecture — L1–L6, MEM, routing map, ghost nodes

Knowledge is a layered estate of Markdown files, each carrying YAML frontmatter
(`layer`, `node_type`, `domain`, `source`, `last_synced`, `fidelity`,
`links_back`, `links_forward`, `ghost_node_id`, `validated_by`).

| Layer | Name | Content | Files |
|---|---|---|---|
| L1 | Enterprise | Org-wide policy, standards, system inventory | `L1-enterprise/mivan-enterprise-context.md` |
| L2 | Domain | Claims/provider domain knowledge by LOB | 6 files (see §4) |
| L3 | Systems | System landscape, integrations, LOB routing | `L3-systems/mivan-system-landscape.md` |
| L4 | Application | MiCPS application behaviour, modules, tech debt | `L4-application/micps-application-knowledge.md` |
| L5 | Business Rules | Adjudication/eligibility/provider rules | `L5-business-rules/claims-business-rules.md` |
| L6 | Task Intelligence | Procedural/QE knowledge | 3 training agendas only; real task intelligence is a ghost node |

Cross-cutting structures:

- **MEM** (`knowledge/MEM/`) — a staging and provenance area: `decisions/`
  (architecture decision records — parallel-build rationale, AWS deployment
  approach), `sme-sessions/`, and `contributions/` (extraction/interview drafts
  awaiting graduation into L1–L6). A `CAPTURE-TEMPLATE.md` defines the draft
  format.
- **Routing map** (`knowledge/routing-map.md`) — a context-selection system
  defining ten question classes (Q01–Q10) and LOB-aware traversal, so a question
  loads only the files on its path (target: <1% of the estate per question).
  Classification and traversal are currently **manual** (see §9).
- **Ghost node registry** (`knowledge/ghost-nodes.md`) — the authoritative list
  of known gaps, each with layer, owner, risk, and lifecycle status
  (`GHOST → IN-FLIGHT → COMPLETE`). See §8.

Node lifecycle: a gap is registered as a ghost node; when work starts it goes
IN-FLIGHT; when a knowledge file is authored and back-linked it graduates to
COMPLETE. Frontmatter `fidelity` (HIGH / PARTIAL / DRAFT) records confidence.

---

## 3. Technical stack

**Frontend** — a single-file portal, `index.html`, with inline vanilla JavaScript
and D3 (force-directed knowledge graph with cluster hulls, architecture diagram,
blast-radius view). It hosts the "Ask the Digital Brain" chat and a "Contribute"
knowledge-contribution workflow. No build step.

**Backend** — `backend/app.py`, a FastAPI + WebSocket server built on the
**Claude Agent SDK** (`ClaudeSDKClient` / `ClaudeAgentOptions`), model
`claude-sonnet-4-6`. It runs Claude calls server-side (no API key in the browser;
uses the Claude Code login), grounded in the `knowledge/` files (frequently-used
files are pre-loaded into the system prompt; the chat can also Read/Grep/Glob on
demand). Endpoints: `/health`, `/ws/chat` (chat + curate modes),
`/connectors/status`, `/contributions/save`, `/contributions/list`. `start.ps1`
is the local dev launcher.

**Connectors** — two distinct things share the name:
- `backend/connectors/` — working Python connector modules (GitHub, ServiceNow,
  Confluence) backed by `mock_data/` JSON, surfaced via the backend's connector
  endpoints. These are demonstrations against mock data, not live sync.
- `connectors/` (repo root) — empty scaffolding for the planned MCP sync
  connectors (Confluence, GitHub, Jira, ServiceNow). Not implemented.

**Target infrastructure (planned, not deployed)** — AWS: Lambda or ECS Fargate
(backend), Secrets Manager (credentials), S3 + CloudFront (frontend). Rationale in
`knowledge/MEM/decisions/aws-deployment-approach.md`.

---

## 4. Program trees built — Commercial, MA, Medicaid, Provider

Claims are routed at intake by **MiEDI** (LOB router): **Commercial → MiCPS**
(COBOL, Java migration path); **Medicare Advantage and Medicaid → MiFCT (TriZetto
Facets)**. The Java services for MA and Medicaid are **post-adjudication reporting**
services called by MiFCT via REST — they do not adjudicate.

| LOB | Adjudicated by | Primary component | COBOL | Java | Status |
|---|---|---|---|---|---|
| Commercial | MiCPS | `MCOMCLDR0` | `src/cobol/commercial/` | `src/java/commercial/` | **Planned — not built** (directories do not yet exist) |
| Medicare Advantage | MiFCT (Facets) | `MaPostAdjudicationService` (post-adj) | n/a | `src/java/ma/` | **Built (Java only)** |
| Medicaid | MiFCT (Facets) | `MedicaidStateReportingService` (post-adj) | n/a | `src/java/medicaid/` | **Built (Java only)** |
| Provider Data (cross-LOB) | MiCPS + MiFCT | `MPRVVLDR0` / `ProviderValidationOrchestrator` | `src/cobol/provider/` | `src/java/provider/` | **Built** |

Provider validation is shared: MiCPS calls `MPRVVLDR0` (COBOL batch); MiFCT calls
the REST endpoint `POST /api/v1/provider/validate/facets` (Option A).

Separately, the original demonstration remains the most complete parallel build:

- **MICPS-4471 — Near-Duplicate Claim Detection.** COBOL `MOVPDUP1` (program,
  copybooks, DDL, JCL, ZUnit) in `src/cobol/`, and a Spring Boot service in
  `src/java/duplicate-detection/` (13 tests, Swagger UI). Story in
  `src/stories/MICPS-4471.md`.

---

## 5. Skills — all 8

Claude Code skills in `skills/`, activated by developer intent. Each must be read
in full before use; validation/analysis steps are not skippable.

| # | Skill | File | Purpose |
|---|---|---|---|
| 1 | Java Feature Builder | `java-feature-builder.md` | Implement a Jira story as a Spring Boot feature |
| 2 | COBOL → Java Migrator | `cobol-to-java-migrator.md` | Convert a COBOL program to equivalent Java |
| 3 | Java Test Generator | `java-test-generator.md` | Generate tests for a Java class |
| 4 | Java Code Reviewer | `java-code-reviewer.md` | Structured review of Java code |
| 5 | COBOL Feature Builder | `cobol-feature-builder.md` | Implement a Jira story as IBM Enterprise COBOL (program, copybooks, DDL, JCL, ZUnit) |
| 6 | COBOL Test Generator | `cobol-test-generator.md` | Generate/improve ZUnit tests for a COBOL program |
| 7 | COBOL Code Reviewer | `cobol-code-reviewer.md` | Structured review of COBOL against MiCPS standards + migration readiness |
| 8 | COBOL Knowledge Extractor | `cobol-knowledge-extractor.md` | Reverse-engineer a COBOL program into a MEM draft — dependency map (incl. implicit dependencies), business logic, migration-risk assessment, shadow-mode test scenarios — under OBSERVABLE vs INFERRED discipline |

---

## 6. Contribution framework — how knowledge enters

Knowledge reaches the formal layers through a defined path rather than direct
edits:

1. **Capture** — an SME interview (via the portal "Contribute" flow) or an
   automated extraction (Skill 8 on a COBOL program) produces a draft in
   `knowledge/MEM/contributions/`, using the `CAPTURE-TEMPLATE` format and
   marking OBSERVABLE vs INFERRED content.
2. **Curate** — the backend `/ws/chat` curate mode (and the portal review panel)
   structures and reviews the draft; approvals persist to disk via
   `/contributions/save` (validated, path-traversal-guarded, non-overwriting).
3. **Validate** — an SME confirms the INFERRED items; confirmations are folded
   back into the draft.
4. **Graduate** — the validated content becomes a file in the appropriate
   L1–L6 layer with bidirectional `links_back`/`links_forward`, its
   `ghost_node_id` is referenced, and the ghost node is flipped to COMPLETE.

Two drafts currently sit in `contributions/`:
- `UTILIZATION-MANAGEMENT-2026-08-09.md` — graduated to
  `L2-domain/utilization-management.md` (fidelity DRAFT; §1–7 specifics still
  need SME validation).
- `MEDIRTR0-2026-08-09.md` — extraction of the MiEDI LOB router; SME-confirmed
  2026-08-09 on effective-date placement, CMS-prefix mapping, and the STATELINK
  comment; not yet graduated (see §8, `FACETS-LOB-ROUTING-TABLE`).

---

## 7. Current state — built vs scaffolded

**Built / populated**
- `knowledge/` — L1 (1 file), L2 (6), L3 (1), L4 (1), L5 (1); MEM (decisions,
  templates, 2 contribution drafts); routing map; ghost registry.
- `skills/` — 8 skills.
- `src/` — MICPS-4471 (COBOL + Java, tests passing); MA, Medicaid, Provider
  services; Commercial is planned only.
- `backend/` — FastAPI/WebSocket chat server; connector modules over mock data;
  contribution endpoints.
- `docs/` — this overview.

**Partial**
- **L6** — contains three training agendas only; real task intelligence (defect
  patterns, incident history, QE gaps) is a ghost node awaiting live Jira/
  ServiceNow data.
- **backend connectors** — functional but over `mock_data/`, not live systems.
- Several L2/L4/L5 nodes carry `fidelity: DRAFT/PARTIAL` pending SME validation.

**Scaffolding only (empty)**
- `connectors/` (root) — planned MCP sync connectors (Confluence, GitHub, Jira,
  ServiceNow).
- `harnesses/developer/`, `harnesses/qe/` — planned agent harnesses.
- `config/` — planned environment/harness configuration.

Next build items per project intent: `connectors/` and `harnesses/`, once AWS
access is confirmed.

---

## 8. Known gaps — from `ghost-nodes.md`

The registry currently holds **26 nodes: 7 COMPLETE, 1 IN-FLIGHT, 18 open GHOST.**
(Counts are current as of this document; `knowledge/ghost-nodes.md` is
authoritative.)

**Critical — blocks MiCPS migration (all GHOST, owner James Whitfield):**
`ADJUD-BUSINESS-RULES-SPEC`, `ACCUM-FILE-LAYOUT`, `DRG-GROUPER-EXTENSIONS`,
`COB-PAYER-AGREEMENTS`, `AUTH-FILE-LAYOUT`, `FEE-SCHED-LAYOUT`. Common theme:
business rules and VSAM record layouts that exist only as inline COBOL logic,
undocumented and extended over ~15 years.

**High:**
- COMPLETE: `MEDICARE-ADVANTAGE-DOMAIN`, `MEDICAID-DOMAIN`,
  `PROVIDER-DATA-LIFECYCLE`, `UTILIZATION-MANAGEMENT`.
- IN-FLIGHT: `FACETS-LOB-ROUTING-TABLE` — MiEDI routing table; extraction from
  MEDIRTR0 done and partly SME-validated; blocked on 3 COPYBOOK layouts, two
  threshold literal values, routing-table maintenance, and the file-vs-queue
  handoff before graduation.
- GHOST: `L6-TASK-INTELLIGENCE`, `NCCI-TABLE-MANAGEMENT`,
  `BATCH-DEPENDENCY-COMPLETE` (full chain only in the CA7 scheduler),
  `MIFCT-CONFIGURATION`, `MIFCT-POSTADJ-INTEGRATION`.

**Medium:** COMPLETE — `PROVIDER-SANCTIONS`, `HEALTH-PRIMER`,
`REGULATORY-LANDSCAPE`. GHOST — `STATE-SPECIFIC-CLAIM-RULES` (partly documented),
`INTRADAY-BATCH-DETAIL`, `CLAIM-ADJUSTMENT-WORKFLOW`, `MIFCT-MODERNIZATION` (not
yet scoped).

**Low (GHOST):** `MEMBER-PORTAL-INTEGRATION`, `MIPAY-INTEGRATION`,
`HISTORICAL-DEFECT-PATTERNS`.

The MiFCT/Facets cluster (`MIFCT-CONFIGURATION`, `FACETS-LOB-ROUTING-TABLE`,
`MIFCT-POSTADJ-INTEGRATION`, `MIFCT-MODERNIZATION`) is the least-mature area:
government-claims adjudication logic lives in Facets configuration that the Brain
does not yet document.

---

## 9. CKF alignment — where we match and where we diverge

CKF is the framework this repository instantiates. Its canonical specification is
not held here, so the following assesses alignment against the framework
principles evident in the artifacts (layered knowledge, explicit absence,
context-selection routing, provenance).

**Where it matches**
- **Layered knowledge estate (L1–L6)** with typed nodes and YAML provenance
  frontmatter.
- **Explicit absence** — the ghost-node registry makes gaps first-class, with a
  defined `GHOST → IN-FLIGHT → COMPLETE` lifecycle and owners/risk.
- **Provenance and fidelity** — `source`, `validated_by`, `last_synced`, and
  `fidelity` on every node; MEM `decisions/` records architecture rationale.
- **Context selection / progressive disclosure** — the routing map defines
  question classes and LOB-aware traversal with per-class context budgets.
- **Epistemic discipline** — OBSERVABLE vs INFERRED separation in extraction, and
  a capture → curate → validate → graduate pipeline before knowledge is trusted.

**Where it diverges (implementation gaps, not design disagreements)**
- **Routing is manual.** Question classification and traversal are performed by
  the agent reading the routing map; there is no automated classification/
  traversal engine, and the per-class token budgets are documented but **not
  enforced**. The routing map itself flags this as a Level-3 goal.
- **No live ingestion.** The root `connectors/` (MCP sync) are empty scaffolding;
  the backend connectors run against mock data. No knowledge is currently synced
  from Jira/GitHub/ServiceNow/Confluence.
- **Harnesses not built.** `harnesses/developer` and `harnesses/qe` are empty; the
  developer/QE agent experiences described in the framework are not yet
  implemented.
- **L6 is thin.** Task-intelligence knowledge is training agendas plus ghost
  nodes, pending real operational data.
- **Single-file portal.** The UI is one hand-authored `index.html`, adequate for
  demonstration but not a framework-generated or componentized front end.
- **Not deployed.** The AWS target architecture is designed and access is being
  requested, but nothing is running in cloud; the backend uses a local Claude
  Code login rather than Secrets Manager.

Overall: the knowledge *model* and *disciplines* align closely with the framework;
the *automation and ingestion* layers are the principal divergence and the stated
next build.

---

## 10. Roadmap — target state

This document is the **as-is**. The **to-be** design that closes the §9
divergences (manual routing, no live ingestion, thin L6) is
`docs/next-gen-architecture.md` — three enhancements (L6 operational memory,
event-driven live ingestion with a two-dimension confidence vector + PHI gate,
and an executable impact-analysis engine) plus the integration seam. It is a
design proposal, not built.
