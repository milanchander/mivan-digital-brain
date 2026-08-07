---
name: java-code-reviewer
description: Provide Java code and say "review this", "code review", or "check this against standards" to get a structured review report covering AC alignment, Mivan coding standards, Spring Boot best practices, test quality, migration traceability, and security.
---

# Java Code Reviewer

## Trigger

Activate when a developer provides Java code and says **"review this"**, **"code review"**, or **"check this against standards"**.

---

## Purpose

Perform a structured code review of Java code against Mivan's coding standards, the relevant Jira story acceptance criteria, and general Spring Boot best practices. Produces a structured review report the developer can act on before merging.

---

## Input Contract

| Input | Required | Effect on review |
|---|---|---|
| Java code (file or pasted) | Yes | All dimensions |
| Jira story | Optional | Enables Dimension 1 (AC alignment) |
| Test class | Optional | Enables Dimension 4 (test quality) |
| COBOL source program | Optional | Enables Dimension 5 (migration traceability) |

If only the Java class is provided, Dimensions 2, 3, and 6 are always performed. Dimensions 1, 4, and 5 are skipped with a note that they require additional context.

---

## Review Dimensions

---

### Dimension 1 — Acceptance Criteria Alignment

*Requires: Jira story*

For each numbered AC in the story:

1. **Implementation check** — Is there code in the class that implements this criterion? Cite the method and line range.
2. **Test check** — Is there a test method whose name references this AC (e.g. `testAC1_…`) or whose body clearly validates it?
3. **Rating per AC:**
   - `PASS` — implemented and tested
   - `PARTIAL` — implemented but no test, or test exists but implementation is incomplete
   - `FAIL` — no implementation found and/or no test found

Flag any AC rated PARTIAL or FAIL as a **blocking issue** if it is a core business rule, or a **high priority issue** if it is a secondary requirement.

---

### Dimension 2 — Mivan Coding Standards

Check every item in the table below. Assign a severity and PASS/FAIL per check.

| Check | Severity | Rule |
|---|---|---|
| Monetary arithmetic uses `BigDecimal` | CRITICAL | Never `float`, `double`, or `Float`/`Double` for monetary values |
| No magic numbers | HIGH | All numeric thresholds as `private static final` named constants with units in the name (`_PCT`, `_DAYS`, `_AMT`) |
| Named constants have meaningful names | HIGH | `CHARGE_TOLERANCE_PCT` not `THRESHOLD` or `TEN` |
| JavaDoc on all `public` methods | MEDIUM | Must describe what the method does, not how |
| Jira issue key in class-level JavaDoc | MEDIUM | e.g. `/** MICPS-4471 — ... */` |
| Lombok used for entity/DTO boilerplate | LOW | `@Data`, `@Builder`, `@RequiredArgsConstructor` preferred over manual getters/setters |
| Package structure `com.mivan.micps.[module]` | MEDIUM | No `duplicatedetection` sub-package; no default package |
| No `System.out.println` or raw console logging | HIGH | Use SLF4J `@Slf4j` + `log.debug/info/warn/error` |
| `@Slf4j` log messages use parameterised form | LOW | `log.debug("value: {}", val)` not `log.debug("value: " + val)` |

---

### Dimension 3 — Spring Boot Best Practices

| Check | Severity | Rule |
|---|---|---|
| Constructor injection, not field injection | HIGH | `@RequiredArgsConstructor` + `final` fields; never `@Autowired` on fields |
| `@Transactional` on service methods that write | HIGH | Any method calling `repository.save()`, `delete()`, or multiple writes needs `@Transactional` |
| No business logic in controllers | HIGH | Controllers call service methods; they do not contain conditionals on domain objects |
| DTOs for request/response, not JPA entities | HIGH | Controllers accept/return `record` DTOs; JPA entities must not escape the service layer |
| `@Service` / `@Repository` annotations correct | MEDIUM | Service classes annotated `@Service`; repository interfaces extend `JpaRepository` (no `@Repository` needed) |
| `ResponseEntity<T>` used in controllers | MEDIUM | All controller methods return `ResponseEntity`; no raw type returns |
| OpenAPI annotations on all endpoints | MEDIUM | `@Operation(summary=…)` and `@Tag` on every `@PostMapping`/`@GetMapping` |
| Exception handling | MEDIUM | Service exceptions are either caught and converted to domain results, or propagated as typed exceptions — no swallowed `catch (Exception e) {}` |
| No `Optional.get()` without `isPresent()` | HIGH | Use `orElseThrow()`, `orElse()`, or `ifPresent()` — never bare `get()` |

---

### Dimension 4 — Test Quality

*Requires: test class*

| Check | Severity | Rule |
|---|---|---|
| All `public` methods have at least one test | HIGH | Untested public methods are blocking |
| Boundary values tested (at / below / above threshold) | HIGH | Every `static final` numeric threshold needs three boundary tests |
| Negative paths tested | HIGH | Empty repository results, null inputs, condition-not-met scenarios |
| Test method names describe the scenario | MEDIUM | `test[Method]_[Scenario]_[ExpectedResult]` pattern |
| AC numbers in test names where applicable | MEDIUM | `testAC1_…` naming for stories with numbered ACs |
| No `@SpringBootTest` in unit tests | HIGH | Unit tests use `@ExtendWith(MockitoExtension.class)` only |
| No shared mutable state between tests | HIGH | Each test is independent; no instance fields modified by one test and read by another |
| Test data as named constants | MEDIUM | No magic numbers or literals in test bodies |
| `assertThrows` used for exception tests | LOW | Not `try/catch` in test bodies |
| AssertJ or clear JUnit assertions | LOW | Assertion messages present on non-obvious assertions |

