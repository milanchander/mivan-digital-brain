# MA Post-Adjudication Reporting Service — Java

Spring Boot 3 / Java 21 service that handles **post-adjudication** CMS reporting
for Medicare Advantage claims. MA claims are adjudicated by **MiFCT (TriZetto
Facets)**; this service is invoked afterward to meet CMS reporting obligations —
it is not a claim adjudication driver.

## How This Fits in the Architecture

MiFCT (TriZetto Facets) adjudicates all Medicare Advantage claims. This Java
service is called after adjudication to handle:

1. CMS EDPS encounter data submission
2. HCC diagnosis validation and mapping
3. RAF score calculation
4. Encounter record staging for CMS submission

## MiFCT Integration Context

| Step | Java Component | Role (post-adjudication) |
|------|----------------|--------------------------|
| Entry point | `MaPostAdjudicationService.java` | Post-adjudication orchestration; called by MiFCT via REST after adjudication |
| Eligibility | `MaEligibilityService.java` | Confirms MA enrollment/eligibility |
| HCC validation | `HccValidationService.java` | HCC diagnosis validation and mapping |
| RAF calculation | `RafCalculationService.java` | RAF score calculation |
| Encounter build | `EncounterBuilderService.java` | Stages encounter records for CMS |
| EDPS submission | `EdpsSubmissionService.java` | Submits encounter data to CMS EDPS |
| `MaEnrollment.java` | JPA entity | MA_ENROLLMENT |
| `MaHccRecord.java` | JPA entity | MA_HCC diagnosis record |
| `MaRafScore.java` | JPA entity | MA_RAF_SCORE |
| `MaEncounterStaging.java` | JPA entity | MA_ENCOUNTER_STAGING |

## Running Locally

```bash
./mvnw spring-boot:run
```

- Swagger UI: http://localhost:8082/swagger-ui.html
- H2 Console: http://localhost:8082/h2-console (JDBC URL: `jdbc:h2:mem:maencdb`)

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/v1/ma/post-adjudication/process` | Post-adjudication reporting for a single member |
| `POST` | `/api/v1/ma/post-adjudication/batch` | Post-adjudication reporting for a batch |
| `GET`  | `/api/v1/ma/raf-scores/{memberId}` | RAF scores calculated for a member |
| `GET`  | `/api/v1/ma/encounter-staging` | Encounter records staged for CMS EDPS |

## Post-Adjudication Flow

```
MiFCT (TriZetto Facets) adjudicates the MA claim
  → MaPostAdjudicationService.processPostAdjudication(...)
  → MaEligibilityService     (confirm MA enrollment)
  → HccValidationService     (HCC diagnosis validation + crosswalk)
  → RafCalculationService    (demographic score + HCC coefficient sum + LIS/dual adders)
  → EncounterBuilderService  (stage MA_ENCOUNTER_STAGING records)
  → EdpsSubmissionService    (submit to CMS EDPS, mark SU)
```

## Production Deployment

Set the `prod` profile and provide:
- `MA_DB_URL` — PostgreSQL JDBC URL
- `MA_DB_USER` / `MA_DB_PASSWORD` — via AWS Secrets Manager

```bash
java -Dspring.profiles.active=prod -jar ma-post-adjudication-service.jar
```
