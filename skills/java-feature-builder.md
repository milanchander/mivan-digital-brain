---
name: java-feature-builder
description: Paste a MICPS-format Jira story and say "implement this story" or "build this feature" to generate a complete Java Spring Boot feature — data model, service, controller, request/response models, JUnit tests, and README update.
---

# Java Feature Builder

## Trigger

Activate when a developer pastes a Jira story and says **"implement this story"**, **"build this feature"**, or similar. The story must be in MICPS format (see Input Contract below).

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
| Technical Notes | Target classes, DB tables, endpoints |
| Definition of Done | Exit criteria |

---

## Validation — Do Not Skip

Before generating any code, verify the story contains **all four** of the following:

1. **At least 3 numbered acceptance criteria** — if fewer, ask the developer to expand them.
2. **At least one DB table referenced** — if none, ask which table the feature reads from or writes to.
3. **A clear business rule that can be expressed as a boolean condition** — e.g. "charge variance > 10% → flag". If absent, ask the developer to state the rule explicitly.
4. **A named target Java class or service** — if absent, ask whether this modifies an existing class or needs a new one.

If any are missing, **stop and ask** before proceeding. Do not generate code until all four are present.

---

## Generation Steps

Execute in this exact order. **After Step 1, pause and ask the developer to confirm before continuing to Step 2.**

---

### Step 1 — Story Analysis

Read the full story and output a structured summary:

```
STORY ANALYSIS — [ISSUE KEY]
═══════════════════════════════════════════════
Business Problem:
  [One sentence]

Business Rule (boolean):
  [e.g. dosVariance > 1 day AND chargeVariance < 10% → NEAR_DUP]

Acceptance Criteria Extracted:
  AC-1: [text]
  AC-2: [text]
  …

DB Tables Involved:
  - [TABLE_NAME] (read / write / create)

Java Classes to Create or Modify:
  - [ClassName] (new / modify)

Test Scenarios (one per AC):
  AC-1 → [test scenario description]
  AC-2 → [test scenario description]
  …
═══════════════════════════════════════════════
Confirm to proceed with Step 2? (yes / adjust)
```

---

### Step 2 — Data Model

If the story references a new DB table:

1. Generate Aurora PostgreSQL DDL and append to `src/java/duplicate-detection/src/main/resources/schema-postgres.sql`
   - Follow conventions in the existing `NEAR_DUP_QUEUE` table definition
   - Include `CREATE TABLE IF NOT EXISTS`, PRIMARY KEY, CHECK constraints, and relevant indexes
   - Add a header comment: `-- [ISSUE KEY] [SUMMARY]`

2. Generate a JPA entity class:
   - Package: `com.mivan.micps.model`
   - Annotations: `@Entity @Table(schema="MIVANCPS", name="TABLE_NAME")`
   - Use `@Data @NoArgsConstructor @AllArgsConstructor @Builder` (Lombok)
   - All column names in `@Column(name="COL_NAME")` must match the DDL exactly
   - Class Javadoc must reference the issue key: `/** MICPS-XXXX — [summary] */`
   - Follow `ClaimPayment.java` as the pattern

3. Generate a Spring Data JPA repository:
   - Package: `com.mivan.micps.repository`
   - Extend `JpaRepository<EntityClass, IdType>`
   - Add a `@Query` method for any query the service will need
   - Follow `ClaimPaymentRepository.java` as the pattern

---

### Step 3 — Service Implementation

Generate or update the service class:

- Package: `com.mivan.micps.service`
- Add one method per distinct business function in the story
- Every threshold or business constant must be a `private static final` named constant — no magic numbers
- Every business rule implementation must have an inline comment citing the AC number:
  ```java
  // AC-1: charge variance must be within 10% of paid amount
  if (chargeVariancePct.compareTo(CHARGE_TOLERANCE_PCT) > 0) { … }
  ```
- Class-level Javadoc must reference the issue key
- Follow `DuplicateClaimDetectionService.java` as the pattern:
  - `@Service @RequiredArgsConstructor`
  - Repository injected via constructor
  - Result returned as a sealed record or enum-backed result type

---

### Step 4 — Controller Update

Update `DuplicateClaimController.java` if the story requires a new endpoint:

- Add to the existing `@Tag(name="Duplicate Detection")` controller
- Follow existing endpoint conventions: `@PostMapping` / `@GetMapping`, `ResponseEntity<T>` return type
- Full OpenAPI annotations:
  ```java
  @Operation(summary="…", description="MICPS-XXXX — …")
  @ApiResponse(responseCode="200", description="…")
  ```
