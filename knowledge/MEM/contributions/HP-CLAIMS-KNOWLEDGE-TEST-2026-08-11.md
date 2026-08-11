---
layer: MEM
node_type: extraction-draft
domain: claims
source: cobol-knowledge-extractor
program_id: HP-CLAIMS-KNOWLEDGE-TEST
ghost_node_id: none
synthetic: true
graduation: DO-NOT-GRADUATE
last_synced: 2026-08-11
fidelity: DRAFT
extraction_confidence: high
observable_findings: 41
inferred_findings: 2
program_size_lines: 30000
extraction_passes: 3
sections_fully_extracted: 1
sections_partial: 1
called_programs_not_supplied: 0
copybooks_not_supplied: 0
unresolved_dynamic_calls: 0
material_findings: 18
sme_confirmation_required: true
---

> **This is an extraction hypothesis, not verified knowledge.** Content marked
> OBSERVABLE is deterministically derived from source. Content marked INFERRED
> requires SME confirmation. **Additionally: this program is SYNTHETIC** — it
> self-declares `AUTHOR. MICROSOFT COPILOT SYNTHETIC GENERATOR` and
> `NOTE: THIS IS NOT PRODUCTION CODE AND CONTAINS NO REAL MEMBER DATA`. Its
> "business rules" are generated test fixtures, not real Mivan payer logic. Do
> **not** graduate this to L4/L5 and do not treat its codes, factors, or
> thresholds as authoritative. It maps to no ghost node.

# Extraction Summary — HP-CLAIMS-KNOWLEDGE-TEST

**Completeness first.** Extracted **1 of 2 sections fully** (the live
adjudication pipeline, lines 1–326) and **sampled** the second (the ~2,522
numbered rule paragraphs, lines 327–~29,988 — 12 read, the rest are templated
repetitions marked NOT FULLY EXTRACTED). **0 called programs and 0 copybooks**
were referenced — the program is fully self-contained (no `CALL`, `COPY`, DB2,
CICS, or MQ). **0 dynamic calls.** The Knowledge Boundary is therefore unusually
small — there is essentially nothing external to pull, which is itself evidence
of a synthetic artifact.

**Headline finding (OBSERVABLE, MATERIAL):** only **lines 1–326 (~1%)** of this
30,000-line file are live. The remaining **~98.7%** — 2,522 numbered rule
paragraphs plus `PAD-KNOWLEDGE-LINE-*` filler comments — is **unreachable dead
code**: it is defined *after* `9000-FINALIZE`/`GOBACK` and is never referenced by
any `PERFORM` (verified: 0 `PERFORM <RULE>-NNNNN` across the whole file). The
live program is a small, clean 8-stage claims-adjudication pipeline.

## Program Classification
- Target layer (were it real): L4/L5 (adjudication pipeline + business rules).
  **Actual: synthetic test artifact — not for graduation.**
- Processing mode: **Batch** (sequential file driver; no `EXEC CICS`).
- Related ghost node: **none**.

## Dependency Map

### Observable dependencies

| Dependency | Type | Direction | Evidence |
|---|---|---|---|
| `CLAIM-IN-FILE` (DD `CLMIN`) | LINE SEQUENTIAL file, `PIC X(420)` | reads | `0100-INITIALIZE`, `1100-READ-CLAIM` ~96,115 |
| `CLAIM-OUT-FILE` (DD `CLMOUT`) | LINE SEQUENTIAL, `PIC X(620)` | writes | `8000-WRITE-OUTPUT` ~300 |
| `DENIAL-RPT-FILE` (DD `DENRPT`) | LINE SEQUENTIAL, `PIC X(420)` | writes | `8100-WRITE-DENIAL-REPORT` ~310 |
| `AUDIT-TRAIL-FILE` (DD `AUDTRL`) | LINE SEQUENTIAL, `PIC X(620)` | writes | `8800-WRITE-AUDIT` ~318 |
| Called programs | — | — | **none** (0 `CALL`) |
| Copybooks | — | — | **none** (0 `COPY`; all data inline in WORKING-STORAGE) |
| DB2 / CICS / MQ | — | — | **none** (0 `EXEC` blocks) |

### Implicit dependencies (highest migration risk)
- **Fixed-position record parsing (`1200-PARSE-CLAIM`, ~120–137):** the 420-byte
  `CLAIM-IN-REC` is sliced by hardcoded offsets (`(001:018)`, `(019:018)`, …).
  *Assumption:* the upstream producer emits exactly this layout. *What breaks:*
  any field shift silently corrupts every downstream rule. *Enforced?* No —
  reference-modification with literal positions, no validation. (Synthetic, but a
  real instance of the layout-coupling hazard.)
- No cross-step file coupling, no shared VSAM, no CICS/batch state — genuinely
  self-contained.

