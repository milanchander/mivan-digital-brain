---
name: cobol-code-reviewer
description: Provide a MiCPS COBOL program and say "review this", "code review", or "check this COBOL" to get a structured review report covering AC alignment, MiCPS coding standards, DB2 best practices, VSAM practices, performance, batch processing, maintainability, and migration readiness.
---

# COBOL Code Reviewer

## Trigger

Activate when a developer provides COBOL code and says **"review this"**, **"code review"**, or **"check this COBOL"**.

---

## Purpose

Perform a structured code review of a MiCPS COBOL program against Mivan's coding standards, IBM Enterprise COBOL 6.x best practices, mainframe performance guidelines, and acceptance criteria alignment. Produces a structured review report the developer and James Whitfield can act on.

---

## Input Contract

| Input | Required | Effect on review |
|---|---|---|
| COBOL program | Yes | All dimensions |
| Jira story | Optional | Enables Dimension 1 (AC alignment) |
| COPYBOOKs | Optional | Enables full Dimension 2 and 5 (COPY statement and record layout checks) |
| JCL that invokes it | Optional | Enables Dimension 6 (batch processing and job stream checks) |

If only the COBOL program is provided, Dimensions 2–8 are performed. Dimensions 1 and partial 6 are skipped with a note.

---

## Review Dimensions

---

### Dimension 1 — Acceptance Criteria Alignment

*Requires: Jira story*

For each numbered AC in the story:

1. **Implementation check** — Is there a 3000-level (or equivalent) paragraph implementing this criterion? Cite the paragraph name.
2. **Test check** — Is there a ZUnit test case in `[PROGNAME]T.cbl` that validates this AC? Cite the test case name.
3. **Rating per AC:**
   - `PASS` — implemented in a named paragraph and tested in ZUnit
   - `PARTIAL` — paragraph exists but no test, or test exists but implementation is incomplete
   - `FAIL` — no paragraph found and/or no test found

Flag any AC rated PARTIAL or FAIL as a **Critical** or **High** issue depending on whether it is a core business rule.

---

### Dimension 2 — MiCPS Coding Standards

| Check | Severity | Rule |
|---|---|---|
| `PROGRAM-ID` is ≤8 characters, uppercase | CRITICAL | IBM limit; longer names cause compile errors |
| Fixed format respected — all code in columns 7–72 | CRITICAL | Columns 1–6 for sequence, 7 for indicator, 73–80 ignored |
| No inline literals for business values | HIGH | All thresholds, reason codes, and status values in WORKING-STORAGE with `VALUE` and AC comment |
| `COPY` statements used for all DB2 record layouts and VSAM FDs | HIGH | No inline redefinition of layouts that exist in COPYBOOKs |
| Paragraph naming follows hierarchy convention | MEDIUM | `0000-MAIN`, `1000-INIT`, `2000-PROCESS`, `3000-*`, `4000-*`, `9000-FINALIZE`, `9999-ABEND` |
| `SQLCODE` checked after every `EXEC SQL` statement | CRITICAL | Every DB2 statement must be followed by `IF SQLCODE NOT = ZERO` or equivalent |
| Checkpoint logic present (every 5,000–10,000 records) | HIGH | `DISPLAY` checkpoint message with record count in main processing loop |
| `9999-ABEND` paragraph present and reachable | HIGH | Must set `RC=16`, display error message, and `STOP RUN` |
| Summary counts written to SYSOUT in `9000-FINALIZE` | MEDIUM | Read, write, skip, error counts — ops team needs these |
| `COMPUTE` used for complex arithmetic | MEDIUM | Not chained `ADD`/`SUBTRACT` statements |
| `EVALUATE` used for multi-way conditions | MEDIUM | Nested `IF` deeper than 3 levels is a flag |

---

### Dimension 3 — DB2 Best Practices

| Check | Severity | Rule |
|---|---|---|
| Cursor declared before PROCEDURE DIVISION | CRITICAL | `EXEC SQL DECLARE cursor CURSOR FOR … END-EXEC` in WORKING-STORAGE |
| Cursor opened in `1000-INIT` | HIGH | Not inline in the processing loop |
| Cursor closed in `9000-FINALIZE` | HIGH | Resource leak if not closed |
| `SQLCODE +100` handled on every FETCH | CRITICAL | End-of-cursor must set EOF flag and exit loop cleanly |
| `SQLCODE -811` handled on single-row SELECT | HIGH | More-than-one-row error must route to `9999-ABEND` or recovery |
| No `SELECT *` — explicit column list | HIGH | Column order in DB2 can change; explicit list is required |
| Static SQL only — no dynamic SQL (`EXECUTE IMMEDIATE`) | HIGH | Performance and security — dynamic SQL prohibited in MiCPS batch |
| Host variables match column data types exactly | CRITICAL | Type mismatch causes SQLCA errors at runtime |
| `EXEC SQL INCLUDE SQLCA END-EXEC` present | CRITICAL | SQLCA required for SQLCODE access |
| `EXEC SQL DECLARE TABLE` present for each table | MEDIUM | Documents the schema version in use at compile time |