- Inject any new service via `@RequiredArgsConstructor` constructor injection

---

### Step 5 — Request/Response Models

Generate new DTO classes only if the story introduces new API inputs or outputs:

- Package: `com.mivan.micps.model`
- Use Java `record` for immutable DTOs (follow `DuplicateCheckRequest.java`)
- Add OpenAPI annotations: `@Schema(description="…")`
- Add Jakarta validation: `@NotNull`, `@NotBlank`, `@Positive` where appropriate
- Include a factory method or `toEntity()` converter where needed
- Class Javadoc must reference the issue key

---

### Step 6 — JUnit Tests

Generate comprehensive JUnit 5 tests:

**Test class naming:** `[ServiceClass]Test.java` in the corresponding test package.

**One test method per acceptance criterion.** Method names must follow this pattern:
```
test[AC_NUMBER]_[CamelCaseDescription]_[ExpectedOutcome]
```
Example: `testAC1_ChargeVarianceWithin10Pct_ShouldFlagNearDup`

**Each test must include:**
```java
// AC-1: charge variance within 10% of paid amount triggers NEAR_DUP
@Test
void testAC1_ChargeVarianceWithin10Pct_ShouldFlagNearDup() { … }
```

**Coverage requirements:**
- One positive test (condition met → expected outcome) per AC
- One negative test (boundary / just-outside condition) per AC
- One edge case per major business rule (null modifier, zero charge, same-day DOS)

**Test setup follows `DuplicateClaimDetectionServiceTest.java`:**
- `@ExtendWith(MockitoExtension.class)`
- `@Mock` for all repositories
- `@InjectMocks` for the service under test
- Use `when(…).thenReturn(…)` — no `any()` matchers on value objects
- Assert on the result record fields directly

---

### Step 7 — README Update

Append a new entry to `src/README.md`:

```markdown
## [ISSUE KEY] — [Summary]

**Status:** Implemented  
**Date:** [today]

### What Was Built
[1–2 sentences]

### New Endpoints
| Method | Path | Description |
|--------|------|-------------|
| POST | /api/v1/claims/… | … |

### New Classes
- `ClassName` — [one-line description]

### How to Test
\`\`\`powershell
Invoke-RestMethod -Method POST -Uri http://localhost:8080/api/v1/claims/seed …
Invoke-RestMethod -Method POST -Uri http://localhost:8080/api/v1/claims/evaluate …
\`\`\`
```

---

### Step 8 — Verification Checklist

After all code is generated, output this checklist. The developer must confirm each item before considering the story done:

```
VERIFICATION CHECKLIST — [ISSUE KEY]
═══════════════════════════════════════════════
[ ] All acceptance criteria have a corresponding test method
[ ] All test method names reference AC numbers (testAC1_…, testAC2_…)
[ ] All business rule implementations have inline // AC-N: … comments
[ ] New DB tables have both DDL (schema-postgres.sql) and JPA entity
[ ] All thresholds are named constants — no magic numbers
[ ] Controller has full OpenAPI annotations
[ ] README updated with new entry
[ ] mvn test passes (run before declaring done)
═══════════════════════════════════════════════
```

---

## Output Standards

- **Java version:** Java 21 throughout (records, switch expressions, text blocks)
- **Boilerplate:** Lombok for all entities and DTOs
- **Constants:** Every threshold and business literal as a `private static final` named constant
- **Javadoc:** Every class must have a Javadoc comment referencing the Jira issue key
- **Package structure:** `com.mivan.micps` (not `com.mivan.micps.duplicatedetection`)
- **No TODOs or stub implementations** — every generated method must be complete

---

## Reference Implementations

Always refer to these existing files as patterns when generating code:

| Role | File |
|---|---|
| Service | `DuplicateClaimDetectionService.java` |
| Service tests | `DuplicateClaimDetectionServiceTest.java` |
| Controller | `DuplicateClaimController.java` |
| JPA entity | `ClaimPayment.java` |
| Repository | `ClaimPaymentRepository.java` |
| Request DTO | `DuplicateCheckRequest.java` |
| Response DTO | `DuplicateCheckResponse.java` |
| PostgreSQL DDL | `schema-postgres.sql` |

---

## Example Usage

Developer pastes the MICPS-4471 story and says "implement this story":

1. Skill validates the story (3+ ACs ✓, DB table ✓, business rule ✓, target class ✓)
2. Outputs **Step 1 analysis** and asks for confirmation
3. Developer says "yes" → skill generates Steps 2–7 in sequence
4. Outputs **Step 8 checklist**
5. Developer runs `mvn test` to verify all tests pass
