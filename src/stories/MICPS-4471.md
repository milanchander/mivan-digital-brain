# MICPS-4471 — Near-Duplicate Claim Detection

| Field          | Value                                                    |
|----------------|----------------------------------------------------------|
| Issue Type     | Story                                                    |
| Priority       | High                                                     |
| Story Points   | 8                                                        |
| Sprint         | 47                                                       |
| Epic           | MICPS-4400 — Overpayment Prevention Wave 5              |
| Assignee       | COBOL: Marcus Delgado / Java: Priya Nair                |
| Status         | In Progress                                              |
| Component      | Adjudication / Overpayment                              |

## User Story

> As the Claims Integrity team, I want MiCPS to automatically detect near-duplicate
> claims — where the same member, provider, and CPT code appear with a date-of-service
> within ±1 day and a charge amount within 10% — so that we can pend them for review
> before payment, closing the $2–4M annual overpayment gap that exact-match detection
> currently misses.

## Background

`MOVPDUP0` (existing) catches only exact duplicates: identical member, NPI, CPT, DOS,
and charge amount. Audits identified a class of near-duplicate patterns — billing agents
shifting DOS by one day or rounding charges by a few percent — that slip through.
The Claims Integrity team estimates $2–4M annual overpayment exposure from these patterns.

## Acceptance Criteria

1. **AC-1 Charge variance ≤10%** — When an inbound claim has the same member/NPI/CPT as
   a paid claim and charge amounts differ by ≤10%, the claim is flagged as near-duplicate
   with `MATCH_TYPE = AMT-VAR`.

2. **AC-2 DOS drift ≤1 day** — When an inbound claim matches member/NPI/CPT and the
   date-of-service differs by exactly 1 day, flag as near-duplicate with
   `MATCH_TYPE = DATE-DRIFT`.

3. **AC-3 Modifier substitution** — When an inbound claim matches member/NPI/CPT/DOS
   but differs only in modifier code (e.g., `59` vs blank), flag as near-duplicate with
   `MATCH_TYPE = MODIFIER`.

4. **AC-4 Exact-duplicate skip** — Claims already flagged as exact duplicates by
   `MOVPDUP0` (`PAYMENT_STATUS_CD = 'ED'`) must be skipped to avoid double-counting.

5. **AC-5 Queue insertion** — All near-duplicate detections must be inserted into
   `MIVANCPS.NEAR_DUP_QUEUE` with `STATUS = 'P'` (pending review) and
   `PEND_REASON = 'NEAR-DUP-REVIEW'`.

6. **AC-6 15% charge variance = no flag** — Charge variances exceeding 10% are NOT
   flagged; they indicate distinct services or pricing errors beyond this scope.

7. **AC-7 2-day DOS drift = no flag** — DOS differences of 2 or more days are NOT
   flagged; only ±1-day drift is within the near-duplicate definition.

8. **AC-8 Shadow mode parity** — During the 30-day shadow window, the Java
   `DuplicateClaimDetectionService` must agree with COBOL `MOVPDUP1` on ≥99.99% of
   evaluated claims before COBOL retirement is considered.

## Technical Notes

### COBOL Track — `MOVPDUP1`
- New DB2 batch program, step STEP020 in job `MOVPAUD0` (runs after `MOVPDUP0`)
- Cursor `PAID-CLAIMS-CUR` — all PD claims
- Cursor `NEAR-DUP-CUR` — parameterised by member/NPI/CPT, DOS ±1 day, excluding inbound claim
- Copybooks: `CLMPAYRC.cpy`, `NDUPQREC.cpy`, `MOVPDUP1.cpy`
- Match priority: MODIFIER > DATE-DRIFT > AMT-VAR (EVALUATE TRUE order)
- ZUnit tests: `MOVPDUP1T.cbl` — 6 test cases

### Java Track — `DuplicateClaimDetectionService`
- Spring Boot 3.3.2 / Java 21, runs in shadow mode alongside COBOL
- Repository method `findPaidCandidates` mirrors `NEAR-DUP-CUR`
- `classifyMatch` mirrors COBOL EVALUATE order exactly
- JUnit 5 tests: TC-01 through TC-06 map 1-to-1 to ZUnit test cases

### New Table
- `MIVANCPS.NEAR_DUP_QUEUE` — see `src/cobol/DDL/NEAR_DUP_QUEUE.sql`
- SLA: pended claims reviewed within 30 days (`NDUP_CREATE_DT + 30`)

## Definition of Done

- [ ] `MOVPDUP1.cbl` compiles clean on Enterprise COBOL 6.4
- [ ] ZUnit suite `MOVPDUP1T` passes all 6 test cases
- [ ] `NEAR_DUP_QUEUE.sql` bound in DB2P
- [ ] JCL `MOVPDUP1.jcl` tested in batch region
- [ ] Java service passes all 13 JUnit 5 tests
- [ ] Shadow mode deployed; parity metrics visible in Grafana
- [ ] Claims Integrity team sign-off on sampled near-dup queue entries