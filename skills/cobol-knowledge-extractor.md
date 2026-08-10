---
name: cobol-knowledge-extractor
description: Provide a MiCPS COBOL program and say "extract knowledge", "document this", or "what does this program actually do" to produce a MEM knowledge-node draft for the Digital Brain — dependency map, business logic, migration-risk assessment, and shadow-mode test scenarios — with every finding marked OBSERVABLE or INFERRED and flagged for SME confirmation.
---

# COBOL Knowledge Extractor

## Trigger

Activate when a developer provides COBOL code and says **"extract knowledge"**, **"document this"**, **"what does this program actually do"**, or **"reverse-engineer this COBOL"**.

---

## Purpose

Read a MiCPS COBOL program and extract structured organizational knowledge into a Digital Brain MEM draft node, ready for SME validation and eventual graduation to an L3/L4/L5 layer. The output captures what the program does, what it depends on, how risky it is to replace, and how a modern replacement could be validated against it.

This skill exists because MiCPS is ~15 years of accreted COBOL whose behaviour is documented nowhere but the source and a handful of SMEs (primarily James Whitfield). Extraction accelerates the SME's work by producing a reviewable first draft; it never replaces the SME.

The single governing discipline of this skill is the separation of **OBSERVABLE** (deterministically derivable from source) from **INFERRED** (a hypothesis about intent). Read the OUTPUT STANDARDS section below before producing anything.

---

## Input Contract

| Input | Required | Effect on extraction |
|---|---|---|
| COBOL program | Yes | All steps |
| COPYBOOKs | Optional | Enables full record-layout extraction; absence is recorded as a gap, never inferred |
| JCL that invokes it | Optional | Enables job-stream and file-coupling analysis in STEP 2 |
| Called/calling programs | Optional | Enables coupling assessment in STEP 3B |
| L3/L4/L5 knowledge nodes | Read if present | Cross-reference for prior SME confirmation and known ghost nodes |
| `knowledge/ghost-nodes.md` | Read if present | Cross-reference known gaps; a new gap found here may already be registered |

If only the COBOL program is provided, all steps still run — but every missing input becomes an explicit "cannot be determined from source" entry, not a guess.

---

## STEP 1 — INTAKE AND CLASSIFY

Establish what you are looking at before extracting anything.

Record, all OBSERVABLE from source:

- `PROGRAM-ID` and any aliases
- Processing mode — Batch (JCL) or Online (`EXEC CICS` present)
- DIVISION and SECTION inventory
- Paragraph inventory (every paragraph name, in order)
- Line count and rough size

Then classify where this knowledge belongs in the estate:

- **L3 (Systems)** — if the program is primarily about integration, file/DB2 topology, or batch architecture
- **L4 (Application)** — if it is application behaviour, configs, or runbook-relevant logic (most MiCPS programs)
- **L5 (Business Rules)** — if it encodes adjudication/eligibility/pricing rules

Cross-reference `knowledge/ghost-nodes.md`: is this program's knowledge already registered as a ghost node (e.g. `ADJUD-BUSINESS-RULES-SPEC`, `COB-PAYER-AGREEMENTS`)? If so, name the node ID — this extraction is a candidate to move it toward COMPLETE.

---

## STEP 2 — MAP DEPENDENCIES

### OBSERVABLE dependencies

These are explicit in the source and are stated as fact. Enumerate:

- **Called programs** — every `CALL 'PROGNAME'` (static) and `CALL identifier` (dynamic — note dynamic calls cannot be fully resolved from source)
- **DB2 access** — every `EXEC SQL` cursor (`DECLARE`, `OPEN`, `FETCH`, `CLOSE`), single-row `SELECT`, `INSERT`/`UPDATE`/`DELETE`, and the tables each touches
- **COPYBOOKs** — every `COPY` member and what it supplies (record layout, working storage, SQLCA)
- **VSAM/sequential files** — every `SELECT … ASSIGN`, its organization (KSDS/ESDS/RRDS/sequential), and its access mode (READ/WRITE/REWRITE/DELETE)
- **JCL coupling** *(requires JCL)* — DD statements, datasets, and the job step's position in the stream

Present these as a dependency table with columns: Dependency, Type, Direction (calls / called-by / reads / writes), Evidence (paragraph + approx line).

