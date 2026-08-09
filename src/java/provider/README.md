# Provider Data Validation — Java (Spring Boot)

Java equivalent of the **MPRVVLDR0** COBOL program tree from the MiCPS
Provider domain. Runs the five-step provider validation sequence — NPI lookup,
credentialing, exclusion screening, network verification, and mandatory
sanction logging — behind a REST API.

This is the parallel-build counterpart to `src/cobol/provider/`.

## COBOL → Java program mapping

| COBOL program | Role | Java equivalent |
|---------------|------|-----------------|
| `MPRVVLDR0` | Validation driver | `orchestrator/ProviderValidationOrchestrator` |
| `MPRVNPI0`  | NPI lookup | `service/ProviderNpiLookupService` |
| `MPRVCRD0`  | Credentialing check | `service/CredentialingCheckService` |
| `MPRVEXC0`  | Exclusion check (OIG/SAM/state) | `service/ExclusionCheckService` |
| `MPRVNET0`  | Network verification | `service/NetworkVerificationService` |
| `MPRVSANL0` | Sanction logging (always runs) | `service/SanctionLogService` |
| `MPRVJB00.jcl` | 5-step batch job stream | `POST /api/v1/provider/validate` |

### Copybook → entity mapping

| COBOL copybook | DB2 table | JPA entity |
|----------------|-----------|------------|
| `MPRVMSTR` | `PROVIDER_MASTER` | `model/ProviderMaster` |
| `MPRVCRED` | `PROVIDER_CREDENTIAL` | `model/ProviderCredential` |
| `MPRVEXCL` | `OIG_EXCLUSION_LIST` (+ SAM / state) | `model/OigExclusionList`, `SamExclusionList`, `StateExclusionList` |
| `MPRVNETW` | `NETWORK_CONTRACT` | `model/NetworkContract`, `NetworkTier` |
| `MPRVVLDR` | (working storage) | `model/ProviderValidationResponse` |
| — | `PROVIDER_SANCTION_LOG` | `model/ProviderSanctionLog` |

## PROV-MSTR VSAM vs Aurora PostgreSQL

On the mainframe, `MPRVNPI0` reads the **`PROV-MSTR` VSAM KSDS** keyed on NPI,
falling back to the DB2 `PROVIDER_MASTER` table on a VSAM miss. In the target
AWS state there is no VSAM tier: the provider master is a single
**Aurora PostgreSQL** table (`provider_master`), read through
`ProviderMasterRepository`. The keyed-read + DB2-fallback logic collapses into
one indexed primary-key lookup. Dev/test runs against in-memory **H2** in
PostgreSQL-compatibility mode, seeded from `schema.sql`.

## OIG exclusion compliance requirement

⚠️ **Federal law (42 USC 1320a-7b, 42 CFR 1001.1901) prohibits payment by any
federal healthcare program to, or on behalf of, a provider on an exclusion
list.**

- `ExclusionCheckService` screens OIG LEIE, SAM, and state Medicaid lists plus
  the local provider-master flag. A single hit short-circuits validation and
  blocks payment.
- `SanctionLogService` **always** writes a `PROVIDER_SANCTION_LOG` row —
  matching COBOL `STEP050` (`COND=EVEN`) — so a complete audit trail exists for
  every provider evaluated for payment. This step is never skipped.

## Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/v1/provider/validate` | Full five-step validation |
| POST | `/api/v1/provider/validate/facets` | **Facets integration (Option A)** — validate provider for MA/Medicaid claims |
| GET  | `/api/v1/provider/{npi}` | Provider master record |
| GET  | `/api/v1/provider/{npi}/credentials` | Credentialing status |
| GET  | `/api/v1/provider/{npi}/network-status` | INN/OON + tier |
| GET  | `/api/v1/provider/exclusions/check/{npi}` | Exclusion screen |
| GET  | `/api/v1/provider/sanctions/{npi}` | Sanction / validation history |

### MiFCT (Facets) Integration — Option A

Provider validation is cross-LOB and shared by both claims platforms. **MiCPS**
(commercial, COBOL) calls the `MPRVVLDR0` batch program; **MiFCT** (TriZetto
Facets, adjudicating MA and Medicaid) calls the REST endpoint directly:

```
POST /api/v1/provider/validate/facets
```

This is the **Option A** integration — MiFCT calls the shared
`ProviderValidationOrchestrator` over HTTP after LOB routing. The request
(`FacetsValidationRequest`) carries the Facets transaction ID, NPI, tax ID,
date of service, LOB code (`MA`/`MC`), claim ID, and plan ID; the response
(`FacetsValidationResponse`) returns validation status, network tier, fee
schedule, credentialing/exclusion flags, and deny reason. The underlying
validation is identical to commercial — provider validation is LOB-agnostic.

## How to run

```bash
cd src/java/provider
mvn spring-boot:run
```

- Swagger UI: <http://localhost:8081/swagger-ui.html>
- H2 console: <http://localhost:8081/h2-console> (JDBC URL `jdbc:h2:mem:providerdb`)

Seed data (`schema.sql`) includes a valid in-network provider
(`1234567893`), an out-of-network provider (`1987654320`), and an
OIG-excluded provider (`1122334455`) for exercising each path.

Example:

```bash
curl -X POST http://localhost:8081/api/v1/provider/validate \
  -H "Content-Type: application/json" \
  -d '{"npi":"1122334455","dateOfService":"2026-08-01"}'
# -> status: EXCLUDED, exclusionSource: OIG-LEIE
```

## Shadow mode validation for Wave 2

For Wave 2 cutover this service runs in **shadow mode**: production claims are
fed to both `MPRVVLDR0` (COBOL, system of record) and this service in parallel,
and the two `ProviderValidationResponse` outcomes are compared. The Java path
takes over as system of record only after outcomes match within the agreed
tolerance across the shadow window — exclusion determinations must match
**100%**, given the compliance exposure. Discrepancies are triaged against the
COBOL paragraph and Java service in the mapping table above.

## Build config

- **Group ID**: `com.mivan.provider`
- **Artifact ID**: `provider-validation`
- **Java**: 21
- **Stack**: Spring Boot Web, Spring Data JPA, PostgreSQL driver, Lombok,
  SpringDoc OpenAPI, Spring Boot Test (JUnit 5 + Mockito)
