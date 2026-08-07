---
layer: L6
domain: claims
source: internal
last_synced: 2026-08-07
---

# Mivan Digital Brain — 5-Day Training Agenda

Structured onboarding programme for MiCPS developers and QE engineers using the Mivan Digital Brain. By Day 5 participants can use the Digital Brain to build, test, and review production-quality COBOL and Java code without consulting James Whitfield.

---

## Day 1 — Domain Knowledge

Build foundational understanding of the claims domain before touching any code.

| # | Topic | Layer | What You Will Learn |
|---|---|---|---|
| 1 | Claims Lifecycle | L2 | End-to-end claim journey from submission to payment; adjudication stages; denial codes |
| 2 | Adjudication Engine | L2 | How MiCPS applies business rules; rule priority; pend queue mechanics |
| 3 | COB and Overpayment | L2 | Coordination of Benefits logic; overpayment detection patterns; $2–4M leakage context |

**Outcome:** Participant can explain what a near-duplicate claim is, why it causes overpayment, and what MOVPDUP0 does and does not catch.

---

## Day 2 — System Architecture

Understand the technology landscape before reading any source code.

| # | Topic | Layer | What You Will Learn |
|---|---|---|---|
| 1 | MiCPS Architecture | L3 | System landscape; mainframe + cloud topology; data flows between MiCPS, Aurora, and downstream systems |
| 2 | CICS and Batch Processing | L3 | When CICS transactions are used vs batch JCL; job streams; batch window constraints |
| 3 | VSAM and DB2 | L3 | VSAM file types (KSDS, ESDS, RRDS); DB2 z/OS subsystem; schema ownership; cursor patterns |

**Outcome:** Participant can read a JCL job stream, identify which programs run in which order, and explain the difference between VSAM and DB2 access patterns.

---

## Day 3 — Application Knowledge

Deep-dive into the specific MiCPS modules relevant to claims integrity work.

| # | Topic | Layer | What You Will Learn |
|---|---|---|---|
| 1 | Module 3 — Adjudication Engine | L4 | MOVPDUP0/MOVPDUP1 program structure; CLAIM_PAYMENT and NEAR_DUP_QUEUE tables; pend reason codes |
| 2 | Module 1 — Claims Intake | L4 | Inbound claim formats; EDI 837 mapping; how claims enter MiCPS before adjudication |
| 3 | Technical Debt — James Whitfield Risks | L4 | Key-person dependency analysis; undocumented knowledge areas; bus factor mitigations |

**Outcome:** Participant understands the full MOVPAUD0 job stream, can locate any MiCPS program in the system landscape, and knows which knowledge gaps the Digital Brain was built to close.

---

## Day 4 — Skills Activation

Learn to use the Digital Brain's three COBOL development skills on real work.

| # | Skill | File | Practice Exercise |
|---|---|---|---|
| 5 | COBOL Feature Builder | `skills/cobol-feature-builder.md` | Paste a Jira story; follow the validation and analysis steps; generate a COBOL program skeleton |
| 6 | COBOL Test Generator | `skills/cobol-test-generator.md` | Paste MOVPDUP1.cbl; generate a ZUnit test program; compare against MOVPDUP1T.cbl |
| 7 | COBOL Code Reviewer | `skills/cobol-code-reviewer.md` | Paste MOVPDUP1.cbl; run a full 8-dimension review; identify what would need changing before migration |

**Outcome:** Participant has activated all three COBOL skills and received at least one generated program, one ZUnit test suite, and one code review report.

---

## Day 5 — Live Code

Work with real production artifacts in the Digital Brain.

| # | Activity | What You Will Do |
|---|---|---|
| 1 | Review MOVPDUP1.cbl | Open the COBOL Code Reviewer skill; paste MOVPDUP1.cbl; receive the full 8-dimension review report including migration readiness rating |
| 2 | Ask Digital Brain to explain every paragraph | Open the chat; ask "Explain each paragraph of MOVPDUP1 and what business rule it implements"; verify the Digital Brain can answer from the embedded source |
| 3 | Run MOVPDUP1T ZUnit tests | Review the ZUnit test program; trace each TC-01 through TC-06 test case against the corresponding acceptance criteria in MICPS-4471; confirm all 6 test cases have passing logic |

**Outcome:** Participant has verified that the Digital Brain holds complete, accurate knowledge of MOVPDUP1 and can answer detailed questions about it without James Whitfield. Participant is ready for independent development on MiCPS stories.

---

## Prerequisites

- Access to Mivan Digital Brain portal: `https://milanchander.github.io/mivan-digital-brain`
- Claude Code installed and configured for this repository
- Read access to `src/cobol/` and `src/java/` directories
- No prior COBOL experience required for Days 1–3; basic COBOL familiarity helpful for Days 4–5

## Facilitator Notes

- Day 3 Module "Technical Debt — James Whitfield Risks" is the most sensitive session. Frame it as a knowledge resilience exercise, not a personnel discussion.
- Day 4 exercises work best when participants use a real in-flight story from the current sprint, not the MICPS-4471 example.
- Day 5 is intentionally open-ended — the goal is to break the Digital Brain, not to follow a script. Encourage participants to ask questions it might not know.
