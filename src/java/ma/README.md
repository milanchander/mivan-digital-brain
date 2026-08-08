# MA Encounter Processing — Java

Spring Boot 3 / Java 21 implementation of the Medicare Advantage encounter data pipeline.

## COBOL-to-Java Mapping

| COBOL Program | Java Equivalent | Role |
|---------------|----------------|------|
| `MAENCDR0.cbl` | `EncounterDataOrchestrator.java` | Driver / orchestrator |
| `MAELGCK0.cbl` | `MaEligibilityService.java` | Eligibility verification |
| `MAHCCVL0.cbl` | `HccValidationService.java` | HCC diagnosis validation |
| `MARAFCL0.cbl` | `RafCalculationService.java` | RAF score calculation |
| `MAENCBL0.cbl` | `EncounterBuilderService.java` | Encounter record builder |
| `MAEDPSUB0.cbl` | `EdpsSubmissionService.java` | EDPS submission |
| `MAENROLL.cpy`  | `MaEnrollment.java` | Enrollment copybook → JPA entity |
| `MAHCCREC.cpy`  | `MaHccRecord.java` | HCC record copybook → JPA entity |
| `MARAFSCR.cpy`  | `MaRafScore.java` | RAF score copybook → JPA entity |
| `MAENCSTG.cpy`  | `MaEncounterStaging.java` | Staging copybook → JPA entity |

## Running Locally

```bash
./mvnw spring-boot:run
```

- Swagger UI: http://localhost:8082/swagger-ui.html
- H2 Console: http://localhost:8082/h2-console (JDBC URL: `jdbc:h2:mem:maencdb`)

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/ma/encounters/process` | Process a single member |
| `POST` | `/api/ma/encounters/batch` | Process a batch of members |
| `GET`  | `/api/ma/encounters/staging/{contractId}/pending` | List pending encounters |
| `POST` | `/api/ma/encounters/staging/{contractId}/resubmit` | Re-submit pending to EDPS |

## Process Flow

```
Input (MBI list)
  → MaEligibilityService     (DB2 MA_ELIGIBILITY select)
  → HccValidationService     (DB2 MA_HCC_CROSSWALK join, hierarchy flag)
  → RafCalculationService    (demo score + HCC coefficient sum + LIS/dual adders)
  → EncounterBuilderService  (generate encounter ID, insert MA_ENCOUNTER_STAGING)
  → EdpsSubmissionService    (validate + mark SU, update staging table)
```

## Production Deployment

Set the `prod` profile and provide:
- `MA_DB_URL` — PostgreSQL JDBC URL
- `MA_DB_USER` / `MA_DB_PASSWORD` — via AWS Secrets Manager

```bash
java -Dspring.profiles.active=prod -jar ma-encounter-processing.jar
```
