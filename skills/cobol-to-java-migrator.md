---
name: cobol-to-java-migrator
description: Provide a MiCPS COBOL program and say "migrate this", "convert this to Java", or "build the Java equivalent" to generate a production-quality Java 21 Spring Boot service with full traceability, shadow mode harness, and migration notes.
---

# COBOL to Java Migrator

## Trigger

Activate when a developer provides a COBOL program and says **"migrate this"**, **"convert this to Java"**, or **"build the Java equivalent"**. The COBOL source may be pasted inline or referenced by program name.

---

## Purpose

Translate a MiCPS COBOL program into a production-quality Java 21 Spring Boot service that produces **identical outputs for identical inputs**. The migrated service must be suitable for shadow mode validation against the original COBOL program before cutover.

Gold standard reference migration: `MOVPDUP1.cbl` → `DuplicateClaimDetectionService.java`.

---

## Input Contract

Collect the following before proceeding. Flag any that are missing:

| Input | Required | Notes |
|---|---|---|
| COBOL source program | Yes | `.cbl` file or pasted code |
| Migration wave | Yes | Wave 1–5 |
| COPYBOOK files referenced | If available | Flag as gap if missing |
| DB2 table schemas | If available | From DECLARE TABLE, or L3/L4 knowledge layer |
| JCL job that invokes it | If available | Needed for Step 5 (Spring Batch) |

---

## Validation — Do Not Skip

Before migrating, ask and record answers to all four of these:

1. **COPYBOOK availability** — Are the COPYBOOK layouts available for all files referenced by the program? If not, list each missing copybook as a gap. The developer must either provide them or acknowledge that field-level mapping will be approximate.

2. **DB2 table schema completeness** — Are all DB2 table schemas known (column names, types, constraints)? If not, list each unknown table as a gap. Check the L3/L4 knowledge layer first before asking.

3. **Subprogram / calling interface** — Is this program called by other COBOL programs via `CALL`? If yes, the calling interface (LINKAGE SECTION parameters) must be preserved as a Java method signature, not a REST endpoint.

4. **Hardcoded values** — Are there hardcoded thresholds, date offsets, reason codes, or dollar limits in the COBOL that should become externalized configuration in the Java service? List each one and confirm with the developer before treating them as constants.

**Do not proceed to code generation until all gaps are acknowledged by the developer.**

---

## Analysis Step — Output Before Generating Any Code

Read the full COBOL program and produce the following structured analysis. **Ask the developer to confirm before proceeding to Step 1.**

### 1. Program Summary

```
PROGRAM SUMMARY — [PROGRAM NAME]
═══════════════════════════════════════════════════════
What it does:
  [Plain English description — 2–3 sentences]

Input sources:
  - [VSAM KSDS/ESDS file name — purpose]
  - [DB2 table name — read/write/cursor]
  - [Work file — purpose]

Output targets:
  - [DB2 table — insert/update]
  - [VSAM file — write]
  - [Return code / SQLCODE]

Key business rules identified:
  BR-1: [description — cite paragraph name]
  BR-2: [description — cite paragraph name]
  …

Hardcoded values found:
  - [Value] in paragraph [NAME] — candidate for @Value property
  …

Complexity assessment: Low / Medium / High / Very High
Reason: [one sentence]
═══════════════════════════════════════════════════════
```

### 2. COBOL to Java Mapping

| COBOL Construct | Java Equivalent |
|---|---|
| `WORKING-STORAGE` | Class fields / local variables |
| `PERFORM paragraph` | Private method call |
| `DB2 cursor (DECLARE/OPEN/FETCH/CLOSE)` | Spring Data JPA `@Query` method + result iteration |
| `VSAM KSDS READ` | `JpaRepository.findById()` |
| `VSAM ESDS WRITE` | `JpaRepository.save()` |
| `EVALUATE TRUE` | `switch` expression (Java 21) |
| `COMPUTE` | `BigDecimal` arithmetic (`add`, `multiply`, `divide`) |
| `MOVE` | Assignment or record constructor |
| `CALL subprogram` | Service method call (inject via constructor) |
| `GOBACK / STOP RUN` | `return` statement |
| `PIC S9(7)V99 COMP-3` | `BigDecimal` |
| `PIC 9(8)` date | `Integer` (YYYYMMDD) or `LocalDate` |
| `SQLCODE` | Spring Data exception handling |

