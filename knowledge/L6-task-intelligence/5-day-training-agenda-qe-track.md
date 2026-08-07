---
layer: L6
node_type: reference
domain: claims
app_id: micps
last_validated: 2026-08-07
validated_by: "Digital Brain — pending SME review"
fidelity: COMPLETE
source_count_declared: 4
source_count_captured: 4
owns:
  - QE engineer 5-day onboarding curriculum
implements: []
links_back:
  - L2-domain/health-payer-domain.md
  - L3-systems/mivan-system-landscape.md
  - L4-application/micps-application-knowledge.md
  - L5-business-rules/claims-business-rules.md
links_forward: []
ghost_nodes:
  - ZUnit regression test library for trainees
  - End-to-end test data generation guide
  - Performance test scenario library
---

# Mivan Digital Brain — 5-Day Training Agenda (QE Track)

Structured onboarding programme for QE engineers joining the MiCPS testing programme. By Day 5 participants can use the Digital Brain to generate comprehensive test suites for both COBOL and Java, identify coverage gaps against acceptance criteria, and produce regression tests from known production complexity areas — without requiring James Whitfield to explain the business rules.

---

## Day 1 — Domain Knowledge

Build the domain foundation QE engineers need before they can write meaningful tests.

| # | Topic | Layer | What You Will Learn |
|---|---|---|---|
| 1 | Full Claims Lifecycle | L2 | End-to-end claim journey: submission → intake → adjudication → payment → reconciliation; which systems touch the claim at each stage; what can go wrong at each transition |
| 2 | Denial Codes and CARC/RARC | L2 | Claim Adjustment Reason Codes (CARC) and Remittance Advice Remark Codes (RARC); MiCPS-specific pend reason codes (including `NEAR-DUP-REVIEW`); how denial codes map to business rules that need test coverage |

**Outcome:** Participant can read a claim denial reason code and identify which adjudication rule it represents, which MiCPS program applies it, and what test scenario would validate the correct outcome.

---

## Day 2 — System Architecture

Understand the technical landscape so test data setup and teardown is tractable.

| # | Topic | Layer | What You Will Learn |
|---|---|---|---|
| 1 | Batch Job Streams | L3 | How MiCPS batch jobs are structured; job dependencies and COND codes; how test data flows through a batch run; what constitutes a complete end-to-end test cycle |
| 2 | Feed Architecture | L3 | Inbound and outbound feed formats; EDI 837 inbound claims; 835 remittance outbound; how feed failures manifest and what test coverage they need |

**Outcome:** Participant can describe the full `MOVPAUD0` job stream (MOVPDUP0 → MOVPDUP1 → MOVPDEM0 → MADJPND0), explain what test data is needed at each step, and identify which feeds need regression coverage.

---

## Day 3 — Test Landscape

Identify where the highest-risk testing gaps are before picking up any skill.

| # | Topic | Layer | What You Will Learn |
|---|---|---|---|
| 1 | Known Complexity Areas | L4 | Which MiCPS modules have the highest cyclomatic complexity; where boundary conditions are most likely to cause defects; adjudication engine edge cases that have caused production incidents |
| 2 | Technical Debt — Highest Risk Modules | L4 | Modules with no or inadequate test coverage; programs where the only "test" is James Whitfield's memory; risk-ranked list of coverage gaps the QE programme must close |

**Outcome:** Participant has a prioritised list of the top 10 untested or under-tested business rules in MiCPS, and understands which of these the Digital Brain can generate test cases for immediately.

---

## Day 4 — Skills Activation

Learn to use both test generation skills — one for Java, one for COBOL — on real code.

| # | Skill | File | Practice Exercise |
|---|---|---|---|
| 3 | Java Test Generator | `skills/java-test-generator.md` | Paste `DuplicateClaimDetectionService.java` + the MICPS-4471 story; generate the full JUnit 5 suite; compare the output against the 14 existing tests; identify any gaps |
| 6 | COBOL Test Generator | `skills/cobol-test-generator.md` | Paste `MOVPDUP1.cbl`; generate a ZUnit test programme; compare against `MOVPDUP1T.cbl`; verify boundary tests exist for the 10% charge tolerance and 1-day DOS threshold |

**Activation order:** Run Skill 3 first. The Java test output gives QE engineers a mental model of the expected business rule coverage before they look at the COBOL equivalent. This makes Skill 6 output easier to evaluate for completeness.

**Outcome:** Participant has generated both a JUnit 5 suite and a ZUnit test programme from live MiCPS source, and can articulate the coverage gaps between what was generated and what exists today.

---

## Day 5 — Live Testing

Run the actual test suites, examine the ZUnit structure, and push the Digital Brain to generate beyond what already exists.

| # | Activity | What You Will Do |
|---|---|---|
| 1 | Run all 14 JUnit tests | Run `mvn test` in `src/java/duplicate-detection`; confirm `Tests run: 14, Failures: 0, Errors: 0`; map each test method name to its corresponding AC in MICPS-4471; identify which test covers which boundary condition |
| 2 | Review ZUnit test structure | Open `src/cobol/MOVPDUP1T.cbl`; trace TC-01 through TC-06; verify each test case maps to an AC; check that boundary values (exactly 10%, exactly 1 day) are tested; identify any missing negative-path tests |
| 3 | Ask Digital Brain to generate additional edge case tests | Open the chat; ask "Generate additional edge case tests for DuplicateClaimDetectionService that are not already covered by the existing 14 tests — focus on boundary values and null inputs"; evaluate the output against the analysis from Days 3 and 4 |

**Outcome:** Participant has run the live test suite, evaluated its coverage against the story ACs, and used the Digital Brain to extend coverage into edge cases that the original developer did not anticipate. Participant is ready to lead QE for MiCPS Wave 1–5 stories.

---

## Prerequisites

- Access to Mivan Digital Brain portal: `https://milanchander.github.io/mivan-digital-brain`
- Claude Code installed and configured for this repository
- Java 21 and Maven installed locally for Day 5 Step 1
- Familiarity with JUnit 5 concepts (not required to write tests — only to read them)
- No COBOL experience required

## Facilitator Notes

- Day 3 is the most strategically important session for the QE programme. The "highest risk modules" list should be updated from the most recent production incident log before the session runs.
- Day 4 ordering (Java before COBOL) is intentional — Java test output is more readable for engineers not familiar with ZUnit syntax, and primes them to recognise good coverage patterns before evaluating the COBOL equivalent.
- Day 5 Step 3 is the key demonstration: the Digital Brain extending a test suite beyond what the original developer wrote. Ask participants to evaluate whether the generated edge cases would have caught known production defects.
- See also: `knowledge/L6-task-intelligence/5-day-training-agenda.md` (COBOL developer track) and `knowledge/L6-task-intelligence/5-day-training-agenda-java-track.md` (Java developer track).