### Implicit dependencies — highest migration risk

Explicit dependencies (CALL statements, DB2 cursors) are easy to find. Implicit dependencies are what make COBOL modernization dangerous, because they do not appear in a call graph and are only discovered when something breaks.

Hunt for these specifically:

- Shared data structures — COPYBOOKs used by multiple programs where one program's write affects another's read
- File-based coupling — a program reading a file that another program wrote in an earlier job step, where the dependency is not declared in JCL or the scheduler
- DASD residency assumptions — logic that assumes a dataset exists from a prior step without checking
- Initialization sequence dependencies — behaviour that differs based on what ran before it
- Global or shared state via VSAM — files updated by both CICS and batch, where timing determines correctness
- Commarea or LINKAGE assumptions — a subprogram assuming the caller populated a field it does not validate
- Implicit ordering — records assumed to arrive sorted because an upstream step sorted them

For each implicit dependency found, record:
- What the assumption is
- What breaks if it is violated
- Whether the assumption is enforced anywhere or merely relied upon

Cross-reference against L3 for known implicit dependencies already documented — MiCPS has at least one registered: batch jobs depending on prior job output on DASD, not declared in CA7, detected only by ABEND.

---

## STEP 3 — EXTRACT BUSINESS LOGIC

For each paragraph that implements logic (typically 3000-level and above), extract:

- **What it does** — the observable transformation (which fields it reads, computes, and writes)
- **The business condition(s)** it implements — each `IF`/`EVALUATE` branch and its outcome
- **Hardcoded values** — every literal used as a threshold, tolerance, reason code, status value, or limit, with the exact value and where it appears

For every extracted item, tag it OBSERVABLE or INFERRED:

- The **existence** of a branch, value, or computation is OBSERVABLE.
- The **business meaning or purpose** of that branch, value, or computation is INFERRED unless a source comment or prior SME confirmation (L4/MEM) supports it — and INFERRED items carry a confidence level per the OUTPUT STANDARDS.

Collect anything that cannot be resolved into a running list of open questions for the SME (used in STEP 4).

---

## STEP 3B — ASSESS MIGRATION RISK

Beyond documenting what the program does, assess how hard it will be to replace. Output a risk rating with reasoning.

Score each dimension LOW / MEDIUM / HIGH:

| Dimension | HIGH risk indicator |
|---|---|
| Coupling | Called by many programs, or calls many; shares VSAM with CICS |
| Implicit dependencies | Undeclared assumptions about prior steps or file state |
| Business rule density | Many hardcoded conditions with no external specification |
| Documentation gap | Behaviour not described anywhere in L4 or L5 |
| Data layout opacity | COPYBOOKs missing or record layout partially undocumented |
| Tribal knowledge dependence | Logic only explicable by a named individual |

Then give an overall rating and a one-paragraph rationale, plus a recommendation:

- EARLY CANDIDATE — isolated, well understood, low coupling. Safe to migrate first.
- SEQUENCED — needs specific prerequisites resolved first. Name them.
- BLOCKED — cannot be safely migrated until named ghost nodes are resolved. Name them.

Cross-reference the program's currently assigned migration wave in L4. If the risk assessment disagrees with the assigned wave, say so explicitly — that is a finding worth surfacing.

---

## STEP 4 — PRODUCE MEM OUTPUT

Assemble everything from STEPs 1–3B into a single MEM draft node. Save to `knowledge/MEM/contributions/[NODE-ID]-[YYYY-MM-DD].md` (never overwrite an existing file; append `-2`, `-3`, … if the name is taken).

Use the following template exactly.

