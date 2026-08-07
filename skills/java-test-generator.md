---
name: java-test-generator
description: Provide a Java class and say "generate tests", "write tests for this", or "improve test coverage" to produce a comprehensive JUnit 5 test suite aligned to business acceptance criteria, boundary values, and migration parity where applicable.
---

# Java Test Generator

## Trigger

Activate when a developer provides a Java class and says **"generate tests"**, **"write tests for this"**, or **"improve test coverage"**.

---

## Purpose

Generate a comprehensive JUnit 5 test suite for an existing Java class that has no tests or insufficient coverage. Produces tests that are meaningful, maintainable, and aligned to business acceptance criteria where available. The richer the context provided, the better the tests.

---

## Input Contract

The skill accepts **one of** the following combinations — listed from minimum to ideal:

| Context Provided | Test Quality |
|---|---|
| Java class only | Happy path + boundary + edge cases |
| Java class + Jira story | + Acceptance criteria tests (one per AC) |
| Java class + COBOL equivalent | + Migration parity tests (one per COBOL business rule) |
| Java class + Jira story + COBOL | Full suite — all of the above |

**Minimum requirement:** the Java class itself.

---

## Input Enrichment — Ask Before Analysing

Before reading the code, ask these four questions. Record the answers — they shape the test suite.

1. **Jira story** — Is there a Jira story for this class? If yes, load it. Acceptance criteria become dedicated test methods.

2. **COBOL equivalent** — Is there a COBOL program this class was migrated from? If yes, load it. COBOL paragraphs containing business rules become migration parity tests.

3. **Coverage target** — What is the minimum acceptable line coverage? Default: **80%**. State the target so the coverage gap report (Step 8) is meaningful.

4. **Known edge cases or production incidents** — Have there been bugs or incidents related to this code in production? If yes, every incident becomes a **regression test** with a comment: `// Regression: [incident description]`.

---

## Analysis Step — Output Before Generating Any Tests

Read the full Java class and produce the following. **Ask the developer to confirm before proceeding to Step 1.**

```
TEST ANALYSIS — [ClassName]
═══════════════════════════════════════════════════════
Public methods (primary test targets):
  1. [methodName(params)] — [one-line description]
  2. …

Business rules identified (each needs positive + negative test):
  BR-1: [condition / threshold] — in method [name]
  BR-2: …

Numeric thresholds (each needs at / below / above boundary tests):
  - [constant name] = [value] — in method [name]

Edge cases to cover:
  - Null: [which parameters can be null]
  - Empty: [which collections / strings can be empty]
  - Zero / negative: [which amounts / counts]
  - Date boundaries: [which date comparisons]

Exception paths:
  - [exception type] thrown when [condition] in [method]

Mocked dependencies:
  - [InterfaceName] [fieldName] — used for [purpose]

Acceptance criteria available: Yes / No
  [If yes: AC-1 through AC-N listed]

COBOL parity scenarios available: Yes / No
  [If yes: paragraphs with business rules listed]

Estimated test count: [N] methods
Estimated coverage: [N]% line coverage
═══════════════════════════════════════════════════════
Confirm to proceed with Step 1? (yes / adjust)
```

---

## Generation Steps

---

### Step 1 — Test Class Setup

Generate the test class skeleton:

```java
/**
 * Unit tests for [ClassName].
 * Coverage target: [N]% line coverage.
 * [MICPS-XXXX — if Jira story provided]
 */
@ExtendWith(MockitoExtension.class)
class [ClassName]Test {

    // ── Mocks ──
    @Mock [RepositoryType] [repositoryField];
    @Mock [ServiceType]    [serviceField];     // repeat for each dependency

    @InjectMocks [ClassName] subject;

    // ── Test data constants ──
    private static final String CLAIM_ID     = "CLM-TEST-001";
    private static final String MEMBER_ID    = "MBR-TEST-001";
    // … one constant per recurring test value — no magic literals in test bodies

    @BeforeEach
    void setUp() {
        // shared mock setup that applies to every test — keep minimal
    }
}
```

