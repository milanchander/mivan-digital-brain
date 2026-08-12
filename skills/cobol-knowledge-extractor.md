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

## Operating Constraints — read before extracting

This skill extracts from ONE program at a time and does NOT have the called subprograms or, unless supplied, the copybooks. It must never pretend otherwise.

Two hard truths this skill is built around:

1. A 30–50K line program does not fit in one context window. Extraction MUST be multi-pass. A single-pass read of a program this size will truncate silently and produce confident, incomplete output. That is the worst possible failure. Never do it.

2. The most valuable output of a single-program extraction is the precise boundary of what could NOT be determined — the called programs not supplied, the copybooks missing, the dynamic behavior invisible to static reading. At a real client, that boundary statement tells the migration team what else to pull. Treat it as a primary deliverable, not a disclaimer.

---

## Technical register vs Business register

This skill produces knowledge at two altitudes, kept visibly separate and never blended:

**TECHNICAL REGISTER (existing)** — for the developer rebuilding the program. Precise, cited, OBSERVABLE or INFERRED. *"3400-EDIT-ELIG lines 2210–2265 rejects WS-MBR-STATUS not in ('A','L')."*

**BUSINESS REGISTER (new)** — for the SME confirming that the rules are correct. Plain business language, no COBOL. *"Mivan pays claims only for members who are Active or on approved Leave. All other statuses are denied."* It is emitted in the **shared Knowledge Register format** (`skills/shared/knowledge-register-format.md`), id prefix `COBOL`, with per-finding layer tags — so the Knowledge Reconciler can compare it against a document-derived register.

Same underlying fact, different altitude. The business register is permitted to make AGGRESSIVE inferences about business meaning BECAUSE every business finding is routed to an SME as a question to confirm, never presented as established fact. The aggression is in generating candidate rules; the discipline is in presenting them as hypotheses for review.

The two registers must never contaminate each other. The technical register keeps its cautious OBSERVABLE/INFERRED discipline unchanged. The business register is a separate, clearly labeled interpretive layer.

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

## STEP 0.5 — CLASSIFY PROGRAM TYPE

Before extraction, classify the program. The type changes how to read it and what to expect. Detect and declare the type from these signals:

- **BATCH DRIVER** — sequential file I/O, `PERFORM UNTIL end-of-file`, no CICS. Control flow is linear. Read normally.
- **CICS ONLINE** — `EXEC CICS` verbs, `DFHCOMMAREA`, `EIBCALEN` checks, `RETURN TRANSID`. Pseudo-conversational. **WARNING: control flow is NOT linear.** State is held across invocations — the same paragraph runs differently on first vs subsequent invocations based on commarea state. Do not read it as a batch program.
- **CICS-DB2 HYBRID** — CICS plus `EXEC SQL`. Real-time inquiry or update; couples two external systems.
- **CALLED SUBPROGRAM** — has a `LINKAGE SECTION` and `PROCEDURE DIVISION USING`. Its behavior only makes sense relative to its caller's contract, which is NOT available. Extract the contract (what it expects in, what it returns) and flag that intent depends on the caller.
- **REPORT WRITER / FORMATTER** — heavy DATA DIVISION, `WRITE` to print files, little branching. LOW business-rule density — say so, and do not manufacture findings.
- **EDIT / VALIDATION** — dense 88-levels and `EVALUATE` over business fields. HIGHEST business-rule density. This is where aggressive business extraction (Pass 4) pays off most.
- **FILE CONVERSION / BRIDGE** — reads one layout, writes another. The mapping between the two layouts IS the knowledge.

State the type, the confidence, and how it shapes the extraction approach for this program. If the program is a hybrid or does not fit cleanly, say so.

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

## STEP 2 — MULTI-PASS EXTRACTION FOR LARGE PROGRAMS

Real production programs (30–50K lines) cannot be read in one pass. Extract in passes; each pass has a narrow job and hands a spine to the next. This orchestrates STEP 3 (business logic) and STEP 3B (risk) — it does not replace their discipline.

### Pass 0 — Size and triage

Determine program size (line count) and structure cheaply before deep reading:
- Total lines; DATA DIVISION vs PROCEDURE DIVISION split
- Count of paragraphs/sections
- Count of CALLs (static and dynamic)
- Count of COPY statements
- Count of EXEC CICS / EXEC SQL / EXEC MQ blocks

