# Medicaid State Reporting Service — Java

Spring Boot 3 / Java 21 service that handles **post-adjudication** state
reporting for Medicaid claims. Medicaid claims are adjudicated by **MiFCT
(TriZetto Facets)**; this service is invoked afterward to meet state reporting
obligations — it is not a claim adjudication driver.

**Federal rule:** 42 CFR 433.139 — Medicaid is always payer of last resort.
All other insurers (employer-sponsored, Medicare, private) must pay before Medicaid pays.

## How This Fits in the Architecture

MiFCT (TriZetto Facets) adjudicates all Medicaid claims. This Java service is
called after adjudication to handle:

1. Third party liability identification
2. Payer of last resort calculation (42 CFR 433.139)
3. Medicaid liability calculation
4. State MMIS encounter data submission

## MiFCT Integration Context

| Java Component | Role (post-adjudication) |
|----------------|--------------------------|
| `MedicaidStateReportingService.java` | Post-adjudication orchestration; called after MiFCT adjudication |
| `MedicaidEligibilityService.java` | Confirms Medicaid eligibility |
| `ThirdPartyLiabilityService.java` | TPL identification (42 CFR 433.139) |
| `PayerOfLastResortService.java` | Medicaid liability calculation |
| `EncounterBuildService.java` | MMIS encounter builder |
| `StateSubmissionService.java` | State MMIS staging & submission |
| `MedicaidEligibility.java` | JPA entity — eligibility |
| `TplResult.java` | JPA entity — TPL result |
| `MedicaidLiability.java` | JPA entity — liability |
| `MedicaidEncounterStaging.java` | JPA entity — encounter staging |

## Key Regulatory Reference

**42 CFR 433.139 — Third Party Liability:**
> Medicaid must pay only what remains after all liable third parties have paid.
> MCOs must identify and pursue TPL as a condition of their state contract.

This rule is implemented in `PayerOfLastResortService.calculateMedicaidLiability()`:
```
medicaidAmt = max(0, billedAmt - tplPaidAmt - memberRespAmt)
```
BigDecimal is used for all monetary arithmetic — no floating point.

## Running Locally

```bash
./mvnw spring-boot:run
```

- Swagger UI: http://localhost:8083/swagger-ui.html
- H2 Console: http://localhost:8083/h2-console (JDBC URL: `jdbc:h2:mem:medicaiddb`)

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/v1/medicaid/state-reporting/process` | State reporting for a single claim |
| `POST` | `/api/v1/medicaid/state-reporting/batch` | State reporting for a batch |
| `GET`  | `/api/v1/medicaid/eligibility/{memberId}` | Get member eligibility |
| `GET`  | `/api/v1/medicaid/tpl/{memberId}` | Get TPL results for member |
| `GET`  | `/api/v1/medicaid/encounter-staging` | Get staged encounters by state |

## Post-Adjudication Flow

```
MiFCT (TriZetto Facets) adjudicates the Medicaid claim
  → MedicaidStateReportingService.processStateReporting(request)
  → MedicaidEligibilityService   (monthly churn, spend-down, CHIP, EPSDT, dual)
  → ThirdPartyLiabilityService   (42 CFR 433.139 — all other payers first)
  → PayerOfLastResortService     (billedAmt - tplPaid - memberResp, floor $0)
  → EncounterBuildService        (MMIS format, state edit checks)
  → StateSubmissionService       (state-specific rules from STATE_CONTRACT)
  → MedicaidClaimResponse
```

## State-Specific Rule Handling

Each state Medicaid program has unique requirements managed via `STATE_CONTRACT`:
- `TIMELY_FILING_DAYS` — maximum days from DOS to claim submission
- `ENCOUNTER_DUE_DAYS` — maximum days to submit encounter to state MMIS
- `CAPITATION_RATE` — monthly per-member payment to MCO

State rules are applied in `StateSubmissionService` and `PayerOfLastResortService`.

## Production Deployment

Set the `prod` profile and provide:
- `MEDICAID_DB_URL` — PostgreSQL JDBC URL
- `MEDICAID_DB_USER` / `MEDICAID_DB_PASSWORD` — via AWS Secrets Manager

```bash
java -Dspring.profiles.active=prod -jar medicaid-state-reporting-service.jar
```
