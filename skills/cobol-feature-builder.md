---
name: cobol-feature-builder
description: Paste a MICPS-format Jira story and say "implement this in COBOL" or "build this COBOL feature" to generate a production-quality IBM Enterprise COBOL 6.x implementation — program, COPYBOOKs, DB2 DDL, JCL job step, and ZUnit test program.
---

# COBOL Feature Builder

## Trigger

Activate when a developer pastes a Jira story and says **"implement this in COBOL"** or **"build this COBOL feature"**.

---

## Purpose

Generate a production-quality IBM Enterprise COBOL 6.x implementation of a Jira story for the MiCPS mainframe environment. Output includes the COBOL program, all required COPYBOOKs, JCL job step, DB2 DDL for any new tables, and ZUnit test program.

---

## Input Contract

The story must contain:

| Section | Example |
|---|---|
| Issue Key | `MICPS-4471` |
| Summary | One-line description |
| Background | Current state and gap |
| Enhancement Required | Specific business rules |
| Acceptance Criteria | Numbered list (AC-1, AC-2, …) |
| Technical Notes | Target programs, DB2 tables, VSAM files, JCL job stream |
| Definition of Done | Exit criteria |

---

## Validation — Do Not Skip

Before generating any code, verify all five of the following:

1. **At least 3 numbered acceptance criteria** — if fewer, ask the developer to expand them.
2. **At least one DB2 table or VSAM file referenced** — if none, ask which data sources the program reads from or writes to.
3. **A clear business rule expressible as COBOL EVALUATE or IF logic** — if absent, ask the developer to state the rule explicitly.
4. **Target program name specified or inferable** — 8 characters max, uppercase (e.g. `MOVPDUP1`). If absent, propose one and confirm.
5. **JCL job stream identified** — which existing job does this step belong to? If absent, ask before generating JCL.

If any are missing, **stop and ask** before proceeding. Do not generate code until all five pass.

---

## Analysis Step — Output Before Generating Any Code

Read the full story and produce the following structured analysis. **Ask the developer to confirm before proceeding to Step 1.**

### 1. Program Summary

```
PROGRAM SUMMARY — [PROGRAM-ID]
═══════════════════════════════════════════════════════════
What it does:
  [One sentence]

Processing mode: Batch (JCL) / Online (CICS)

Input sources:
  - [VSAM KSDS/ESDS file name — purpose]
  - [DB2 table — DECLARE cursor / single-row fetch]
  - [Work file — purpose]

Output targets:
  - [DB2 table — INSERT / UPDATE]
  - [VSAM file — WRITE / REWRITE]
  - [Return code / SYSOUT summary]

Business rules identified:
  BR-1: [description — target paragraph name]
  BR-2: [description — target paragraph name]
  …

Hardcoded values to avoid (move to WORKING-STORAGE constants):
  - [value] — [where it appears] — [AC reference]
  …

Complexity: Low / Medium / High / Very High
Reason: [one sentence]
═══════════════════════════════════════════════════════════
```

### 2. Program Structure Plan

List every paragraph to be written:

| Paragraph | Purpose |
|---|---|
| `0000-MAIN` | Entry point — PERFORM sequence, STOP RUN |
| `1000-INIT` | Open files, initialize counters, open DB2 cursors |
| `2000-PROCESS` | Main processing loop |
| `3000-[BUSINESS FUNCTION]` | Business rule implementation (one per BR) |
| `4000-[OUTPUT FUNCTION]` | DB2 INSERT/UPDATE, VSAM WRITE, work file output |
| `9000-FINALIZE` | Close files/cursors, write SYSOUT summary, set RETURN-CODE |
| `9999-ABEND` | Standard abend handler — display error, RC=16, STOP RUN |

COPYBOOKs needed:
- `[TABLENAME]RC.cpy` — DB2 host variable layout
- `[PROGNAME].cpy` — working storage constants and work fields

DB2 tables to DECLARE in WORKING-STORAGE.

VSAM files to define in FILE SECTION with SELECT statements.

### 3. ZUnit Test Plan

```
ZUNIT TEST PLAN — [PROGNAME]T
═══════════════════════════════════════════════════════════
TC-01: [AC-1 description] — input: [values] → expected: [outcome]
TC-02: [AC-2 description] — input: [values] → expected: [outcome]
…
═══════════════════════════════════════════════════════════
Confirm analysis to proceed with Step 1? (yes / adjust)
```

---

## Generation Steps

---

### Step 1 — DB2 DDL