State the triage result and the extraction plan. If the program exceeds what one pass can reliably hold, say so explicitly and proceed in sections.

### Pass 1 — Structural map (cheap, whole-program)

Read only the DATA DIVISION and the paragraph/section headers plus PERFORM/CALL/GOTO statements. Do NOT yet extract business logic. Produce:
- The paragraph inventory and PERFORM call graph
- The CALL inventory — every called program, marked STATIC (literal) or DYNAMIC (via data name)
- For DYNAMIC calls: the variable that holds the target, and every place it is set, if determinable. If the target cannot be resolved from source, that is a finding, not a gap to skip.
- COPY inventory — every copybook, whether supplied
- File and DB2 and CICS resource inventory

This map is the spine. Everything else hangs off it.

#### Dependency inventory (OBSERVABLE) — the substance of the spine

These are explicit in the source and are stated as fact. Enumerate:

- **Called programs** — every `CALL 'PROGNAME'` (static) and `CALL identifier` (dynamic — note dynamic calls cannot be fully resolved from source)
- **DB2 access** — every `EXEC SQL` cursor (`DECLARE`, `OPEN`, `FETCH`, `CLOSE`), single-row `SELECT`, `INSERT`/`UPDATE`/`DELETE`, and the tables each touches
- **COPYBOOKs** — every `COPY` member and what it supplies (record layout, working storage, SQLCA)
- **VSAM/sequential files** — every `SELECT … ASSIGN`, its organization (KSDS/ESDS/RRDS/sequential), and its access mode (READ/WRITE/REWRITE/DELETE)
- **JCL coupling** *(requires JCL)* — DD statements, datasets, and the job step's position in the stream

Present these as a dependency table with columns: Dependency, Type, Direction (calls / called-by / reads / writes), Evidence (paragraph + approx line).

#### Implicit dependencies — highest migration risk

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

### Pass 2 — Sectioned deep extraction

Using the Pass 1 map, extract business logic in coherent sections (by paragraph range or functional block), not in arbitrary line chunks. For each section carry the OBSERVABLE/INFERRED discipline of STEP 3 and cite program name plus line range for every finding.

Track which sections have been extracted so nothing is silently skipped. If a section is too large or too tangled to extract confidently, say so and mark it NOT FULLY EXTRACTED rather than summarizing loosely.

### Pass 3 — Synthesis and boundary statement

Consolidate. Produce the findings (ranked by materiality), the risk assessment (STEP 3B), the MEM output (STEP 4), and — critically — the boundary statement (the Knowledge Boundary section).

### Pass 4 — Business knowledge extraction

Using the technical findings as source material, translate them into business meaning. Do NOT re-read the program from scratch — work from what the technical passes already established, so every business rule is traceable back to a cited technical finding. This pass produces the **business register** (see "Technical register vs Business register"); it must not alter any technical finding's OBSERVABLE/INFERRED classification.

Systematically mine these COBOL constructs for business meaning — in payer COBOL these are where the rules live:

- **88-level condition names → business vocabulary.** A condition name like `ELIGIBLE-MEMBER` or `DENY-DUPLICATE` is a business term the program's authors chose. Capture it as domain vocabulary.
- **EVALUATE / nested IF over business fields → decision rules.** Translate the branch logic into "when X, the business does Y."
- **Hardcoded literals in business conditions → candidate business parameters.** A literal compared against a date, amount, count, or code is almost always a business rule with a real-world meaning. Infer that meaning aggressively.
- **Date arithmetic against literals → candidate regulatory or contractual deadlines** (timely filing, look-back periods, effective dating).
- **Reject / deny / suspend paths → the program's business rules** about what it will not pay and why.
- **Computed fields → the business calculations** (cost share, allowed amount, coordination).
- **Table lookups → the reference data the business depends on.**