List all COBOL paragraphs and their Java method equivalents:

| COBOL Paragraph | Java Method | Notes |
|---|---|---|
| `0000-MAIN` | `execute()` (public entry point) | |
| `1000-INITIALIZE` | `initialize()` | |
| … | … | |

### 3. Shadow Mode Validation Plan

```
SHADOW MODE PLAN
═══════════════════════════════════════════════════════
Input source for comparison:
  [What dataset / table will be used to drive both programs]

Match definition:
  [What fields in the output must match exactly]

Acceptable discrepancies:
  [e.g. timestamp fields, sequence numbers — document why]

Cutover gate:
  [e.g. 99.99% output agreement over 30 consecutive business days]
═══════════════════════════════════════════════════════
Confirm analysis to proceed with Step 1? (yes / adjust)
```

---

## Generation Steps

---

### Step 1 — Aurora PostgreSQL Schema

For each DB2 table accessed by the COBOL program, generate Aurora PostgreSQL DDL and append to `src/java/duplicate-detection/src/main/resources/schema-postgres.sql`.

**DB2 to PostgreSQL type mapping:**

| DB2 / COBOL Type | PostgreSQL Type |
|---|---|
| `PIC X(n)` / `CHAR(n)` | `VARCHAR(n)` |
| `PIC 9(n)` / `DECIMAL(n,0)` | `NUMERIC(n,0)` |
| `PIC S9(7)V99 COMP-3` | `NUMERIC(9,2)` |
| `PIC S9(4) COMP` / `SMALLINT` | `INTEGER` |
| `PIC S9(9) COMP` / `INTEGER` | `BIGINT` |
| `DATE` | `DATE` |
| `TIMESTAMP` | `TIMESTAMP` |
| `CHAR(1)` status/flag | `CHAR(1)` with `CHECK` constraint |

Rules:
- Every table gets `CREATE TABLE IF NOT EXISTS mivancps.[table_name_lowercase]`
- Preserve all DB2 CHECK constraints and FOREIGN KEY constraints
- Add a header comment: `-- [PROGRAM NAME] migration — Wave [N]`
- Add the same indexes as the DB2 DDL (converted to `CREATE INDEX IF NOT EXISTS`)

---

### Step 2 — JPA Entity Classes

For each DB2 table:

- Package: `com.mivan.micps.model`
- Annotations: `@Entity @Table(schema="MIVANCPS", name="TABLE_NAME")`
- Lombok: `@Data @NoArgsConstructor @AllArgsConstructor @Builder`
- Column names: convert `HYPHEN-CASE` DB2 / COBOL names to `snake_case` in `@Column(name="...")`
- Field types follow the COBOL/DB2 type mapping above — `BigDecimal` for all monetary fields, never `float` or `double`
- Class Javadoc must reference the COBOL program and migration wave:
  ```java
  /** [PROGRAM NAME] migration Wave [N] — [DB2 table] entity. */
  ```
- Follow `ClaimPayment.java` as the pattern

---

### Step 3 — Repository Interfaces

For each entity:

- Package: `com.mivan.micps.repository`
- Extend `JpaRepository<EntityClass, IdType>`
- Add a `@Query` method for each DB2 cursor in the COBOL program
- Name query methods to match the COBOL cursor or paragraph name with camelCase conversion:
  - `PAID-CLAIMS-CUR` → `findPaidCandidates(...)`
  - `2200-FIND-NEAR-DUP` → `findNearDupCandidates(...)`
- Include a comment on each query method citing the source COBOL cursor:
  ```java
  // COBOL: DECLARE PAID-CLAIMS-CUR CURSOR FOR ...
  @Query("SELECT c FROM ClaimPayment c WHERE ...")
  List<ClaimPayment> findPaidCandidates(...);
  ```
- Follow `ClaimPaymentRepository.java` as the pattern