---

### Dimension 5 — Migration Traceability

*Requires: COBOL program or indication this is a migration*

| Check | Severity | Rule |
|---|---|---|
| COBOL paragraph names preserved as method names | HIGH | `2200-FIND-NEAR-DUP` → `findNearDup()` — camelCase conversion, traceable |
| COBOL paragraph citations in method Javadoc | MEDIUM | `/** Translates COBOL paragraph 3100-EVALUATE-MATCH. */` |
| COBOL paragraph citations in inline comments | HIGH | `// COBOL 3100-EVALUATE-MATCH: WHEN WS-CHARGE-VARIANCE < 10` |
| Hardcoded COBOL values documented | HIGH | Every value from COBOL WORKING-STORAGE has a comment noting its origin |
| Migration parity test exists | HIGH | At least one test class ending in `MigrationTest` with `// Migration parity: COBOL paragraph [NAME]` comments |
| `ShadowModeValidator` exists or planned | MEDIUM | Either generated or flagged as a gap |

---

### Dimension 6 — Security and Data

| Check | Severity | Rule |
|---|---|---|
| No PHI in log statements | CRITICAL | Member ID, claim ID, provider NPI, dates of service, amounts must never appear in `log.info/debug/error` — use masked references or counts only |
| No hardcoded credentials | CRITICAL | No passwords, API keys, or connection strings in source code — use `@Value` or AWS Secrets Manager |
| Input validation on controller endpoints | HIGH | `@NotNull`, `@NotBlank`, `@Positive` annotations on request DTOs; `@Valid` on `@RequestBody` |
| Parameterised queries only | CRITICAL | No string concatenation in JPQL or native SQL — always `@Query` with `:param` or `JpaRepository` derived methods |
| No `@SuppressWarnings("unchecked")` masking real issues | LOW | Flag any suppressed warnings for justification |

---

## Output Format

Produce the following structured report. Do not summarise — be specific. Every finding must cite the class name, method name, and line number (or line range) where the issue occurs.

---

```
## Code Review — [ClassName] — [IssueKey or "no story provided"]
**Reviewer:** Mivan Digital Brain
**Date:** [today]
**Dimensions assessed:** [list which dimensions ran]
**Overall verdict:** APPROVED / APPROVED WITH COMMENTS / CHANGES REQUIRED

---

### Critical Issues (must fix before merge)
[CRITICAL-1] [Dimension] — [ClassName].[methodName()] line [N]
  Issue: [specific description]
  Rule: [which rule was violated]
  Fix: [specific code change required]

[none — all critical checks passed] if applicable

---

### High Priority Issues (should fix before merge)
[HIGH-1] [Dimension] — [ClassName].[methodName()] line [N]
  Issue: [specific description]
  Fix: [specific code change required]

---

### Medium Priority Issues (fix in follow-up)
[MEDIUM-1] …

---

### Low Priority / Suggestions
[LOW-1] …

---

### Acceptance Criteria Coverage
[Omitted — no Jira story provided] OR:

| AC | Description | Implemented | Tested | Status |
|---|---|---|---|---|
| AC-1 | [text] | Yes — [method()] | Yes — [testMethod()] | PASS |
| AC-2 | [text] | Yes — [method()] | No | PARTIAL |
| AC-3 | [text] | No | No | FAIL |

---

### Positive Observations
- [specific thing done well — cite method/pattern]
- [another positive — be concrete, not generic]

---

### Summary
[2–3 sentences: overall quality assessment, most important action the developer must take, and whether this is ready to merge or needs another pass.]
```

---

## Severity Definitions

| Severity | Meaning | Merge impact |
|---|---|---|
| CRITICAL | Security, data integrity, or correctness risk | Blocks merge |
| HIGH | Violates a core standard; likely causes bugs or maintenance problems | Should fix before merge |
| MEDIUM | Reduces maintainability or traceability | Fix in follow-up ticket |
| LOW | Style preference or minor improvement | At developer's discretion |

**Overall verdict logic:**
- Any CRITICAL finding → `CHANGES REQUIRED`
- Two or more HIGH findings → `CHANGES REQUIRED`
- One HIGH finding or any MEDIUM findings → `APPROVED WITH COMMENTS`
- No findings above LOW → `APPROVED`

---

## Reference Implementations

When assessing whether code meets standards, compare against these files:

| Role | File |
|---|---|
| Service pattern | `DuplicateClaimDetectionService.java` |
| Controller pattern | `DuplicateClaimController.java` |
| Entity pattern | `ClaimPayment.java` |
| Repository pattern | `ClaimPaymentRepository.java` |
| Request DTO pattern | `DuplicateCheckRequest.java` |
| Response DTO pattern | `DuplicateCheckResponse.java` |
| Unit test pattern | `DuplicateClaimDetectionServiceTest.java` |
| Controller test pattern | `DuplicateClaimControllerTest.java` |
