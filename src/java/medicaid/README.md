# Medicaid Claim Processing — Java

Spring Boot 3 / Java 21 implementation of the Medicaid claim processing pipeline.

**Federal rule:** 42 CFR 433.139 — Medicaid is always payer of last resort.
All other insurers (employer-sponsored, Medicare, private) must pay before Medicaid pays.

## COBOL-to-Java Mapping

| COBOL Program | Java Equivalent | Role |
|---------------|----------------|------|
| `MMCOCLDR0.cbl` | `MedicaidClaimOrchestrator.java` | Driver / orchestrator |
| `MMCOELV0.cbl` | `MedicaidEligibilityService.java` | Eligibility verification |
| `MMCOTPL0.cbl` | `ThirdPartyLiabilityService.java` | TPL identification (42 CFR 433.139) |
| `MMCOLRP0.cbl` | `PayerOfLastResortService.java` | Last resort calculation |
| `MMCOENC0.cbl` | `EncounterBuildService.java` | MMIS encounter builder |
| `MMCOSSUB0.cbl` | `StateSubmissionService.java` | State MMIS staging & submission |
| `MMCOELIG.cpy` | `MedicaidEligibility.java` | Eligibility copybook → JPA entity |
| `MMCOTPLR.cpy` | `TplResult.java` | TPL result copybook → JPA entity |
| `MMCOLIAB.cpy` | `MedicaidLiability.java` | Liability copybook → JPA entity |
| `MMCOENCR.cpy` | `MedicaidEncounterStaging.java` | Encounter copybook → JPA entity |

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
| `POST` | `/api/v1/medicaid/claims/process` | Process a single claim |
| `POST` | `/api/v1/medicaid/claims/batch` | Process a batch (equiv. to MMCOJB00) |
| `GET`  | `/api/v1/medicaid/eligibility/{memberId}` | Get member eligibility |
| `GET`  | `/api/v1/medicaid/tpl/{memberId}` | Get TPL results for member |
| `GET`  | `/api/v1/medicaid/encounter-staging` | Get staged encounters by state |

## Process Flow

```
MedicaidClaimRequest
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
java -Dspring.profiles.active=prod -jar medicaid-claim-processing.jar
```
