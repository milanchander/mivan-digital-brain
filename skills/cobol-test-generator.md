---
name: cobol-test-generator
description: Provide a MiCPS COBOL program and say "generate tests", "write ZUnit tests for this", or "improve test coverage" to produce a comprehensive IBM ZUnit test program covering every business rule, boundary value, DB2 error path, and migration parity scenario.
---

# COBOL Test Generator

## Trigger

Activate when a developer provides a COBOL program and says **"generate tests"**, **"write ZUnit tests for this"**, or **"improve test coverage"**.

---

## Purpose

Generate a comprehensive IBM ZUnit test program for an existing MiCPS COBOL program. Produces tests that validate every business rule, cover boundary values, and can be used for migration parity validation against a Java equivalent.

---

## Input Contract

| Input | Required | Effect on test suite |
|---|---|---|
| COBOL source program | Yes | All steps |
| Jira story | Optional | AC-aligned test cases with citation comments |
| Java equivalent service | Optional | Migration parity test cases |
| Known production defects or edge cases | Optional | Regression test cases |

The more context provided, the more complete the suite. Minimum: the COBOL program.

---

## Analysis Step — Output Before Generating Any Tests

Read the full COBOL program and produce the following. **Ask the developer to confirm before proceeding to Step 1.**

### 1. Paragraphs to Test

Focus on:
- Business logic paragraphs (3000-level) — every `IF`, `EVALUATE WHEN`, `COMPUTE`
- Output paragraphs (4000-level) — every DB2 `INSERT`/`UPDATE`, every VSAM `WRITE`/`REWRITE`
- Any paragraph containing multi-way `EVALUATE` or nested `IF` deeper than 2 levels

### 2. Business Rules Extracted

For each testable condition:
```
BR-1: [condition text from COBOL] — paragraph [NAME] line ~[N]
BR-2: …
```

### 3. DB2 Interactions to Stub

| EXEC SQL Statement | Type | SQLCODE to test |
|---|---|---|
| `OPEN cursor` | Cursor open | 0 (ok), -904 (resource unavailable) |
| `FETCH cursor` | Cursor fetch | 0 (row found), +100 (end of data) |
| `INSERT INTO` | Write | 0 (ok), -803 (duplicate key) |
| `UPDATE` | Write | 0 (ok), +100 (not found) |

### 4. VSAM Interactions to Stub

| File | Operation | File-status to test |
|---|---|---|
| [FILENAME] | READ | `00` (ok), `10` (end of file), `23` (not found) |
| [FILENAME] | WRITE | `00` (ok), `22` (duplicate key) |

### 5. Edge Cases

- Boundary values for every numeric threshold in WORKING-STORAGE
- Zero amounts and negative amounts where applicable
- Date boundary conditions (end of month, leap year if relevant)
- SQLCODE +100 (not found) — program must handle gracefully
- SQLCODE -811 (more than one row) — if single-row fetch used
- End-of-file on VSAM sequential read
- Empty cursor result set (first FETCH returns +100)

### 6. Migration Parity Scenarios (if Java provided)

Scenarios that use identical input values to the Java test suite, enabling exact output comparison:

```
PARITY-01: [input values] → expected COBOL output → expected Java output (must match)
PARITY-02: …
```

```
TEST ANALYSIS — [PROGNAME]T
═══════════════════════════════════════════════════════════
Paragraphs to test:    [list]
Business rules found:  [N]
DB2 statements:        [N] (SQLCODE paths to cover: [list])
VSAM files:            [N] (file-status paths: [list])
Edge cases identified: [N]
Migration parity:      Yes / No

Estimated test cases:  [N]
═══════════════════════════════════════════════════════════
Confirm to proceed with Step 1? (yes / adjust)
```

---

## Generation Steps

---

### Step 1 — Test Program Structure

Generate the ZUnit test program skeleton and save to `src/cobol/[PROGNAME]T.cbl`:

```cobol
      *----------------------------------------------------------------*
      * PROGRAM-ID: [PROGNAME]T                                        *
      * ZUnit test program for [PROGNAME]                              *
      * [ISSUE KEY if available]                                       *
      *                                                                *
      * TEST CASES:                                                    *
      *   TC-01: [description]                                         *
      *   TC-02: [description]                                         *
      *   …                                                            *
      *----------------------------------------------------------------*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. [PROGNAME]T.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *-- Test framework counters
       01  WS-PASS-COUNT             PIC 9(4) COMP VALUE ZERO.
       01  WS-FAIL-COUNT             PIC 9(4) COMP VALUE ZERO.
       01  WS-RETURN-CODE            PIC S9(4) COMP VALUE ZERO.

      *-- Test data constants — [PROGNAME]-specific
       01  TD-[FIELD]-VALID          PIC [type] VALUE [value].
       01  TD-[FIELD]-INVALID        PIC [type] VALUE [value].
       01  TD-[THRESHOLD]-AT         PIC [type] VALUE [threshold].
       01  TD-[THRESHOLD]-BELOW      PIC [type] VALUE [threshold - 1].
       01  TD-[THRESHOLD]-ABOVE      PIC [type] VALUE [threshold + 1].

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM TC-01-[DESC]
           PERFORM TC-02-[DESC]
           …
           PERFORM TC-SUMMARY
           STOP RUN.
```

Rules:
- All test data as named constants — no inline literals in test bodies
- `DISPLAY` of test name before each test case
- Pass/fail count updated after every test
- `TC-SUMMARY` paragraph always last

---

### Step 2 — Happy Path Tests

One test case per primary business rule:

```cobol
       TC-01-[AC-DESCRIPTION].
      *----------------------------------------------------------------*
      * TC-01: [AC text]
      *   Input:    [field] = [value]
      *   Expected: [field] = [expected-value]
      *----------------------------------------------------------------*
           DISPLAY 'TC-01: [AC description]'
      *-- Arrange: set up test input
           MOVE TD-[INPUT-VALUE] TO [WS-FIELD]
      *-- Stub: mock DB2 response
           MOVE ZERO TO SQLCODE
           MOVE TD-[MOCK-VALUE] TO [DB2-RECORD-FIELD]
      *-- Act
           CALL '[PROGNAME]'
      *-- Assert
           IF [OUTPUT-FIELD] = [EXPECTED-VALUE]
               ADD 1 TO WS-PASS-COUNT
               DISPLAY '  TC-01 PASS'
           ELSE
               ADD 1 TO WS-FAIL-COUNT
               DISPLAY '  TC-01 FAIL'
               DISPLAY '    Expected: [EXPECTED-VALUE]'
               DISPLAY '    Got:      ' [OUTPUT-FIELD]
               MOVE 8 TO WS-RETURN-CODE
           END-IF.
```

---

### Step 3 — Boundary Value Tests

For every numeric threshold in WORKING-STORAGE, generate three tests:

```cobol
       TC-[N]A-[THRESHOLD]-EXACTLY-AT.
      * Boundary: [threshold name] = [value] — at threshold (should trigger)
           DISPLAY 'TC-[N]A: [THRESHOLD] exactly at [value]'
           MOVE TD-[THRESHOLD]-AT TO [WS-FIELD]
           CALL '[PROGNAME]'
           IF [RESULT-FIELD] = [EXPECTED-AT]
               ADD 1 TO WS-PASS-COUNT
               DISPLAY '  TC-[N]A PASS'
           ELSE
               ADD 1 TO WS-FAIL-COUNT
               DISPLAY '  TC-[N]A FAIL - ' [RESULT-FIELD].

       TC-[N]B-[THRESHOLD]-JUST-BELOW.
      * Boundary: [threshold name] - 1 — just inside (should trigger)

       TC-[N]C-[THRESHOLD]-JUST-ABOVE.
      * Boundary: [threshold name] + 1 — just outside (should NOT trigger)
```

---

### Step 4 — Negative Path Tests

Cover every path that results in no action, a skip, or an error RC:

```cobol
       TC-[N]-SQLCODE-100-NOT-FOUND.
      * DB2 NOT FOUND: SQLCODE +100 on cursor FETCH
      * Program must handle gracefully (not abend)
           DISPLAY 'TC-[N]: SQLCODE +100 on first FETCH'
           MOVE +100 TO SQLCODE
           CALL '[PROGNAME]'
           IF WS-RETURN-CODE = ZERO OR 4
               ADD 1 TO WS-PASS-COUNT
               DISPLAY '  TC-[N] PASS - handled gracefully'
           ELSE
               ADD 1 TO WS-FAIL-COUNT
               DISPLAY '  TC-[N] FAIL - RC=' WS-RETURN-CODE.

       TC-[N]-EMPTY-FILE.
      * VSAM file AT END on first READ
      * Program must set WS-EOF and terminate cleanly
```

Include negative tests for:
- SQLCODE +100 (not found / end of cursor)
- SQLCODE -803 (duplicate key on INSERT)
- SQLCODE -911 (deadlock / timeout)
- VSAM file-status `23` (record not found on READ)
- VSAM file-status `10` (end of file)
- Each condition that bypasses the primary business rule (e.g. ED claim skip)

---

### Step 5 — Migration Parity Tests

Generated only when a Java equivalent is provided:

```cobol
       TC-MP-01-[PARITY-SCENARIO].
      * MIGRATION PARITY: validates identical behavior to [JavaClassName]
      * Input values match Java test: test[AC1]_[Description]
      *   Input:    [field] = [value] (same as Java test constant [JAVA_CONST])
      *   Expected: [field] = [expected] (must match Java EvaluationResult.[field])
           DISPLAY 'TC-MP-01: Parity — [scenario]'
           MOVE [TD-PARITY-VALUE] TO [WS-FIELD]
           CALL '[PROGNAME]'
           IF [RESULT-FIELD] = [EXPECTED-COBOL-VALUE]
               ADD 1 TO WS-PASS-COUNT
               DISPLAY '  TC-MP-01 PASS - matches Java expected output'
           ELSE
               ADD 1 TO WS-FAIL-COUNT
               DISPLAY '  TC-MP-01 FAIL - shadow mode discrepancy'.
```

Use exactly the same input values as the Java test constants — this makes shadow mode comparison mechanically verifiable.

---

### Step 6 — Coverage Summary

Output after all test cases are generated:

```
COVERAGE SUMMARY — [PROGNAME]T
═══════════════════════════════════════════════════════════
Test cases generated:    [N] total
  Happy path:            [N]
  Boundary values:       [N] ([M] thresholds × 3)
  Negative paths:        [N]
  DB2 error paths:       [N]
  Migration parity:      [N]

Paragraphs covered:
  ✓ [paragraph name]
  ✓ …
  ✗ [paragraph name] — not covered (recommend: [test scenario])

Business rules covered:  [N] / [total]
Known gaps:              [list any if applicable]

To run tests:
  Submit [PROGNAME]T JCL to batch region
  Review SYSOUT for PASS/FAIL counts
  Non-zero return code indicates test failure
═══════════════════════════════════════════════════════════
```

---

## Output Standards

| Rule | Detail |
|---|---|
| Format | IBM ZUnit framework, fixed COBOL format columns 7–72 |
| Test case naming | `TC-NN-DESCRIPTIVE-UPPERCASE-NAME` |
| Test data | Named `TD-` prefixed constants — no magic literals in test bodies |
| DISPLAY before each test | `DISPLAY 'TC-NN: [description]'` always first line |
| DISPLAY on failure | Show both expected and actual values |
| Return code | Non-zero (`MOVE 8 TO WS-RETURN-CODE`) if any test fails |
| TC-SUMMARY always last | Final paragraph writes pass/fail counts and sets RETURN-CODE |

---

## Reference Implementation

| Role | File |
|---|---|
| Gold standard ZUnit test | `MOVPDUP1T.cbl` |
| Program under test | `MOVPDUP1.cbl` |
