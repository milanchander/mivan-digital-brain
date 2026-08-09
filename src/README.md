# MICPS-4471 — Near Duplicate Claim Detection
## AI-Native Parallel Build Demo

This directory documents the complete delivery of **MICPS-4471**, the near-duplicate
claim detection story for the MiCPS adjudication system. Two developers built two
independent implementations — one in IBM Enterprise COBOL, one in Spring Boot Java —
simultaneously, guided entirely by the **Mivan Digital Brain** knowledge portal, without
a single conversation with the system's principal author, James Whitfield.

---

## Program Trees & Government Claims Architecture

The Digital Brain models four lines of business. Only **Commercial** claims are
adjudicated inside MiCPS; **Medicare Advantage** and **Medicaid** claims are
adjudicated by **MiFCT (TriZetto Facets)**, with Java services handling the
post-adjudication reporting obligations.

### Government Claims Architecture

MA and Medicaid claims are adjudicated by MiFCT (TriZetto Facets). The Java
services in this repository are invoked *after* adjudication to meet downstream
reporting obligations:

- **MA** → CMS EDPS encounter data submission, HCC diagnosis validation, RAF score calculation
- **Medicaid** → third party liability identification, payer of last resort (42 CFR 433.139), state MMIS encounter submission

These are **not** claim adjudication drivers — MiFCT owns adjudication for
government lines of business.

### Program Tree Summary

| Line of Business | Primary Component | Implementation |
|---|---|---|
| Commercial | `MCOMCLDR0` | COBOL + Java equivalent *(planned — not yet built)* |
| Medicare Advantage | `MaPostAdjudicationService` | Java only (post-adjudication reporting after MiFCT) |
| Medicaid | `MedicaidStateReportingService` | Java only (post-adjudication reporting after MiFCT) |
| Provider (cross-LOB) | `ProviderValidationOrchestrator` | Java only |

---

## 1. The Business Problem

MiCPS already catches **exact** duplicate claims through `MOVPDUP0`: same member,
provider, CPT code, date-of-service, and charge amount. But billing agents have learned
to introduce tiny variations — shift the DOS by one day, round the charge by a few
dollars — and the exact-match check lets them through.

The Claims Integrity team's 2026 Q2 audit identified **$2–4M in annual overpayment
exposure** from this pattern. The fix is a second-pass program, `MOVPDUP1`, that runs
immediately after `MOVPDUP0` and catches near-duplicates within these tolerances:

| Dimension       | Tolerance            |
|-----------------|----------------------|
| Date-of-service | ± 1 day              |
| Charge amount   | ≤ 10% variance       |
| Modifier code   | Any mismatch         |

Claims that pass within tolerance are inserted into `MIVANCPS.NEAR_DUP_QUEUE`
with status `P` (pending review) for the Claims Integrity team to adjudicate.

---

## 2. The Story — MICPS-4471

**Epic:** MICPS-4400 — Overpayment Prevention Wave 5
**Sprint:** 47 | **Points:** 8 | **Priority:** High

8 acceptance criteria covering: charge variance detection (AC-1), DOS drift detection
(AC-2), modifier substitution (AC-3), exact-dup skip (AC-4), queue insertion (AC-5),
and two negative cases — >10% variance is NOT flagged (AC-6), >1-day drift is NOT
flagged (AC-7) — plus shadow-mode parity gate (AC-8, 99.99% over 30 days).

Full Jira story: [`src/stories/MICPS-4471.md`](stories/MICPS-4471.md)

---

## 3. Track 1 — COBOL Build

**Developer:** Marcus Delgado (mainframe engineer, 2 years on MiCPS, first time touching
the overpayment module)

### Files Built

| File | Description |
|------|-------------|
| `cobol/COPYBOOKS/CLMPAYRC.cpy` | Host variable layout for `MIVANCPS.CLAIM_PAYMENT` (12 fields, COMP-3 packed decimals) |
| `cobol/COPYBOOKS/NDUPQREC.cpy` | Record layout for `MIVANCPS.NEAR_DUP_QUEUE` insertion |
| `cobol/COPYBOOKS/MOVPDUP1.cpy` | Working storage: counters, DOS range fields, 10% tolerance constant, 88-level flags |
| `cobol/DDL/NEAR_DUP_QUEUE.sql` | DB2 for z/OS DDL — STOGROUP, TABLESPACE, TABLE, 3 indexes, grants |
| `cobol/MOVPDUP1.cbl` | Main batch program — dual cursors, EVALUATE TRUE match classifier, DB2 INSERT/UPDATE |
| `cobol/MOVPDUP1.jcl` | 4-step IKJEFT01 job: MOVPDUP0 → MOVPDUP1 → MOVPDEM0 → MADJPND0 with COND codes |
| `cobol/MOVPDUP1T.cbl` | ZUnit test suite — 6 test cases (TC-01 to TC-06), PASS/FAIL report, RC=8 on any failure |

### How the Digital Brain Helped

Marcus had never worked in the overpayment module. He used the Digital Brain to:

- **L2 (Data):** Look up the exact field names and PIC clauses for `CLAIM_PAYMENT` without
  reading 3,000 lines of existing copybooks
- **L3 (Technical):** Understand MiCPS cursor patterns and the IKJEFT01/DSN RUN card
  convention used across all MiCPS batch jobs
- **L4 (Architecture):** Confirm the STEP020 insertion point in `MOVPAUD0` and understand
  why `COND=(8,LE,STEP010)` is the right guard (not `(0,NE)`)
- **L5 (Decision history):** Learn why the exact-dup check (`'ED'` skip) must come first
  — a prior incident where double-counting inflated the overpayment report by 12%