## Business Logic

Lead with MATERIAL (money / eligibility / control-flow). All values below are
**OBSERVABLE**; their business rationale is **SYNTHETIC** (generated), not a real
fee schedule or policy.

### MATERIAL — live pipeline (lines 89–326)

**Control flow (0000-MAINLINE ~90):** `INITIALIZE → PROCESS-CLAIMS UNTIL EOF →
FINALIZE → GOBACK`. Per-claim pipeline (`1000` ~103): parse → `2000` eligibility
→ `3000` benefits → `4000` pricing → `5000` liability → `6000` COB → `7000` final
adjudication → `8000` output.

- **Eligibility (2000–2300):** missing member → deny `M001`; DOS `< 20200101` →
  deny `E101`; product `EVALUATE` `PPO001|HMO001|MCR001` → in-network, `OTHER` →
  pend `P201`; group `= 'TERMINATED'` → deny `G301`.
- **Benefits (3100–3500):** covered-service `EVALUATE` procedure
  `99385|99213|93000` or revenue `0450`, else deny `B401`; prior-auth trigger
  procedure `70553` or revenue `0360` → if auth not found, pend `A501`; benefit
  max `> 999999.99` → deny `B601`; duplicate flag → deny `D701`; billed
  `> 50000.00` → pend `F801` (SIU).
- **Pricing (4000–4200):** allowed `= billed × 0.6200`; out-of-network overrides
  to `× 0.4200`; fee-schedule by place-of-service `11→×1.00, 22→×1.10, 23→×1.25,
  OTHER→×0.95`; provider contract `PAR*` prefix `→ ×0.97` else `× 0.85`.
- **Member liability (5000–5300):** deductible `MIN(allowed, 1500.00 − member-ded-met)`
  while member-ded-met `< 1500.00`; copay by POS `11→25.00, 23→150.00, OTHER→0`;
  coinsurance `(allowed − deduct − copay) × 0.2000`, waived if member-OOP-met
  `> 7000.00`; paid `= allowed − deduct − copay − coins`, floored at 0.
- **COB (6000):** if COB flag set → paid `× 0.5000`.
- **Final adjudication (7000):** status `D→denied`, `P→pended`, else set `A` and
  `paid`. Counters displayed in `9000-FINALIZE`.
- **Output (8000/8100/8800):** pipe-delimited `STRING` into CLAIM-OUT, DENIAL-RPT
  (on `D`), and AUDIT-TRAIL (on every rule hit).

### MATERIAL — structural

1. **Dead code, ~98.7%.** 2,522 numbered rule paragraphs (lines 327+) are never
   `PERFORM`ed (0 references, verified whole-file) and sit after `GOBACK`.
   OBSERVABLE: unreachable.
2. **Dead rules diverge from live rules.** The dead templates echo the live
   semantics but with *different* hardcoded values — e.g. dead `PRIC-*` uses
   `× 0.8400` (live pricing uses `0.62/0.42`), dead `LIAB-*` adds coinsurance
   `× 0.1500` (live uses `0.20`), dead `RISK-*` triggers at `> 18000.00` (live
   SIU triggers at `> 50000.00`), and each dead denial/pend code embeds its rule
   number (`E101, B102, A103 … E109, B110`). If anyone ever wired these in, they
   would conflict with the live pipeline — a latent trap. OBSERVABLE divergence.

### NOTABLE
- No file-status checks after `OPEN`/`READ`/`WRITE` (no `FILE STATUS` clauses) —
  I/O errors are unhandled. `1100-READ-CLAIM` handles only `AT END`.
- `WS-COB-FLAG`, `WS-DUPLICATE-FLAG`, `WS-AUTH-FOUND-FLAG` are initialized `'N'`
  and never set to `'Y'` in the live path, so the COB, duplicate, and
  auth-found branches are effectively unreachable at runtime (data-driven dead
  paths within live code).

### INCIDENTAL
- `PAD-KNOWLEDGE-LINE-00001..29990` comment filler to reach 30,000 lines.
- 4 `DISPLAY` count lines in `9000-FINALIZE`.

## Hardcoded Values