Rules:
- `@ExtendWith(MockitoExtension.class)` — never `@SpringBootTest` in unit tests
- `@Mock` for every injected dependency
- `@InjectMocks` for the class under test
- All recurring test values as `private static final` constants — never inline literals
- `@BeforeEach` only if meaningful shared setup exists; omit if it would be empty

---

### Step 2 — Happy Path Tests

One test per public method covering the primary success scenario:

**Naming:** `test[MethodName]_[Scenario]_[ExpectedResult]`
Examples:
- `testEvaluate_NearDuplicateByAmtVar_ShouldReturnNearDup`
- `testEvaluate_CleanClaim_ShouldReturnClean`
- `testEvaluate_EDClaim_ShouldReturnSkipped`

**Structure (Arrange / Act / Assert):**
```java
@Test
void testEvaluate_NearDuplicateByAmtVar_ShouldReturnNearDup() {
    // Arrange
    ClaimPayment inbound = claimBuilder().chargeAmt(new BigDecimal("272.50")).build();
    when(repository.findPaidCandidates(any(), any(), any(), anyInt(), anyInt(), any()))
        .thenReturn(List.of(paidClaim()));

    // Act
    EvaluationResult result = subject.evaluate(inbound);

    // Assert
    assertThat(result.outcome()).isEqualTo(Outcome.NEAR_DUP);
    assertThat(result.matchType()).isEqualTo(MatchType.AMT_VAR);
}
```

Rules:
- One logical concept per test — multiple `assertThat` calls are fine if they verify the same concept
- Never mix assertions about different outcomes in one test
- Mock only what the test needs — do not add unnecessary `when(…)` setups

---

### Step 3 — Acceptance Criteria Tests

Generated only when a Jira story is available. One test per numbered AC:

**Naming:** `testAC[N]_[CamelCaseDescription]_[ExpectedOutcome]`
Examples:
- `testAC1_ChargeVarianceWithin10Pct_ShouldFlagNearDup`
- `testAC3_EDClaimCptCode_ShouldSkip`

```java
// AC-1: Near-duplicate flagged when charge variance is within 10% of paid amount
@Test
void testAC1_ChargeVarianceWithin10Pct_ShouldFlagNearDup() {
    …
}
```

Every AC test must have the `// AC-N:` comment citing the acceptance criterion text verbatim (or abbreviated). This makes traceability auditable.

---

### Step 4 — Boundary Value Tests

For **every numeric threshold** identified in the code, generate three tests:

| Test | Value | Naming suffix |
|---|---|---|
| Exactly at threshold | `threshold` | `_ExactlyAtThreshold_Should[result]` |
| Just inside (should trigger) | `threshold - epsilon` | `_JustInsideThreshold_Should[result]` |
| Just outside (should not trigger) | `threshold + epsilon` | `_JustOutsideThreshold_Should[result]` |

Example for a 10% charge variance threshold:
```java
// Boundary: 10% charge tolerance (CHARGE_TOLERANCE_PCT)
@Test
void testChargeVariance_ExactlyAt10Pct_ShouldFlagNearDup() { … }

@Test
void testChargeVariance_At9Point99Pct_ShouldFlagNearDup() { … }

@Test
void testChargeVariance_At10Point01Pct_ShouldReturnClean() { … }
```

Apply the same triple-boundary pattern to:
- Date offset tolerances (`_DAYS` constants)
- Count limits
- Amount floors/ceilings
- String length limits (if validated)

---

### Step 5 — Negative Path Tests

Cover every path that results in a rejection, denial, clean result, or early return:

- **Condition not met** — input that does not satisfy the business rule
- **Repository returns empty** — `Optional.empty()` or `List.of()`
- **Null optional fields** — modifier null, secondary code null, amount null
- **Invalid / boundary inputs** — zero charge, negative paid amount, future DOS

Naming: `test[MethodName]_[FailureCondition]_Should[NegativeOutcome]`
Examples:
- `testEvaluate_NoPaidCandidatesFound_ShouldReturnClean`
- `testEvaluate_ChargeVarianceExceeds10Pct_ShouldReturnClean`
- `testEvaluate_NullModifier_ShouldNotThrow`

---