---

### Dimension 4 — VSAM Best Practices

| Check | Severity | Rule |
|---|---|---|
| `FILE STATUS` defined for each VSAM file | HIGH | `SELECT … FILE STATUS IS WS-[FILE]-STATUS` |
| `FILE STATUS` checked after every I/O verb | HIGH | `OPEN`, `READ`, `WRITE`, `REWRITE`, `DELETE`, `CLOSE` |
| Files opened in `1000-INIT` | MEDIUM | Not inline on first use |
| Files closed in `9000-FINALIZE` | HIGH | Resource leak if not closed; also prevents data loss on WRITE |
| `INVALID KEY` clause on keyed READ | CRITICAL | Required for KSDS; absent causes runtime error |
| `AT END` clause on sequential READ | CRITICAL | Required for ESDS and KSDS sequential; absent causes runtime error |
| `NOT INVALID KEY` used for success path | MEDIUM | Cleaner than `IF WS-STATUS = '00'` after INVALID KEY |

---

### Dimension 5 — Performance

| Check | Severity | Rule |
|---|---|---|
| No table scans — indexed cursor access only | HIGH | `WHERE` clause must use indexed column(s); full-table scan is a performance incident |
| `COMP-3` for all packed-decimal monetary fields | MEDIUM | `PIC S9(7)V99 COMP-3` — not `PIC S9(7)V99` (display) |
| `COMP` for binary counters and index fields | MEDIUM | `PIC S9(4) COMP` — not display format for counters |
| `OCCURS … INDEXED BY` for large tables | MEDIUM | Internal index is faster than a subscript variable |
| Unnecessary `MOVE` statements | LOW | Particularly redundant moves between fields of the same value |
| `STRING`/`UNSTRING` used appropriately | LOW | Preferred over manual character-by-character manipulation |

---

### Dimension 6 — Batch Processing

*Full assessment requires JCL.*

| Check | Severity | Rule |
|---|---|---|
| Checkpoint frequency appropriate (5,000–10,000 records) | HIGH | Too infrequent risks long restart window; too frequent adds overhead |
| Return code set correctly | HIGH | `RC=0` success, `RC=4` warnings, `RC=8` errors, `RC=16` abend |
| SYSOUT messages meaningful for ops team | MEDIUM | Include job step name, record counts, and error descriptions |
| Restart/recovery logic documented in comment | MEDIUM | How to restart after abend; which DB2 tables need cleanup |
| JCL `COND` code on dependent steps | HIGH | Step skips correctly if a prerequisite step fails |
| `STEPLIB` points to correct load library | HIGH | `MIVANCPS.LOADLIB` |
| DD statements match `FILE-CONTROL` entries | CRITICAL | Missing DD causes JCL error (IEF285I) |

---

### Dimension 7 — Maintainability

| Check | Severity | Rule |
|---|---|---|
| Paragraph comments explain business purpose | HIGH | Every 3000-level paragraph needs a `*` comment block explaining what it does and which AC it implements |
| AC number cited in inline comments | HIGH | `* AC-1: flag if charge variance within 10%` before the relevant logic |
| No dead code (unreachable paragraphs) | MEDIUM | Paragraphs not called from any `PERFORM` |
| No duplicated logic across paragraphs | MEDIUM | Same condition tested twice with the same code — extract to a shared paragraph |
| `COPY` members used instead of duplicated record layouts | HIGH | If the same field layout appears in two programs, it belongs in a COPYBOOK |
| Paragraph length reasonable | LOW | Paragraphs longer than ~50 lines are candidates to split |

---

### Dimension 8 — Migration Readiness

*Assessed for all programs; rated regardless of migration plan.*

