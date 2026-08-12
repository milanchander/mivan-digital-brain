---
name: document-knowledge-extractor
description: Provide a text-based structured document (design spec, runbook, Confluence/wiki export, markdown, design/architecture doc) and ask to "extract knowledge" from it to produce a Knowledge Register in the shared format (skills/shared/knowledge-register-format.md), written to MEM for human review. The document counterpart to the COBOL Knowledge Extractor.
---

# Document Knowledge Extractor

## Trigger

Activate when a developer provides a **text-based structured document** — a design spec, runbook, Confluence/wiki export, markdown file, or design/architecture doc — and asks to **"extract knowledge"**, **"document this"**, or **"what does this doc tell us"**.

---

## Purpose

Read a text document about a Mivan system or process and extract structured knowledge as a **Knowledge Register**, in the exact shared format defined in `skills/shared/knowledge-register-format.md`. Output goes to MEM for human review.

This is the **document counterpart** to the COBOL Knowledge Extractor. It emits the identical register format so the Knowledge Reconciler can compare the two — a doc-derived register against a code-derived register — precisely, not fuzzily. The shared format is the source of truth; follow it exactly and do not let this skill's output drift from it.

---

## Scope — text-based structured documents only

**IN SCOPE:** specs, runbooks, design docs, architecture docs, markdown, Confluence/wiki text exports, plain text procedures.

**OUT OF SCOPE (flag, do not silently fail):** documents that are primarily diagrams, screenshots, scanned images, or spreadsheets/tables-as-data. If the document's meaning lives in images or complex tables the skill cannot read reliably, **STATE that clearly**, extract what text it can, and flag the rest as *"content not extractable from text — requires manual review or a different tool."* Never hallucinate around an image you cannot see.

---

## Method

### Step 1 — Document triage

State: document type, apparent age / last-updated if present, structure (sections/headings), and whether any content is out of scope per above. Documentation is often stale — note any signals of age (dated headers, superseded system names, "as of" statements, old version numbers).

### Step 2 — Extract knowledge into the shared register

Walk the document and extract every business rule, system fact, process step, and domain statement into the shared register format. Follow the shared schema exactly: `id` prefix **DOC**, all fields, layer tagging, confidence, materiality, SME questions.

Apply the same **aggressive-but-labeled inference** discipline as the COBOL extractor: offer business meaning, label confidence, phrase as SME questions. An uncertain but useful reading, clearly labeled PLAUSIBLE or SPECULATIVE, is more valuable than silence.

### Step 3 — Epistemic discipline specific to documents

Documents assert **intent**; they are not proof of **behavior**. A document says what someone INTENDED or BELIEVED the system does. It is **not evidence of what the system actually does**. Mark every finding's `source_citation` to the document section, and treat all document-derived knowledge as **claims to be confirmed** — by an SME, or by reconciliation against code.

Watch specifically for, and flag each where found:
- **Stale content** — describes a system state that may no longer hold.
- **Aspirational content** — describes intended behavior that may never have been built.
- **Ambiguity** — vague statements that cannot be pinned to a specific rule.

---

## Output

Write to `knowledge/MEM/contributions/DOCEXTRACT-{doc-slug}-{YYYY-MM-DD}.md` (never overwrite an existing file; append `-2`, `-3`, … if the name is taken).

Frontmatter per the shared format plus:

```yaml
source: document-extraction
source_document: {name}
document_type: {spec | runbook | design | wiki | other}
out_of_scope_content: {none | description}
status: draft
validated_by: PENDING HUMAN REVIEW
```

Body: the shared register — **layer coverage summary first (View 1)**, then **findings grouped by layer (View 2)**, materiality-ranked within each group. See `skills/shared/knowledge-register-format.md` for both views.

---

## Do not

- Do not write to formal layers. **MEM only.**
- Do not read images or infer their content.
- Do not present document claims as verified facts.
- Do not update `ghost-nodes.md` — recommend only.

---

## Reference

- Shared format: `skills/shared/knowledge-register-format.md`
- Counterpart skill: `skills/cobol-knowledge-extractor.md`