### Step 6 — Exception Tests

For each exception path identified in the analysis:

```java
@Test
void test[Method]_[Condition]_ShouldThrow[ExceptionType]() {
    // Arrange
    when(repository.findPaidCandidates(…)).thenThrow(new DataAccessException("DB down") {});

    // Act + Assert
    assertThrows(DataAccessException.class, () -> subject.evaluate(inbound));
}
```

Rules:
- Use `assertThrows` — never `try/catch` in tests
- Verify the exception message if the code sets a specific message
- If the class is expected to wrap exceptions, assert on the wrapper type

---

### Step 7 — Migration Parity Tests

Generated only when a COBOL program is available. One test per COBOL business rule paragraph:

**Naming:** `testParity_[CobolParagraphName]_[Scenario]_[ExpectedResult]`
Examples:
- `testParity_3100EvaluateMatch_AmtVarWithinTolerance_ShouldMatchCobolOutput`
- `testParity_2200FindNearDup_DateDriftOneDay_ShouldFlagSameAsCobol`

```java
// Migration parity: COBOL paragraph 3100-EVALUATE-MATCH
// Input: same as COBOL TC-02 ZUnit test case
@Test
void testParity_3100EvaluateMatch_AmtVarWithinTolerance_ShouldMatchCobolOutput() {
    …
    // COBOL expected output: NEAR-DUP-MATCH-TYPE = "AMT-VAR"
    assertThat(result.matchType()).isEqualTo(MatchType.AMT_VAR);
}
```

Use the same input values as the COBOL ZUnit test cases where available — this makes the parity provable.

---

### Step 8 — Coverage Gap Report

After generating all tests, output:

```
COVERAGE ESTIMATE — [ClassName]Test
═══════════════════════════════════════════════════════
Tests generated:   [N] methods
Estimated coverage: ~[N]% line / ~[N]% branch
Coverage target:    [N]%
Gap:                [Met / N% below target]

Methods fully covered:
  ✓ [methodName()]
  ✓ …

Branches not covered (recommend additional tests):
  ✗ [methodName()] — [branch condition not covered]
  ✗ …

Recommended additional tests:
  1. [test scenario] — covers [uncovered branch]
  2. …

Run coverage report:
  mvn test jacoco:report
  open target/site/jacoco/index.html
═══════════════════════════════════════════════════════
```

If estimated coverage is below the target, generate the recommended additional tests before declaring the suite complete.

---

## Output Standards

| Rule | Detail |
|---|---|
| JUnit version | JUnit 5 throughout — never JUnit 4 annotations (`@Test` from `org.junit.jupiter.api`) |
| Mocking | Mockito only — never PowerMock |
| Assertions | AssertJ (`assertThat`) where it improves readability; JUnit `assertEquals` acceptable for simple cases |
| `@SpringBootTest` | Never in unit tests — only in integration test classes suffixed `IT` |
| Test data | Named `static final` constants — no magic numbers or string literals in test bodies |
| Test independence | No shared mutable state between tests — each test sets up its own `when(…)` only if needed |
| One logical concept | Multiple `assertThat` calls fine; never test two unrelated outcomes in one method |
| Integration tests | Separate class: `[ClassName]IT.java` — uses `@SpringBootTest` and a real (H2) datasource |

---

## Reference Implementations

| Role | File |
|---|---|
| Service unit test pattern | `DuplicateClaimDetectionServiceTest.java` |
| Controller MockMvc pattern | `DuplicateClaimControllerTest.java` |
| Class under test (service) | `DuplicateClaimDetectionService.java` |
| Class under test (controller) | `DuplicateClaimController.java` |

---

## Example Usage

**Minimum context:**
> Developer pastes `DuplicateClaimDetectionService.java` and says "generate tests"
> → Skill analyses the class, produces analysis summary, developer confirms, generates Steps 1–2, 4–6, 8.

**Full context:**
> Developer pastes the service + MICPS-4471 story + MOVPDUP1.cbl and says "generate tests"
> → Skill generates Steps 1–8, including AC-1 through AC-8 tests and COBOL parity tests for each COBOL paragraph containing a business rule.