```markdown
---
layer: MEM
node_type: extraction-draft
domain: [claims | provider | eligibility | pricing | …]
source: cobol-knowledge-extractor
program_id: [PROGRAM-ID]
ghost_node_id: [matching ghost node ID, or none]
last_synced: [YYYY-MM-DD]
fidelity: DRAFT
extraction_confidence: [high | medium | low]
observable_findings: [count]
inferred_findings: [count]
sme_confirmation_required: true
---

> **This is an extraction hypothesis, not verified knowledge.** Content marked
> OBSERVABLE is deterministically derived from source. Content marked INFERRED
> requires confirmation by a subject matter expert before it can be relied upon
> for migration decisions, test design, or business rule documentation.
> Extraction accelerates SME work; it does not replace it.

# Extraction Summary — [PROGRAM-ID]

[2–3 sentences: what the program is, its processing mode, and the headline
of the migration-risk assessment. State plainly what is known vs unknown.]

## Program Classification
- Target layer: [L3 / L4 / L5]
- Processing mode: [Batch / Online]
- Related ghost node: [ID or none]

## Dependency Map
### Observable dependencies
[table from STEP 2]

### Implicit dependencies (highest migration risk)
[list from STEP 2 — assumption / what breaks / enforced or relied-upon]

## Business Logic
[per-paragraph extraction from STEP 3, each item tagged OBSERVABLE or INFERRED
with confidence level for INFERRED items]

## Hardcoded Values
| Value | Location (paragraph ~line) | Observable | Business rationale |
|---|---|---|---|
| [value] | [3000-NAME ~N] | Yes | OPEN QUESTION — not derivable from source |

## Migration Risk Assessment
[the STEP 3B table, overall rating, one-paragraph rationale, recommendation,
and any disagreement with the assigned L4 migration wave]

## Open Questions for SME
1. [question — what evidence would resolve it]
2. …

## Suggested Shadow Mode Test Scenarios
[section below]
```

### Suggested Shadow Mode Test Scenarios

Derive test scenarios from the extracted logic that would validate a modern replacement produces identical output to this program.

For each business condition found in the source, propose a scenario:
- Input conditions
- Expected behaviour per the COBOL
- Which paragraph implements it
- Whether the expected behaviour is OBSERVABLE or INFERRED

Flag separately any scenario that requires SME confirmation before it can be used as a test oracle — an INFERRED behaviour cannot validate a migration, because the inference may be wrong.

Explicitly list boundary conditions worth testing: every threshold, tolerance, and hardcoded limit found, tested at, just below, and just above.

---

## OUTPUT STANDARDS — EPISTEMIC DISCIPLINE

Reading COBOL tells you WHAT happens with certainty. It rarely tells you WHY. This distinction is the single most important discipline in this skill.

Rules, in order of importance:

1. Never state an inference as a fact. Every INFERRED item carries a confidence level: LIKELY, PLAUSIBLE, or SPECULATIVE — and a one-line statement of what evidence would confirm or refute it.

2. A paragraph's business purpose is INFERRED unless there is a supporting comment in the source or prior SME confirmation in L4 or MEM. Naming a paragraph 3100-CHECK-ELIGIBILITY is not evidence that it checks eligibility correctly, or that eligibility means what you assume.

3. A hardcoded value's existence is OBSERVABLE. Its business rationale is never derivable from source. State the value; flag the rationale as an open question. Do not guess.

4. If a COPYBOOK is missing, say so. Do not infer record layout from field usage — record that layout could not be determined and why.

5. Where the extraction cannot determine something, say "cannot be determined from source" explicitly. A gap stated plainly is more valuable than a confident guess.

6. Comments in COBOL are often stale. Where a comment contradicts the code beneath it, report both and note that the code is authoritative for behaviour while the comment may reveal original intent.

7. This extraction is a HYPOTHESIS requiring SME confirmation. It is never a substitute for SME involvement. State this at the top of every output.

---

## REFERENCE

| Role | File |
|---|---|
| Gold standard program | `MOVPDUP1.cbl` |
| DB2 copybook pattern | `CLMPAYRC.cpy` |
| Working storage copybook | `MOVPDUP1.cpy` |
| JCL structure | `MOVPDUP1.jcl` |
| Ghost node registry | `knowledge/ghost-nodes.md` |
| Routing map | `knowledge/routing-map.md` |
| MEM contribution examples | `knowledge/MEM/contributions/` |

Informed by Anthropic's COBOL modernization guidance:
https://claude.com/blog/how-ai-helps-break-cost-barrier-cobol-modernization
and the Code Modernization Playbook:
https://resources.anthropic.com/code-modernization-playbook

Key principle adopted: implicit dependencies — shared data structures, file-based coupling, initialization sequences — are the primary source of modernization risk and do not appear in static call-graph analysis.