Emit each finding in the **shared Knowledge Register format** — the single source of truth is `skills/shared/knowledge-register-format.md`; follow it exactly so the Knowledge Reconciler can diff this register against the Document Extractor's. Use id prefix **COBOL** (`COBOL-001`, `COBOL-002`, …). For EACH finding produce every shared field:
- **statement** — the rule/fact in plain business or system language, no COBOL (one or two sentences)
- **rationale** — your AGGRESSIVE inference of WHY it exists (the useful part)
- **confidence** — LIKELY / PLAUSIBLE / SPECULATIVE (how sure you are your interpretation of the source is correct)
- **materiality** — MATERIAL / NOTABLE / INCIDENTAL
- **proposed_layer** — L1 | L2 | L3 | L4 | L5 | L6 | SPANS | UNCLEAR. Tag by what the knowledge IS, not that it came from code. A single program emits knowledge across L2–L6: a domain truth is L2, a system/file/flow fact is L3, program-level detail is L4, a specific decision rule is L5, an operational/tribal-knowledge reality is L6. Use the layer guide in the shared format.
- **layer_confidence** — LIKELY / PLAUSIBLE / SPECULATIVE (a distinct judgment from `confidence`)
- **source_citation** — program + paragraph + line range
- **maps_to** — existing L2/L5 node or concept, or "no known mapping — candidate ghost node" (check L2 and L5)
- **sme_question** — a specific confirm question phrased as a question, never as an assertion

Lead the register output with the **layer coverage summary (View 1)**, then the findings grouped by layer (View 2), materiality-ranked (MATERIAL first) within each group — exactly as the shared format prescribes.

Be aggressive in offering business meaning. A hardcoded `180` in a date comparison should produce: *"PLAUSIBLE: appears to enforce a 180-day timely filing window. Commercial timely filing commonly ranges 90–365 days. CONFIRM: is 180 days Mivan's timely filing limit for this claim type, and which contract or regulation sets it?"* — not *"180-day threshold, meaning undetermined."*

The cost of an aggressive wrong guess is one SME correction. The cost of timidity is an SME's expertise wasted on rules the skill could have proposed. Lean aggressive.

---

## Copybook and record-layout hazards

Real payer copybooks are where meaning hides and where extraction most often goes wrong. Handle explicitly:

- REDEFINES: the same bytes reinterpreted multiple ways. Record every REDEFINES and the condition (usually a record-type or claim-type field) that selects which view applies. If the selecting condition is not determinable, flag it — misreading a REDEFINES means misreading the record entirely.
- OCCURS DEPENDING ON: variable-length tables. Record the controlling field and note the layout is variable.
- Deep nesting and level-88 condition names: capture the business meaning encoded in 88-levels — they are often the clearest statement of business rules in the whole program.
- If a copybook is NOT supplied: do not infer its layout from field usage. State which copybook is missing, which fields from it are referenced, and that the layout is undetermined. A guessed record layout is dangerous.

---

## What static reading cannot determine

Mandatory analysis for constructs whose runtime behavior is not derivable from source. For each, record its presence and state plainly that the actual behavior requires runtime tracing or SME confirmation:

- Dynamic CALL (CALL data-name) — target not known from source
- EXEC CICS LINK / XCTL with dynamic program names
- MQ PUT/GET — external system coupling, async behavior
- GO TO and especially GO TO DEPENDING ON
- ALTER statements — if present, flag prominently; they make control flow non-deterministic from reading
- PERFORM THRU ranges — confirm the range boundaries
- State-flag-driven logic where a paragraph's behavior depends on a flag set far away

This section is not optional and is not a footnote. At scale it is often the most important finding set.

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

## Ranking findings by materiality

A large program yields hundreds of findings. An unranked list is noise. Rank every finding:

**MATERIAL** — affects money, compliance, or migration risk:
- Hardcoded values in payment, pricing, or eligibility paths
- Regulatory thresholds or date logic
- Business rules with no external specification
- Implicit dependencies and undeclared coupling
- Anything on the critical execution path

**NOTABLE** — affects correctness but bounded impact:
- Error handling gaps, edge cases, validation logic

**INCIDENTAL** — real but low stakes:
- Formatting, display, logging, dead-looking code