---

### Step 4 — Service Class

Generate the main service class:

**Naming:** Derive from the COBOL program name using one of:
- Descriptive functional name if intent is clear (preferred): `DuplicateClaimDetectionService`
- Direct camelCase conversion as fallback: `Movpdup1Service`

**Structure:**
- Package: `com.mivan.micps.service`
- `@Service @RequiredArgsConstructor`
- One `public` method per COBOL entry point (program PROCEDURE DIVISION or CICS HANDLE)
- One `private` method per significant COBOL paragraph
- Private method names must be camelCase conversions of the COBOL paragraph names:
  - `2200-FIND-NEAR-DUP` → `findNearDup()`
  - `3100-EVALUATE-MATCH` → `evaluateMatch()`

**Traceability rules — non-negotiable:**
- Every method has a Javadoc comment citing the COBOL paragraph it translates:
  ```java
  /** Translates COBOL paragraph 3100-EVALUATE-MATCH. Determines match classification. */
  ```
- Every business rule has an inline comment citing the COBOL paragraph and line reference:
  ```java
  // COBOL 3100-EVALUATE-MATCH: WHEN WS-CHARGE-VARIANCE < 10
  if (chargeVariancePct.compareTo(CHARGE_TOLERANCE_PCT) < 0) { … }
  ```
- Every hardcoded COBOL value that became a named constant has a comment:
  ```java
  // Hardcoded in COBOL WORKING-STORAGE as 10; externalized to config
  private static final BigDecimal CHARGE_TOLERANCE_PCT = new BigDecimal("10.00");
  ```

**Arithmetic rules:**
- `BigDecimal` for all monetary fields — never `float` or `double`
- Packed decimal (`COMP-3`) maps to `BigDecimal`
- COBOL binary integers (`COMP`) map to `int` or `long`
- `HALF_UP` rounding by default; note if COBOL uses `ROUNDED` keyword
- Date arithmetic uses `java.time` (`LocalDate`, `ChronoUnit`) — never `java.util.Date`

---

### Step 5 — Spring Batch Job (if JCL-invoked)

If the COBOL program is invoked by a JCL batch job, generate a Spring Batch configuration:

- One `@Configuration` class per JCL job
- One `Step` bean per JCL `EXEC` step
- Preserve JCL `COND=(RC,LE,STEPxx)` dependencies as Spring Batch `FlowBuilder` conditions
- `ItemReader` for each input file or table cursor
- `ItemProcessor` containing the business logic (delegate to service)
- `ItemWriter` for each output file or table

Name classes to match JCL job and step names:
- JCL `//MOVPAUD0 JOB` → `MovpAud0JobConfig`
- JCL `//STEP020` → `step020Bean()`

Include a comment on each step citing the JCL step it replaces:
```java
// JCL STEP020: EXEC PGM=MOVPDUP1, COND=(8,LE,STEP010)
@Bean
public Step step020(...) { … }
```

---

### Step 6 — REST Endpoint (if CICS transaction)

If the COBOL program has a CICS transaction equivalent (`EXEC CICS RECEIVE MAP` / `SEND MAP`):

- Generate a `@RestController` in `com.mivan.micps.controller`
- Map the CICS transaction code to a REST path: `TDPX` → `POST /api/v1/[domain]/[action]`
- BMS map fields become request/response record DTOs
- Add to the existing `@Tag(name="Duplicate Detection")` controller or create a new tag
- Full OpenAPI annotations on every endpoint

---

### Step 7 — JUnit Tests

Generate migration validation tests:

- Class name: `[ServiceName]MigrationTest`
- Package: matching service package, under `src/test/`
- Extend or follow `DuplicateClaimDetectionServiceTest.java` as the pattern

**One test method per business rule** identified in the Analysis Step:

```java
// Validates parity with COBOL paragraph 3100-EVALUATE-MATCH — BR-1: charge within tolerance
@Test
void testBR1_ChargeWithinTolerance_ShouldReturnClean() { … }
```

Test method naming: `test[BR_NUMBER]_[CamelCaseDescription]_[ExpectedOutcome]`