| Check | Rating Component | Question |
|---|---|---|
| Business rules isolated | Yes / No | Are all business rules in dedicated 3000-level paragraphs, or are they embedded inline in 2000-PROCESS? |
| Hardcoded values documented | Yes / No | Are all WORKING-STORAGE constants commented with their purpose and AC reference? |
| VSAM layouts in COPYBOOKs | Yes / No | Are all VSAM record layouts in `.cpy` files, or inline in the FD? |
| DB2 cursor logic self-contained | Yes / No | Is each cursor declared, opened, fetched, and closed in clearly bounded paragraphs? |
| No CICS-specific verbs | Yes / No | Programs with `EXEC CICS` require separate migration analysis |

**Migration readiness rating:**
- `Ready` — all five Yes
- `Needs Preparation` — 3–4 Yes; minor refactoring before migration
- `Not Ready` — fewer than 3 Yes; significant restructuring required before the COBOL to Java Migrator skill can be applied effectively

---

## Output Format

Every finding must cite the paragraph name and approximate line number where the issue occurs. Do not generalise — be specific.

```
## COBOL Code Review — [PROGRAM-ID] — [IssueKey or "no story provided"]
**Reviewer:** Mivan Digital Brain
**Standard:** IBM Enterprise COBOL 6.x / MiCPS Batch Standards
**Date:** [today]
**Dimensions assessed:** [list which dimensions ran]
**Overall verdict:** APPROVED / APPROVED WITH COMMENTS / CHANGES REQUIRED

---

### Critical Issues (must fix before promote to TEST)
[CRITICAL-1] [Dimension] — paragraph [NAME] line ~[N]
  Issue: [specific description]
  Rule: [which standard was violated]
  Fix: [specific change required]

[none — all critical checks passed] if applicable

---

### High Priority Issues (fix before promote to TEST)
[HIGH-1] …

---

### Medium Priority Issues (fix in follow-up)
[MEDIUM-1] …

---

### Low Priority / Suggestions
[LOW-1] …

---

### Acceptance Criteria Coverage
[Omitted — no Jira story provided] OR:

| AC | Description | Paragraph | ZUnit Test Case | Status |
|---|---|---|---|---|
| AC-1 | [text] | 3000-[NAME] | TC-01-[NAME] | PASS |
| AC-2 | [text] | 3000-[NAME] | None found | PARTIAL |

---

### DB2 Safety Check

| EXEC SQL Statement | Location | SQLCODE Handled | Status |
|---|---|---|---|
| OPEN [cursor] | 1000-INIT line ~[N] | N/A | OK |
| FETCH [cursor] | 2000-PROCESS line ~[N] | +100 ✓, others? | OK / FLAG |
| INSERT INTO [table] | 4000-[NAME] line ~[N] | 0 only | FLAG |

---

### Migration Readiness
**Rating:** [Ready / Needs Preparation / Not Ready]

| Check | Status |
|---|---|
| Business rules in dedicated paragraphs | Yes / No |
| Hardcoded values documented | Yes / No |
| VSAM layouts in COPYBOOKs | Yes / No |
| DB2 cursor logic self-contained | Yes / No |
| No CICS-specific verbs | Yes / No |

Notes: [what needs to be done before COBOL to Java Migrator skill can be applied]

---

### Positive Observations
- [specific thing done well — cite paragraph or pattern]
- [another positive — always include at least one]

---

### Summary
[2–3 sentences: overall quality, most important action, whether ready to promote.]

*Reviewed by Mivan Digital Brain — for James Whitfield sign-off*
```

---

## Severity Definitions

| Severity | Meaning | Promote impact |
|---|---|---|
| CRITICAL | Compile error, runtime abend risk, or data integrity risk | Blocks promote to TEST |
| HIGH | Violates a core standard; likely causes incidents or makes migration harder | Fix before promote to TEST |
| MEDIUM | Reduces maintainability or ops visibility | Fix in follow-up ticket |
| LOW | Style or minor improvement | Developer's discretion |

**Overall verdict logic:**
- Any CRITICAL finding → `CHANGES REQUIRED`
- Two or more HIGH findings → `CHANGES REQUIRED`
- One HIGH or any MEDIUM findings → `APPROVED WITH COMMENTS`
- No findings above LOW → `APPROVED`

---

## Reference Implementations

When assessing whether code meets standards, compare against these files:

| Role | File |
|---|---|
| Gold standard program | `MOVPDUP1.cbl` |
| Gold standard ZUnit tests | `MOVPDUP1T.cbl` |
| DB2 copybook pattern | `CLMPAYRC.cpy` |
| Working storage copybook | `MOVPDUP1.cpy` |
| JCL structure | `MOVPDUP1.jcl` |
| DB2 DDL pattern | `NEAR_DUP_QUEUE.sql` |