Lead the output with MATERIAL. An SME reading only the MATERIAL section must get the findings that matter for a migration or a payment-integrity decision. Justify each MATERIAL ranking in a few words — do not rank by how much text a finding generated.

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
program_size_lines: [count]
extraction_passes: [number]
sections_fully_extracted: [count]
sections_partial: [count]
called_programs_not_supplied: [count]
copybooks_not_supplied: [count]
unresolved_dynamic_calls: [count]
material_findings: [count]
business_rules_extracted: [count]
business_rules_material: [count]
domain_terms_captured: [count]
rules_with_no_known_mapping: [count]
sme_confirmation_required: true
---

> **This is an extraction hypothesis, not verified knowledge.** Content marked
> OBSERVABLE is deterministically derived from source. Content marked INFERRED
> requires confirmation by a subject matter expert before it can be relied upon
> for migration decisions, test design, or business rule documentation.
> Extraction accelerates SME work; it does not replace it.

# Extraction Summary — [PROGRAM-ID]

Cover BOTH registers. Technical completeness first: "Extracted [N] of [M]
sections. [K] called programs and [J] copybooks were not supplied and are listed
in the Knowledge Boundary. [P] dynamic calls could not be resolved from source."
THEN the business register (shared Knowledge Register format, id prefix COBOL):
"[B] findings for SME confirmation, [Bm] material, [Bu] with no mapping to
existing knowledge (candidate ghost nodes); layer coverage L2:[n] L3:[n] L4:[n]
L5:[n] L6:[n]." THEN 2–3 sentences on what the program is, its processing mode, and the
headline of the migration-risk assessment. State plainly what is known vs unknown.

---
## ══ BUSINESS REGISTER — for SME confirmation (plain language, interpretive) ══

*Aggressive business inference; every item is a QUESTION for the SME. This
register never alters the technical findings below and never states business
meaning as fact.*