**Coverage requirements:**
- Positive test (rule triggered) and negative test (rule not triggered) per business rule
- One boundary test per numeric threshold (exactly at limit, one unit over, one unit under)
- One null-safety test per optional COBOL field

**Setup:**
- `@ExtendWith(MockitoExtension.class)`
- `@Mock` for all repositories
- `@InjectMocks` for the service under test
- Input data built using entity `Builder` — no magic literals inline

---

### Step 8 — Shadow Mode Harness

Generate a `ShadowModeValidator` class in `com.mivan.micps.shadow`:

```java
/**
 * Shadow mode validator for [PROGRAM NAME] migration.
 * Compares Java service output against expected COBOL output loaded from fixtures.
 * Used during parallel run before cutover. Wave [N].
 */
@Component
public class ShadowModeValidator { … }
```

Responsibilities:
- Accept the same input as the Java service
- Call the Java service and capture its output
- Load expected COBOL output from a JSON fixture file (`src/test/resources/shadow/[program]-fixtures.json`)
- Compare outputs field-by-field and report any discrepancies with:
  - Field name
  - Expected value (COBOL)
  - Actual value (Java)
  - Whether the discrepancy is in the acceptable list
- Return a `ShadowValidationResult` record: `{ inputId, match, discrepancies, timestamp }`

Generate the fixture file schema and two sample fixtures using the test inputs from Step 7.

---

### Step 9 — Migration Notes

Generate `src/migration/[PROGRAM-NAME]-MIGRATION-NOTES.md`:

```markdown
# [PROGRAM NAME] Migration Notes

## Program Summary
[2–3 sentences from Analysis Step]

## Migration Wave
Wave [N] — Target cutover: [date if known]

## Cutover Gate
[e.g. 99.99% output agreement over 30 consecutive business days]

## Files Generated
| File | Purpose |
|---|---|
| `[EntityClass].java` | JPA entity for [TABLE] |
| `[ServiceClass].java` | Business logic |
| `[ServiceClass]MigrationTest.java` | Validation tests |
| `ShadowModeValidator.java` | Shadow run harness |

## Hardcoded Values Externalized
| COBOL Value | COBOL Location | Java Constant | Config Key |
|---|---|---|---|
| [value] | [paragraph] | `CONSTANT_NAME` | `micps.[key]` |

## Business Rules That Required Interpretation
[List any COBOL logic that was ambiguous or required a judgment call]

## Known Behavioral Differences
[List any intentional differences between COBOL and Java behavior and why they are acceptable]

## Shadow Mode Test Period
Recommended: [N] business days minimum
Inputs: [describe the data set]
Match definition: [fields that must be identical]

## Rollback Procedure
1. [Step 1]
2. [Step 2]
```

---

## Output Standards

| Rule | Detail |
|---|---|
| COBOL paragraph names | Preserved as method names (camelCase) and in Javadoc / inline comments |
| Monetary arithmetic | `BigDecimal` only — never `float` or `double` |
| Packed decimal (`COMP-3`) | → `BigDecimal` |
| Binary integer (`COMP`) | → `int` or `long` |
| Date arithmetic | `java.time` (`LocalDate`, `ChronoUnit`) |
| Hardcoded COBOL values | → `private static final` named constant + `@Value` property for configurables |
| Thresholds | Never inline — always named constants with units in the name (`_PCT`, `_DAYS`) |
| Javadoc | Every class and public method must reference the source COBOL program name and paragraph |

---

## Reference Implementations

| Role | File |
|---|---|
| Gold standard migration | `MOVPDUP1.cbl` → `DuplicateClaimDetectionService.java` |
| Migration tests | `DuplicateClaimDetectionServiceTest.java` |
| JPA entity pattern | `ClaimPayment.java` |
| Repository pattern | `ClaimPaymentRepository.java` |
| PostgreSQL DDL pattern | `schema-postgres.sql` |
| COBOL copybook pattern | `CLMPAYRC.cpy`, `NDUPQREC.cpy` |
| DB2 DDL pattern | `NEAR_DUP_QUEUE.sql` |