| Value | Location (paragraph ~line) | Observable | Business rationale |
|---|---|---|---|
| Coverage window `20200101` | 2100-CHECK-COVERAGE-DATES ~154 | Yes | SYNTHETIC — not a real policy date |
| Product codes `PPO001/HMO001/MCR001` | 2200 ~161–164 | Yes | SYNTHETIC |
| Covered procs `99385/99213/93000`, rev `0450` | 3100 ~188–191 | Yes | SYNTHETIC (real-looking CPT/rev codes) |
| Auth triggers proc `70553`, rev `0360` | 3200 ~199 | Yes | SYNTHETIC |
| Benefit max `999999.99` | 3300 ~209 | Yes | SYNTHETIC |
| Fraud/SIU threshold `50000.00` | 3500 ~223 | Yes | SYNTHETIC |
| Pricing factors `0.62 / 0.42` | 4000 ~232–234 | Yes | SYNTHETIC fee logic |
| POS fee factors `1.00/1.10/1.25/0.95` | 4100 ~241–244 | Yes | SYNTHETIC |
| Contract factors `0.97 / 0.85` | 4200 ~248–250 | Yes | SYNTHETIC |
| Deductible `1500.00` | 5100 ~261–262 | Yes | SYNTHETIC |
| Copays `25.00 / 150.00` | 5200 ~268–269 | Yes | SYNTHETIC |
| Coinsurance `0.20`, OOP `7000.00` | 5300 ~273–274 | Yes | SYNTHETIC |
| COB factor `0.50` | 6000 ~279 | Yes | SYNTHETIC |

## Migration Risk Assessment

| Dimension | Rating | Basis |
|---|---|---|
| Coupling | LOW | No CALL/COPY/DB2/CICS/MQ; 4 flat files only |
| Implicit dependencies | LOW–MEDIUM | Only the fixed-offset input record layout |
| Business rule density | LOW (live) | ~34 live paragraphs; simple IF/EVALUATE |
| Documentation gap | N/A | Synthetic; generator comments state intent |
| Data layout opacity | LOW | All layouts inline, no missing copybooks |
| Tribal knowledge dependence | NONE | Generated, no SME involved |

**Overall: N/A — do not migrate.** This is a synthetic extraction-capability
test, not a Mivan asset. The meaningful engineering finding is that a 30,000-line
program contains ~326 lines of live logic; a real migration effort would first
run dead-code elimination and discover the true scope is ~1% of the file.

## Knowledge Boundary — what this extraction does NOT cover
- **Called programs not supplied:** none — the program issues no `CALL`. (The
  "what to pull next" list is empty.)
- **Copybooks not supplied:** none — no `COPY`; all data is inline.
- **Dynamic calls unresolved:** none.
- **Sections NOT FULLY EXTRACTED:** the 2,522 numbered rule paragraphs
  (lines 327–~29,988). I read rules `00001`–`00012` (one full 8-category cycle
  plus 4) and confirmed by sampling that they are templated repetitions cycling
  ELIG/BNFT/AUTH/PRIC/LIAB/COB/QUAL/RISK with incrementing codes. The remaining
  ~2,510 were **not read individually** — low materiality (dead code, templated).
- **REDEFINES/ODO undetermined:** none present.
- **Runtime behavior:** data-driven dead paths (COB/duplicate/auth-found) would
  need real input to confirm; irrelevant here as the file is synthetic.

## Open Questions for SME
*(For a synthetic file these are process questions, not payer questions.)*
1. Confirm intent: is this file only an extraction-capability benchmark? (Header
   says yes.) If so it should live outside the knowledge estate, not be graduated.
2. If the intent was to test dead-code detection: the extractor flags ~98.7% of
   the file as unreachable — is that the expected result?

## Suggested Shadow Mode Test Scenarios
*(Would validate a re-implementation of the LIVE pipeline only; the dead rules
are excluded because they never execute.)*

| # | Input | Expected (per live COBOL) | Paragraph | Oracle |
|---|---|---|---|---|
| S1 | member-id = spaces | deny `M001` | 2000 | OBSERVABLE |
| S2 | DOS `20191231` | deny `E101` | 2100 | OBSERVABLE |
| S3 | product `ZZZ999` | pend `P201` | 2200 | OBSERVABLE |
| S4 | group `TERMINATED` | deny `G301` | 2300 | OBSERVABLE |
| S5 | procedure not in covered set | deny `B401` | 3100 | OBSERVABLE |
| S6 | procedure `70553`, no auth | pend `A501` | 3200 | OBSERVABLE |
| S7 | billed `50000.01` | pend `F801` | 3500 | OBSERVABLE |
| S8 | in-network valid claim | allowed = billed×0.62 then POS/contract factors | 4000–4200 | OBSERVABLE |
| S9 | member-ded-met `1499.99` | deduct = MIN(allowed, 0.01) | 5100 | OBSERVABLE |
| S10 | POS `23` | copay `150.00` | 5200 | OBSERVABLE |

**Boundary conditions to test (at / just below / just above):** `20200101`
(coverage), `50000.00` (SIU), `18000.00` (dead RISK — excluded), `1500.00`
(deductible), `7000.00` (OOP), `999999.99` (benefit max).

---

*Extraction produced by the COBOL Knowledge Extractor skill (Skill 8). Source:
`health_payer_claims_knowledge_test_30000.cbl` (synthetic). Not for graduation;
no ghost node.*
