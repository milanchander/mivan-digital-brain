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
  - Java developer 5-day onboarding curriculum
implements: []
links_back:
  - L2-domain/commercial-claims.md
  - L3-systems/mivan-system-landscape.md
  - L4-application/micps-application-knowledge.md
  - L5-business-rules/claims-business-rules.md
links_forward: []
ghost_nodes:
  - Spring Boot service deployment lab exercises
  - Shadow mode validation walkthrough exercises
  - Wave 1 cutover simulation exercises
---

# Mivan Digital Brain — 5-Day Training Agenda (Java Modernization Track)

Structured onboarding programme for Java developers and architects joining the MiCPS modernization programme. By Day 5 participants can use the Digital Brain to build, test, and review Spring Boot features that run in shadow mode alongside COBOL, with confidence in business rule parity before cutover.

---

## Day 1 — Domain Knowledge

Build foundational understanding of the claims domain from the perspective of the Java modernization effort.

| # | Topic | Layer | What You Will Learn |
|---|---|---|---|
| 1 | Claims Lifecycle | L2 | End-to-end claim journey from submission to payment; adjudication stages; denial and pend reason codes |
| 2 | Adjudication and Pricing | L2 | How MiCPS applies adjudication rules; pricing logic; coordination of benefits; near-duplicate detection and the $2–4M overpayment exposure |

**Outcome:** Participant can explain what a near-duplicate claim is, what business rules govern detection, and why identical logic must produce identical outputs in both COBOL and Java during the shadow period.

---

## Day 2 — System Architecture

Understand the modernization topology before writing a single line of Java.

| # | Topic | Layer | What You Will Learn |
|---|---|---|---|
| 1 | Modernization Architecture | L3 | Mainframe + AWS coexistence; Aurora PostgreSQL as DB2 mirror; EKS deployment for Java services; API gateway layer |
| 2 | Wave 1–5 Migration Sequence | L3 | Which modules migrate in which wave; dependencies between waves; cutover gates per wave |
| 3 | Coexistence Pattern | L3 | How COBOL and Java run simultaneously; shadow mode data flow; how discrepancies are detected and escalated |

**Outcome:** Participant can draw the coexistence architecture from memory, explain which systems own which data during the shadow period, and state the cutover gate condition (99.99% agreement over 30 consecutive days).

---

## Day 3 — Application Knowledge

Deep-dive into Wave 1 modules and the shadow mode validation framework.

| # | Topic | Layer | What You Will Learn |
|---|---|---|---|
| 1 | Wave 1 Modules | L4 | Scope of Wave 1 — which MiCPS programs are targeted; `DuplicateClaimDetectionService` as the reference implementation; CLAIM_PAYMENT and NEAR_DUP_QUEUE table schemas |
| 2 | Shadow Mode Validation | L4 | How shadow mode works technically; `ShadowModeValidator` harness; fixture file format; how to interpret the parity dashboard; what constitutes an acceptable discrepancy |

**Outcome:** Participant understands the full Wave 1 scope, can read the shadow mode parity metrics, and knows what action to take when parity drops below the gate threshold.

---

## Day 4 — Skills Activation

Learn to use the Digital Brain's four Java development skills on real work, in the order a developer would encounter them in a sprint.

| # | Skill | File | Practice Exercise |
|---|---|---|---|
| 1 | Java Feature Builder | `skills/java-feature-builder.md` | Paste a Jira story; follow the 8-step process; confirm the Step 1 analysis before generating code |
| 3 | Java Test Generator | `skills/java-test-generator.md` | Paste `DuplicateClaimDetectionService.java` + the MICPS-4471 story; generate the full test suite; compare against the 14 existing tests |
| 4 | Java Code Reviewer | `skills/java-code-reviewer.md` | Paste `DuplicateClaimDetectionService.java`; run the 6-dimension review; identify any gaps against the MICPS-4471 ACs |
| 2 | COBOL to Java Migrator | `skills/cobol-to-java-migrator.md` | Paste `MOVPDUP1.cbl`; follow the analysis step; compare the generated migration to the existing `DuplicateClaimDetectionService.java` |

**Outcome:** Participant has activated all four Java skills and can apply them independently to any MiCPS Wave 1–5 story.

---

## Day 5 — Live Code

Work with the running Spring Boot service and live Digital Brain knowledge.

| # | Activity | What You Will Do |
|---|---|---|
| 1 | Run DuplicateClaimDetectionService | Start the Spring Boot app (`mvn spring-boot:run`); seed `CLM-ORIG-001` via `POST /api/v1/claims/seed`; submit a near-duplicate via `POST /api/v1/claims/evaluate`; verify the response shows `NEAR_DUP` with correct `matchType` |
| 2 | Review 14 passing tests | Run `mvn test`; trace each of the 14 test methods to its corresponding AC in MICPS-4471; confirm all AC-1 through AC-8 are covered |
| 3 | Try Swagger UI | Open `http://localhost:8080/swagger-ui.html`; explore the Duplicate Detection API; execute the evaluate endpoint directly from the browser |
| 4 | Ask Digital Brain to compare MOVPDUP1 to Java service | Open the chat; ask "Compare the COBOL MOVPDUP1 business rules to the Java DuplicateClaimDetectionService — are they identical?"; verify the Digital Brain can identify any differences from the embedded source |

**Outcome:** Participant has run the full Java stack, verified test coverage against the story ACs, and confirmed the Digital Brain holds accurate, comparable knowledge of both the COBOL and Java implementations. Participant is ready for independent Wave 1–5 development.

---

## Prerequisites

- Access to Mivan Digital Brain portal: `https://milanchander.github.io/mivan-digital-brain`
- Claude Code installed and configured for this repository
- Java 21 and Maven installed locally (`C:\Users\[user]\tools\apache-maven-3.9.10`)
- `JAVA_HOME` set to Eclipse Adoptium JDK 21
- Basic Java and Spring Boot familiarity (REST, JPA, Lombok)
- No COBOL experience required

## Facilitator Notes

- Day 2 "Coexistence Pattern" is the conceptual pivot of the track. Spend extra time here — Java developers often underestimate how much the shadow period constrains their implementation choices.
- Day 4 Skills Activation runs in the order 1 → 3 → 4 → 2 intentionally: Feature Builder first so participants understand the generation target, Code Reviewer before Migrator so they know what good looks like before they see a migration.
- Day 5 Step 4 is the key moment: the Digital Brain answering the comparison question live, without James Whitfield. Let it run and let participants probe further.
- See also: `knowledge/L6-task-intelligence/5-day-training-agenda.md` for the parallel COBOL track.