### Business Summary
[≤200 words, plain business language — no program names, no COBOL, no jargon
beyond standard payer terms. What does this program do to a claim, in business
terms? An SME/BA should understand the program's purpose from this alone.]

## Knowledge Register — shared format (for SME confirmation)
Emitted per `skills/shared/knowledge-register-format.md`, id prefix `COBOL`. Two
views of the same findings. Feeds the Contribution Framework and is what the
Knowledge Reconciler diffs against a document-derived register: a confirmed
finding becomes a validated node at its proposed layer; a corrected one captures
the SME's correction; an unmappable one becomes a registered ghost node.

### View 1 — Layer coverage summary (lead with this)
`L2: [n] · L3: [n] · L4: [n] · L5: [n] · L6: [n] · SPANS: [n] · UNCLEAR: [n]`
[one line on where this program's knowledge concentrates and what that implies.]

### View 2 — Findings grouped by layer
[Findings grouped under L2 / L3 / L4 / L5 / L6 / SPANS / UNCLEAR headings,
materiality-ranked (MATERIAL first) within each group. One block per finding:]

#### COBOL-001 — [short label]
- **statement:** [plain business or system language, no COBOL — one or two sentences]
- **rationale:** [aggressive inference of WHY this rule/fact exists]
- **confidence:** LIKELY | PLAUSIBLE | SPECULATIVE
- **materiality:** MATERIAL | NOTABLE | INCIDENTAL
- **proposed_layer:** L2 | L3 | L4 | L5 | L6 | SPANS | UNCLEAR
- **layer_confidence:** LIKELY | PLAUSIBLE | SPECULATIVE
- **source_citation:** [program] [paragraph] lines [range]
- **maps_to:** [L2/L5 node or concept, or "no known mapping — candidate ghost node"]
- **sme_question:** [specific confirm question, phrased as a question]

## Domain Vocabulary
[Business vocabulary the program encodes — 88-level condition names, status
codes, reason/denial codes, LOB-specific terms. Often the clearest domain
glossary that exists for the program, because the authors encoded their business
language directly in condition names.]

| Term | Meaning (as encoded in the program) | Confidence | SME confirm |
|---|---|---|---|
| [ELIGIBLE-MEMBER] | [members with status 'A' or 'L'] | LIKELY | [question] |

---
## ══ TECHNICAL REGISTER — for the developer (cited, OBSERVABLE / INFERRED) ══

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
[Lead with MATERIAL findings, then NOTABLE, then INCIDENTAL (see "Ranking
findings by materiality"). Per-paragraph extraction from STEP 3, each item
tagged OBSERVABLE or INFERRED with confidence level for INFERRED items; justify
each MATERIAL item in a few words. Cite program name + line range per finding.]

## Hardcoded Values
| Value | Location (paragraph ~line) | Observable | Business rationale |
|---|---|---|---|
| [value] | [3000-NAME ~N] | Yes | OPEN QUESTION — not derivable from source |

## Migration Risk Assessment
[the STEP 3B table, overall rating, one-paragraph rationale, recommendation,
and any disagreement with the assigned L4 migration wave]

## Knowledge Boundary — what this extraction does NOT cover
[MANDATORY. Called programs referenced but not supplied (with calling paragraph +
apparent purpose = the "what to pull next" list); copybooks referenced but not
supplied; dynamic calls whose targets could not be resolved; sections marked NOT
FULLY EXTRACTED and why; REDEFINES/ODO whose selecting condition is undetermined;
any point where the extraction stopped short. See the Knowledge Boundary section
below.]

## Open Questions for SME
1. [question — what evidence would resolve it]
2. …

## Suggested Shadow Mode Test Scenarios
[section below]

## Extraction Self-Assessment
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

## Knowledge Boundary — what this extraction does NOT cover

Mandatory section in every extraction (include it in the MEM output). State precisely:

- Called programs referenced but not supplied — list every one, with the paragraph that calls it and what it appears to be for. This is the "what to pull next" list.
- Copybooks referenced but not supplied
- Dynamic calls whose targets could not be resolved
- Sections marked NOT FULLY EXTRACTED and why
- REDEFINES/ODO whose selecting condition is undetermined
- Any point where the extraction had to stop short

Frame this as the deliverable it is: at a real client, this list is what tells the team the true scope of the program's dependency footprint.

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

8. Bias toward "cannot be determined from source." On a large program, if the ratio of confident findings to declared unknowns is very high, that is a warning sign the extraction is overreaching, not a sign of success. A thorough extraction of a complex program surfaces MORE unknowns, not fewer.

9. Never let volume create false confidence. Extracting 400 OBSERVABLE facts about data movement does not mean the program is understood. Understanding lives in the business rules and the coupling, which are the hardest and least certain parts. Weight the summary accordingly.

10. If asked whether the program is "safe to migrate" or "fully understood," the answer is never yes from static extraction alone. State what would be required to reach that confidence: SME confirmation of INFERRED items, resolution of the boundary list, and runtime validation of dynamic behavior.

11. The business register may infer aggressively, but every business inference is a QUESTION for the SME, never a stated fact. Phrase them as "appears to / likely / CONFIRM:" — never as "Mivan does X." The SME decides what is true; the skill proposes.

12. A business rule with SPECULATIVE confidence is still worth surfacing — but it must be labeled SPECULATIVE and the SME question must acknowledge the uncertainty. Do not suppress a useful guess out of caution; do not dress a guess as certainty.

13. Never let the business register's interpretive freedom leak into the technical register. A business inference labeled LIKELY does not make the underlying technical finding anything other than what it is — OBSERVABLE or INFERRED as originally classified.

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
| Shared register format | `skills/shared/knowledge-register-format.md` |
| Companion skill (documents) | `skills/document-knowledge-extractor.md` |
| Companion skill (reconciler) | `skills/knowledge-reconciler.md` |

Informed by Anthropic's COBOL modernization guidance:
https://claude.com/blog/how-ai-helps-break-cost-barrier-cobol-modernization
and the Code Modernization Playbook:
https://resources.anthropic.com/code-modernization-playbook

Key principle adopted: implicit dependencies — shared data structures, file-based coupling, initialization sequences — are the primary source of modernization risk and do not appear in static call-graph analysis.

---

## Extraction Self-Assessment

End every extraction with an honest note on the extraction itself, so the skill can be refined over time. Include it as the final section of the MEM output:

- Program type (from STEP 0.5), and whether the skill's approach fit it
- Where the extraction was confident vs where it strained
- Any COBOL construct or pattern encountered that the skill's current guidance did not cover well
- What additional input (a specific copybook, the caller, the JCL) would most improve this extraction
- A one-line verdict: was this program type well served by the current skill, or does the skill need refinement for programs like this?

This note is the feedback loop. Patterns that recur across extractions become the next refinement to the skill itself.