Total time to first clean compile: **4 hours**. James Whitfield was not contacted.

---

## 4. Track 2 — Java Build

**Developer:** Priya Nair (Java/Spring Boot engineer, new to MiCPS, assigned to build
the shadow-mode validation service)

### Files Built

```
src/java/duplicate-detection/
├── pom.xml                          Spring Boot 3.3.2, Java 21, H2/PostgreSQL
├── src/main/java/com/mivan/micps/
│   ├── DuplicateDetectionApplication.java
│   ├── model/
│   │   ├── ClaimPayment.java        JPA entity mirroring CLAIM_PAYMENT table
│   │   ├── NearDupQueue.java        JPA entity mirroring NEAR_DUP_QUEUE table
│   │   └── MatchType.java           Enum: DATE_DRIFT, AMT_VAR, MODIFIER, COMBINED
│   ├── repository/
│   │   ├── ClaimPaymentRepository.java   findPaidCandidates() mirrors NEAR-DUP-CUR
│   │   └── NearDupQueueRepository.java
│   ├── service/
│   │   └── DuplicateClaimDetectionService.java   Core logic + EvaluationResult record
│   └── controller/
│       └── DuplicateClaimController.java         POST /api/v1/claims/evaluate
└── src/test/...                     13 JUnit 5 tests (9 service + 4 MockMvc)
```

### How to Run Locally

```bash
export JAVA_HOME="C:/Program Files/Eclipse Adoptium/jdk-21.0.12.8-hotspot"
export PATH="$JAVA_HOME/bin:$PATH"
cd src/java/duplicate-detection
mvn spring-boot:run
```

App starts on **http://localhost:8080** with H2 in-memory database.

| Endpoint | URL |
|----------|-----|
| Swagger UI | http://localhost:8080/swagger-ui.html |
| API docs | http://localhost:8080/api-docs |
| H2 Console | http://localhost:8080/h2-console |
| Health | http://localhost:8080/actuator/health |

### API Endpoint

```
POST /api/v1/claims/evaluate
Content-Type: application/json

{
  "claimId": "CLM-NEW-002",
  "memberId": "MBR-12345",
  "provNpi": "1234567890",
  "dosFrom": 20260720,
  "cptCd": "99213",
  "chargeAmt": 327.00,
  "paymentStatusCd": "PD"
}
```

Response:
```json
{ "claimId": "CLM-NEW-002", "outcome": "NEAR_DUP",
  "matchedClaimId": "CLM-ORIG-001", "matchType": "AMT_VAR" }
```

### How to Run Tests

```bash
mvn test
```

Expected output:
```
Tests run: 13, Failures: 0, Errors: 0, Skipped: 0
BUILD SUCCESS
```

---

## 5. Shadow Mode

Before COBOL `MOVPDUP1` is declared production-authoritative and the Java service is
retired (or vice versa, if the migration timeline accelerates), both implementations
run in parallel against the same claims volume.

### Validation Architecture

```
Inbound Claims Batch
        │
        ├──► MOVPDUP1 (COBOL)  ──► NEAR_DUP_QUEUE (DB2)
        │                              │
        └──► Java Service      ──► shadow_results (Aurora)
                                       │
                                  Comparison Job (nightly)
                                       │
                              Grafana dashboard: parity %
```

### Cutover Gate

| Metric | Threshold |
|--------|-----------|
| Agreement rate | ≥ 99.99% over 30 consecutive days |
| Disagreement investigation | 100% of mismatches explained before cutover |
| Claims Integrity sign-off | Required on 500-claim random sample |

Disagreements are categorised:
- **Type A** — Java flags, COBOL misses: potential COBOL bug, escalate immediately
- **Type B** — COBOL flags, Java misses: potential Java bug, fix before cutover
- **Type C** — Both flag, different `MATCH_TYPE`: classifier alignment issue, acceptable
  if business outcome (pend vs. pass) is identical

---

## 6. The Digital Brain's Role

> *"I built the whole thing without pinging James once. Every question I had — why
> the DOS tolerance is ±1 and not ±2, what COND=(8,LE) means vs (0,NE), which
> copybook has the CHARGE-AMT PIC clause — the answer was already in the portal."*
>
> — Marcus Delgado, after first clean compile

The Digital Brain's five knowledge layers each played a specific role in this delivery:

| Layer | Content | Used for |
|-------|---------|----------|
| L1 Business | Claims adjudication rules, overpayment definitions | Understanding the $2–4M problem and the ±1 day / 10% thresholds |
| L2 Data | `CLAIM_PAYMENT` schema, `NEAR_DUP_QUEUE` DDL, VSAM layouts | Getting field names, PIC clauses, and column types exactly right on first attempt |
| L3 Technical | COBOL patterns, cursor conventions, Spring Boot JPA mappings | Writing idiomatic MiCPS code rather than generic COBOL or generic Spring |
| L4 Architecture | Batch job topology, shadow mode design, DB2 plan binding | Inserting STEP020 correctly, designing the comparison architecture |
| L5 Decision history | Why exact-dup check precedes near-dup check; prior incident log | Avoiding the double-counting bug that hit Wave 3 |

**James Whitfield** is MiCPS's principal architect. He holds 14 years of institutional
knowledge about adjudication edge cases, VSAM KSDS access patterns, and DB2 bind
procedures. For Wave 5, he was on extended leave. The Digital Brain distilled his
knowledge into the five layers above — and two developers who had never touched the
overpayment module shipped a complete, tested, shadow-ready implementation in one sprint.