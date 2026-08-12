# Shared Knowledge Register Format

This is the single source of truth for how all knowledge-extraction skills emit findings. Three skills reference it: `cobol-knowledge-extractor`, `document-knowledge-extractor`, and `knowledge-reconciler`. It is defined once here so the format cannot drift between skills — if it drifts, the reconciler breaks.

Every extraction skill emits findings as a Knowledge Register: a list of findings in one identical shape, regardless of whether the source was COBOL code or a document. This shared shape is what lets the reconciler compare a code-derived register against a doc-derived register precisely, rather than fuzzily matching prose.

## Finding schema

Every finding has exactly these fields:

- **id** — {SOURCE}-{nnn}. SOURCE is COBOL, DOC, or RECON. e.g. COBOL-001, DOC-014, RECON-003.
- **statement** — the knowledge in plain business or system language. No COBOL, no jargon beyond standard payer domain terms. One or two sentences.
- **rationale** — inferred reason this rule/fact exists. Aggressive inference is allowed and encouraged here.
- **confidence** — LIKELY | PLAUSIBLE | SPECULATIVE. How sure the skill is that its interpretation of the source is correct.
- **materiality** — MATERIAL | NOTABLE | INCIDENTAL. MATERIAL = affects money, compliance, or migration risk. NOTABLE = affects correctness, bounded impact. INCIDENTAL = real but low stakes.
- **proposed_layer** — L1 | L2 | L3 | L4 | L5 | L6 | SPANS | UNCLEAR. The knowledge layer this finding most likely belongs to. See layer guide below.
- **layer_confidence** — LIKELY | PLAUSIBLE | SPECULATIVE. Separate from confidence: how sure the skill is about the LAYER assignment, which is a distinct judgment from how sure it is about the finding itself.
- **source_citation** — where this came from. For code: program + paragraph + line range. For docs: document name + section/heading. Precise enough for an SME to go straight to it.
- **maps_to** — existing knowledge node this relates to (L2/L5 file or concept), or "no known mapping — candidate ghost node".
- **sme_question** — a specific confirm question phrased as a question, never as an assertion. "CONFIRM: is 180 days the timely filing limit for this claim type?"

## Layer assignment guide

Assign proposed_layer by what the knowledge IS, not where it was found. A single source emits knowledge at many layers simultaneously. Reference `knowledge/routing-map.md` and the existing L2–L6 file definitions.

- **L1 Enterprise** — org-level context, transformation mandate, stakeholder structure. Rare from code.
- **L2 Domain** — business/domain truth that holds regardless of any specific program. "Medicaid is payer of last resort." "MA claims require CMS encounter data."
- **L3 Systems** — system landscape: what systems exist, what files/queues/tables, how they connect, batch flow. "MEDIRTR0 reads the edited claim file and writes three platform queues."
- **L4 Application** — program-level detail: what a specific program does, its paragraphs, its position in the processing flow, what it calls.
- **L5 Business Rules** — specific decision rules the system enforces. "Route to MiFCT when CMS prefix is H/R/S/E/N." "Deny claims with member status not A or L."
- **L6 Task Intelligence** — operational reality, defect patterns, known incidents, tribal knowledge. "The default-to-commercial path is commented as impossible but increments a counter — it occurs in production."

- **SPANS** — genuinely belongs to more than one layer. State the primary and secondary: "primary L5, secondary L2". Do not force a single choice when it distorts.
- **UNCLEAR** — does not fit the current layer model. This is a valuable signal — it stress-tests the taxonomy. Flag for SME and note it may be a candidate for a new node type.

## Register output structure

Every skill's register output has two views of the same findings:

### View 1 — Layer coverage summary (lead with this)

A count of findings by proposed layer: "L2: 3 · L3: 4 · L4: 6 · L5: 12 · L6: 2 · SPANS: 1 · UNCLEAR: 1" — plus a one-line read on where this source's knowledge concentrates and what that implies about it.

### View 2 — Findings grouped by layer

The findings themselves, grouped under L2 / L3 / L4 / L5 / L6 / SPANS / UNCLEAR headings, materiality-ranked within each group (MATERIAL first). This is how the SME sees them organized the way they will enter the brain.

## Confidence vocabulary — used identically everywhere

- LIKELY — strong evidence, would be surprised if wrong
- PLAUSIBLE — reasonable inference, genuinely uncertain
- SPECULATIVE — a useful guess worth surfacing, low certainty, explicitly flagged as such

Never suppress a SPECULATIVE finding out of caution; never dress one as LIKELY. The SME decides truth.
