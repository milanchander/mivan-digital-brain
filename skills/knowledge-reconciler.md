---
name: knowledge-reconciler
description: Provide a COBOL program AND one or more documents for the same system/program (or two already-produced Knowledge Registers) and ask to reconcile them. Diffs a code-derived register against a doc-derived register to surface where they agree, conflict, or each hold unique knowledge, and produces a single reconciled MEM entry — code wins on behavior, SME adjudicates intent.
---

# Knowledge Reconciler

## Trigger

Activate when a developer provides a **COBOL program AND one or more documents** for the same system/program and asks to **"reconcile"** them, or provides **two already-produced Knowledge Registers** to compare.

---

## Purpose

Orchestrate the COBOL and Document extractors, then **diff their registers** to surface where code and documentation agree, conflict, or each hold unique knowledge. Produce a single **reconciled knowledge entry** in MEM that borrows from both and resolves conflicts in favor of observed behavior.

---

## Dependencies

This skill composes two others:
- `skills/cobol-knowledge-extractor.md`
- `skills/document-knowledge-extractor.md`

Both emit the shared register: `skills/shared/knowledge-register-format.md`.

If given **raw inputs** (a program and a doc), run each extractor first to produce the two registers. If given **two existing registers**, skip to reconciliation.

---

## Governing principle

When code and documentation disagree, the **CODE is authoritative for what the system DOES**. The documentation is evidence of what it was **INTENDED** to do. Never resolve a conflict by trusting the document. Surface it; code wins on behavior; SME adjudicates intent.

---

## Method

### Step 1 — Obtain both registers

Produce or ingest the COBOL register and the Document register. Confirm both are in the shared format (`id` prefixes `COBOL` and `DOC`, full field set, layer tags).

### Step 2 — Match findings across registers

Match code findings to doc findings that concern the same rule/fact. **Matching is by meaning, not by id.** Because both registers use the shared schema and layer tags, match **within the same `proposed_layer` first, then across layers**. A code L5 rule and a doc L5 rule about the same decision are a match candidate.

### Step 3 — Classify every matched and unmatched finding

- **CONFIRMED** — code and doc agree. Confidence rises. Report briefly, cite both.
- **CONTRADICTED** — code and doc disagree. **HIGHEST VALUE.** State what code does (cited to lines), what doc claims (cited to section), that code is authoritative for behavior, and the likely explanation (stale doc / unbuilt intent / different version / code defect). SME question for each.
- **CODE-ONLY** — in code, absent from docs. Undocumented behavior / tribal knowledge surfaced.
- **DOC-ONLY** — in docs, absent from code. Intended-but-unbuilt, lives elsewhere, or doc describes a system that no longer matches reality.

### Step 4 — Produce the reconciled entry

A **THIRD artifact**, neither source alone. It uses the document's business language and context WHERE confirmed by code, corrects the documentation WHERE code contradicts it, and marks the **provenance of every element** (code / doc / both) and every divergence. Preserve layer tags through reconciliation.

---

## Output

Write to `knowledge/MEM/contributions/RECON-{subject}-{YYYY-MM-DD}.md` (never overwrite an existing file; append `-2`, `-3`, … if the name is taken).

Frontmatter per the shared format plus:

```yaml
source: reconciliation
sources_reconciled: {program + documents}
facts_confirmed: {count}
facts_contradicted: {count}
code_only_findings: {count}
doc_only_findings: {count}
reconciliation_note: {one line on overall doc accuracy}
status: draft
validated_by: PENDING HUMAN REVIEW
```

Body order:
1. **Layer coverage summary** (reconciled, across L2–L6).
2. **Code vs Documentation Reconciliation** — lead with CONTRADICTED, then CODE-ONLY, then DOC-ONLY, then a brief CONFIRMED list.
3. **The reconciled knowledge entry**, grouped by layer, provenance marked on each element.

---

## Value framing

Every payer has documentation everyone knows is partly wrong but nobody knows which parts. This skill's core output is telling them **exactly which documented rules the code contradicts** — a knowledge-governance capability, not just extraction. Frame the `reconciliation_note` to answer: **how much can this documentation be trusted?**

---

## Do not

- MEM only, never formal layers.
- Never trust doc over code on behavior.
- Do not update `ghost-nodes.md` — recommend only.

---

## Reference

- Shared format: `skills/shared/knowledge-register-format.md`
- Composed skills: `skills/cobol-knowledge-extractor.md`, `skills/document-knowledge-extractor.md`