For any new DB2 tables required by the story, generate and save to `src/cobol/DDL/[TABLENAME].sql`:

```sql
-- [TABLENAME].sql  DB2 for z/OS DDL — [ISSUE KEY]
-- Schema: MIVANCPS   Subsystem: DB2P

CREATE STOGROUP [STOGROUP_NAME]
  VOLUMES ([VOL1], [VOL2])
  VCAT [VCAT];

CREATE TABLESPACE [TSNAME]
  IN MIVANCPS
  USING STOGROUP [STOGROUP_NAME]
  PRIQTY [N] SECQTY [N]
  LOCKSIZE PAGE
  BUFFERPOOL BP2
  COMPRESS YES;

CREATE TABLE MIVANCPS.[TABLENAME] (
    [COL_NAME]  [TYPE]  NOT NULL,
    …
    CONSTRAINT [PK_NAME] PRIMARY KEY ([COL]),
    CONSTRAINT [CHK_NAME] CHECK ([COL] IN ('V1','V2'))
) IN MIVANCPS.[TSNAME];

CREATE INDEX MIVANCPS.[IX1_NAME]
    ON MIVANCPS.[TABLENAME] ([COL] ASC, [COL2] ASC)
    CLUSTER;

GRANT SELECT, INSERT, UPDATE ON TABLE MIVANCPS.[TABLENAME]
    TO MICPS_BATCH;
```

**DB2 to COBOL PIC type mapping:**

| COBOL PIC | DB2 Column Type |
|---|---|
| `PIC X(n)` | `CHAR(n)` or `VARCHAR(n)` |
| `PIC 9(n)` | `INTEGER` (n≤9) or `BIGINT` (n>9) |
| `PIC S9(7)V99 COMP-3` | `DECIMAL(9,2)` |
| `PIC 9(8)` date | `DECIMAL(8,0)` |
| `PIC X(1)` flag | `CHAR(1) CHECK (col IN ('P','A','D'))` |

---

### Step 2 — COPYBOOKs (DB2 Host Variable Layouts)

For each DB2 table accessed, generate and save to `src/cobol/COPYBOOKS/[TABLENAME]RC.cpy`:

```cobol
      *----------------------------------------------------------------*
      * [TABLENAME]RC  Host variable layout for MIVANCPS.[TABLENAME]   *
      *                [ISSUE KEY]                                      *
      *----------------------------------------------------------------*
       01  [RECORD-NAME].
           05  [FIELD-NAME]          PIC X(20).
           05  [AMT-FIELD]           PIC S9(7)V99  COMP-3.
           05  [STATUS-FIELD]        PIC X(1).
               88  [STATUS-ACTIVE]   VALUE 'A'.
               88  [STATUS-PENDING]  VALUE 'P'.
```

Rules:
- `01` level for the record group; `05` for all fields
- `COMP-3` for all packed-decimal monetary fields
- `COMP` for binary counters and index fields
- `88`-level condition names for all status/flag fields
- `VALUE` clause only for fields with documented defaults

---

### Step 3 — Working Storage COPYBOOK

Generate the program-specific working storage and save to `src/cobol/COPYBOOKS/[PROGNAME].cpy`:

```cobol
      *----------------------------------------------------------------*
      * [PROGNAME].cpy  Working storage — [ISSUE KEY]                  *
      *----------------------------------------------------------------*
      * Return and SQL codes
       01  WS-RETURN-CODE            PIC S9(4)     COMP VALUE ZERO.
       01  WS-SQLCODE                PIC S9(9)     COMP VALUE ZERO.

      * Record counters
       01  WS-READ-COUNT             PIC 9(9)      COMP VALUE ZERO.
       01  WS-WRITE-COUNT            PIC 9(9)      COMP VALUE ZERO.
       01  WS-SKIP-COUNT             PIC 9(9)      COMP VALUE ZERO.
       01  WS-ERROR-COUNT            PIC 9(9)      COMP VALUE ZERO.

      * Business rule thresholds — [AC references]
       01  WS-[THRESHOLD-NAME]       PIC [type]    VALUE [n].
           *> AC-N: [threshold description]

      * Processing flags
       01  WS-END-OF-FILE            PIC X(1)      VALUE 'N'.
           88  WS-EOF                VALUE 'Y'.
           88  WS-NOT-EOF            VALUE 'N'.

      * Work fields
       01  WS-[WORK-FIELD]           PIC [type].
```

---

### Step 4 — Main COBOL Program

Generate and save to `src/cobol/[PROGNAME].cbl`:

```cobol
      *----------------------------------------------------------------*
      * PROGRAM-ID: [PROGNAME]                                         *
      * AUTHOR:     MIVAN HEALTH PLAN                                  *
      * DATE:       [YYYY-MM-DD]                                       *
      * ISSUE:      [ISSUE KEY] — [SUMMARY]                            *
      *                                                                *
      * DESCRIPTION:                                                   *
      *   [2-3 sentence plain English description]                     *
      *                                                                *
      * PARAGRAPHS:                                                    *
      *   0000-MAIN       Entry point                                  *
      *   1000-INIT       Initialization                               *
      *   2000-PROCESS    Main loop                                    *
      *   3000-[FUNC]     [Business rule]                              *
      *   4000-[OUTPUT]   [Output function]                            *
      *   9000-FINALIZE   Cleanup and reporting                        *
      *   9999-ABEND      Error handler                                *
      *----------------------------------------------------------------*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. [PROGNAME].
```

**PROCEDURE DIVISION requirements:**

`0000-MAIN`:
```cobol
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-PROCESS UNTIL WS-EOF
           PERFORM 9000-FINALIZE
           STOP RUN.
```

`1000-INIT`: Open all files, initialize counters to zero, open DB2 cursors, check SQLCODE after each DB2 statement.

`2000-PROCESS`: Main loop — FETCH from cursor or READ file, call 3000-level paragraphs for business logic, call 4000-level for output, increment counters, checkpoint every 10,000 records.

`3000-[BUSINESS FUNCTION]` (one per BR):
- Each business rule in its own named paragraph
- Inline comment citing the AC number:
  ```cobol
      * AC-1: Flag if charge variance within 10%
           IF WS-CHARGE-VARIANCE <= WS-CHARGE-TOLERANCE
               MOVE 'AMT-VAR' TO [MATCH-TYPE-FIELD]
           END-IF
  ```
- Use `EVALUATE` for multi-way conditions; `IF`/`END-IF` for simple conditions
- No nested IF deeper than 3 levels — refactor to sub-paragraphs

`4000-[OUTPUT FUNCTION]`: DB2 INSERT/UPDATE with SQLCODE check, VSAM WRITE with file-status check. Route to `9999-ABEND` on unexpected error codes.

`9000-FINALIZE`:
```cobol
       9000-FINALIZE.
           CLOSE [files]
           EXEC SQL CLOSE [cursor] END-EXEC
           DISPLAY '[PROGNAME] COMPLETE'
           DISPLAY '  RECORDS READ:    ' WS-READ-COUNT
           DISPLAY '  RECORDS WRITTEN: ' WS-WRITE-COUNT
           DISPLAY '  RECORDS SKIPPED: ' WS-SKIP-COUNT
           DISPLAY '  ERRORS:          ' WS-ERROR-COUNT
           MOVE WS-RETURN-CODE TO RETURN-CODE.
```

`9999-ABEND`:
```cobol
       9999-ABEND.
           DISPLAY '[PROGNAME] ABEND - ' WS-ERROR-MSG
           DISPLAY '  SQLCODE: ' WS-SQLCODE
           MOVE 16 TO WS-RETURN-CODE
           MOVE WS-RETURN-CODE TO RETURN-CODE
           STOP RUN.
```

**Coding standards enforced:**
- Columns 7–72 only
- `*` in column 7 for comments, `-` for continuation
- All paragraph names and data names UPPERCASE-HYPHENATED
- `COPY` statement for every record layout — no inline FD redefinitions
- `EXEC SQL … END-EXEC` for all DB2 access
- SQLCODE checked immediately after every DB2 statement
- Checkpoint `DISPLAY` every 10,000 records: `DISPLAY '[PROGNAME] CHECKPOINT ' WS-READ-COUNT`
- No inline string literals for business values — use WORKING-STORAGE constants

---

### Step 5 — JCL Job Step

Generate and save to `src/cobol/[PROGNAME].jcl`:

```jcl
//[JOBNAME] JOB (MiCPS,[ACCT]),'[DESC]',
//             CLASS=A,MSGCLASS=X,MSGLEVEL=(1,1),
//             NOTIFY=&SYSUID
//*----------------------------------------------------------------*
//* [JOBNAME]  [Description] — [ISSUE KEY]                        *
//* STEP0NN    [PROGNAME]  [Purpose]                               *
//*            Runs after STEP0[NN-1] — COND=(8,LE,STEP0[NN-1])  *
//*----------------------------------------------------------------*
//JOBLIB   DD DSN=MIVANCPS.LOADLIB,DISP=SHR
//*
//STEP0NN  EXEC PGM=IKJEFT01,COND=(8,LE,STEP0[NN-1])
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD *
  DSN SYSTEM(DB2P)
  RUN PROGRAM([PROGNAME]) PLAN([PROGNAME]) -
      LIB(MIVANCPS.LOADLIB)
  END
//SYSPRINT DD SYSOUT=*
//[DDNAME]  DD DSN=[VSAM.DATASET],DISP=SHR
//*
```

Include comment block showing the full job stream with the new step annotated.

---

### Step 6 — ZUnit Test Program

Generate and save to `src/cobol/[PROGNAME]T.cbl`:

```cobol
      *----------------------------------------------------------------*
      * PROGRAM-ID: [PROGNAME]T                                        *
      * ZUnit test program for [PROGNAME] — [ISSUE KEY]               *
      *                                                                *
      * TEST CASES:                                                    *
      *   TC-01: [AC-1 description]                                    *
      *   TC-02: [AC-2 description]                                    *
      *   …                                                            *
      *----------------------------------------------------------------*
```

One test case per AC. Each test case:
```cobol
       TC-01-[AC-DESC].
           DISPLAY 'TC-01: [AC description]'
      * Setup: mock DB2 responses and working storage
           MOVE [test-value] TO [ws-field]
      * Execute
           CALL '[PROGNAME]' USING [linkage-fields]
      * Assert
           IF [expected-field] = [expected-value]
               ADD 1 TO WS-PASS-COUNT
               DISPLAY '  TC-01 PASS'
           ELSE
               ADD 1 TO WS-FAIL-COUNT
               DISPLAY '  TC-01 FAIL - GOT: ' [actual-field]
               MOVE 8 TO WS-RETURN-CODE
           END-IF.
```

Final summary:
```cobol
       TC-SUMMARY.
           DISPLAY '[PROGNAME]T COMPLETE'
           DISPLAY '  PASS: ' WS-PASS-COUNT
           DISPLAY '  FAIL: ' WS-FAIL-COUNT
           IF WS-FAIL-COUNT > ZERO
               MOVE 8 TO RETURN-CODE
           END-IF
           STOP RUN.
```

---

### Step 7 — Verification Checklist

Output after all files are generated:

```
VERIFICATION CHECKLIST — [ISSUE KEY]
═══════════════════════════════════════════════════════════
[ ] All ACs have a corresponding ZUnit test case in [PROGNAME]T.cbl
[ ] All business rules implemented in dedicated 3000-level paragraphs
[ ] All paragraphs have inline // AC-N: … comments
[ ] SQLCODE checked after every EXEC SQL statement
[ ] No hardcoded business values — all in WORKING-STORAGE constants
[ ] Checkpoint DISPLAY every 10,000 records in 2000-PROCESS
[ ] 9999-ABEND handler present and reachable
[ ] JCL positioned correctly in job stream with COND code
[ ] DDL generated for all new DB2 tables in src/cobol/DDL/
[ ] All COPYBOOKs generated in src/cobol/COPYBOOKS/
═══════════════════════════════════════════════════════════
```

---

## Output Standards

| Rule | Detail |
|---|---|
| COBOL format | IBM Enterprise COBOL 6.x fixed format — columns 7–72 |
| Paragraph naming | `0000-MAIN`, `1000-INIT`, `2000-PROCESS`, `3000-*`, `4000-*`, `9000-FINALIZE`, `9999-ABEND` |
| Data names | ALL-UPPERCASE-HYPHENATED |
| Arithmetic | `COMPUTE` for complex calculations; `EVALUATE` for multi-way conditions |
| DB2 access | `EXEC SQL … END-EXEC` only; SQLCODE checked after every statement |
| Loops | `PERFORM VARYING` or `PERFORM … UNTIL`; cursor loop with FETCH |
| No magic numbers | All thresholds in WORKING-STORAGE with `VALUE` and AC comment |
| Checkpoints | `DISPLAY` every 10,000 records |

---

## Reference Implementations

| Role | File |
|---|---|
| Gold standard program | `MOVPDUP1.cbl` |
| Gold standard ZUnit tests | `MOVPDUP1T.cbl` |
| DB2 copybook pattern | `CLMPAYRC.cpy` |
| Working storage copybook | `MOVPDUP1.cpy` |
| JCL structure | `MOVPDUP1.jcl` |
| DB2 DDL pattern | `NEAR_DUP_QUEUE.sql` |
