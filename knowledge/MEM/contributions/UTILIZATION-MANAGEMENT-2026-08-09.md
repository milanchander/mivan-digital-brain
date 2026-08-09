---
layer: L2
node_type: domain
domain: claims
source: sme-interview
last_synced: 2026-08-09
validated_by: Milan Chander
fidelity: DRAFT
ghost_node_id: UTILIZATION-MANAGEMENT
---

# Utilization Management

## Services Requiring Prior Authorization

Prior authorization (PA) applies across a broad range of service categories for Mivan commercial members. The following table lists the major categories by type:

| Category | Notes |
|---|---|
| Advanced imaging | MRI, CT, PET, nuclear cardiology. Highest volume by request count. Frequently delegated to a radiology benefit manager. |
| Inpatient admissions | All elective/scheduled admissions. Emergency admissions are notification-only within 24–48 hours. |
| Outpatient surgical procedures | Spine, joint replacement, bariatric, and procedures where medical necessity vs. cosmetic determination is required. |
| Specialty pharmacy and injectables | Biologics, infusion therapy, oncology, specialty drugs under the medical benefit. High dollar, high growth. |
| Durable medical equipment (DME) | Power wheelchairs, CPAP/BiPAP, prosthetics, orthotics — typically above a dollar threshold. |
| Behavioral health | Inpatient psych, residential treatment, PHP, IOP, ABA therapy. |
| Skilled nursing and post-acute | SNF, IRF, LTAC, home health beyond initial visit allotment. |
| Sleep studies | In-lab polysomnography; home sleep test often required first. |
| Genetic and molecular testing | Hereditary cancer panels, pharmacogenomics, prenatal screening. Fast-growing category. |
| Transplant services | Evaluation through post-transplant. Low volume, very high dollar. |
| Out-of-network services | Any OON care where in-network alternatives exist. |

By volume, the top five categories are advanced imaging, specialty pharmacy, outpatient surgery, behavioral health, and DME — with imaging and specialty pharmacy accounting for the largest share of total requests.

---

## Clinical Criteria Sets for Medical Necessity

Mivan uses a hybrid model rather than a single vendor criteria set.

| Criteria set | Primary use |
|---|---|
| **MCG (Milliman Care Guidelines)** | Inpatient admissions, level of care, concurrent review, length-of-stay benchmarking |
| **InterQual** | Outpatient procedures, DME, post-acute (SNF, IRF, home health) |
| **Proprietary Clinical Coverage Policies (CCPs)** | Mivan-authored criteria supplementing or overriding vendor guidelines |

### When Proprietary CCPs Take Precedence

- Emerging technology and new procedure codes not yet addressed by vendor criteria
- Genetic and molecular testing (vendor criteria frequently lag new test introductions)
- Specialty drugs under the medical benefit — typically reference NCCN or Micromedex compendia
- Cosmetic vs. reconstructive determinations with Mivan-specific thresholds
- Services with state mandate implications requiring a plan-specific policy position

### Variation by Line of Business

| LOB | Criteria precedence |
|---|---|
| Commercial | Full hybrid model; plan has latitude to establish its own criteria |
| Medicare Advantage | CMS NCDs and LCDs take precedence. MCG/InterQual apply only where no NCD/LCD exists. Adjudicated in MiFCT. |
| Medicaid | State Medicaid criteria take precedence; varies by state contract. Some states mandate specific criteria sets. Adjudicated in MiFCT. |

Criteria sets are reviewed annually. MCG and InterQual release annual content updates that must be loaded and regression-tested. Proprietary CCPs go through a Medical Policy Committee with physician review before publication.

---

## Standard Prior Authorization Workflow

### Process Sequence

```
Provider submission (portal / EDI 278 / fax / phone)
        ↓
Intake and completeness check
  - Member eligible on service date
  - Provider active and credentialed
  - Service actually requires PA
  - Required clinical documentation attached
        ↓
Auto-approval screening
  - Clean pattern: in-network, criteria met automatically,
    no utilization flags
  - Mature plans auto-approve 40–60% of requests at this stage
        ↓
Nurse review (licensed RN)
  - Applies MCG / InterQual to submitted clinical documentation
  - CAN approve. CANNOT issue an adverse determination.
        ↓
Medical Director review (physician)
  - Only a physician may issue an adverse determination
  - Peer-to-peer typically offered before finalizing a denial
  - Outcomes: approve / deny / partial (fewer units, shorter duration,
    or alternative site of service)
        ↓
Notification (provider and member)
  - Denials must state clinical rationale, criteria applied,
    reviewer credentials, and full appeal rights
        ↓
Auth record written
  - Auth number, approved codes, units, valid date range,
    servicing provider
  - This is the record MAUTHCK0 reads at claim adjudication time
```

### Key Principle

A nurse can approve but cannot deny. Adverse determinations require physician review. This is a regulatory requirement in most states, not a plan-level courtesy.

### Decision Timeframes — Commercial

| Request type | Timeframe | Notes |
|---|---|---|
| Standard / non-urgent | 14 calendar days | Many states require shorter — 5–7 business days common |
| Urgent / expedited | 72 hours | Some states require 24 hours |
| Concurrent review (continued stay) | 24 hours | While member is admitted |
| Extension when information is missing | +14 days | Requires member notification |

Medicare Advantage follows CMS timeframes; Medicaid follows state-directed timeframes. Both are processed in MiFCT, not MiCPS.

---

## Denial Reasons and Appeal Process

### Clinical Denial Reasons

- **Criteria not met** — submitted clinical documentation does not satisfy MCG/InterQual thresholds. Largest single denial category.
- **Insufficient clinical documentation** — service may be appropriate but not demonstrated. Distinct from criteria-not-met; often resolved on resubmission.
- **Conservative therapy not attempted or documented** — common for spine, joint replacement, and bariatric. Requires documented failure of PT, injections, or medical management first.
- **Site of service** — approved, but not at the requested location. Results in a partial approval rather than outright denial.
- **Less costly alternative available** — step therapy requirements for specialty drugs.
- **Experimental or investigational** — insufficient evidence base or no FDA approval for the requested indication.
- **Diagnosis-procedure mismatch** — service not medically necessary for the submitted diagnosis.

### Administrative Denial Reasons

- Non-covered benefit (cosmetic most common)
- Member not eligible on service date
- Provider not in network
- Provider not credentialed or excluded (including OIG/SAM hits)
- Duplicate request
- PA not required (technically a rejection rather than a denial)

**Operating principle:** Administrative denials are typically fixable at intake and should not reach a Medical Director. Clinical denials consume physician review time and drive appeals. Reducing administrative denials through front-end validation lowers total review burden.

### Appeal Process — Commercial

| Level | Detail |
|---|---|
| **Level 1 — internal** | Filed within ~180 days of denial. Reviewed by a physician not involved in the original decision, same or greater clinical specialty. Timeframes: 30 days pre-service, 60 days post-service, 72 hours expedited. |
| **Level 2 — second internal** | Not universal. Some states mandate two internal levels before external review is available. Different reviewer required. |
| **External review — IRO** | Independent Review Organization with no financial relationship to Mivan. Decision is binding on the plan. ACA mandates availability for non-grandfathered plans. 45 days standard, 72 hours expedited. Plan bears cost regardless of outcome. |

**Expedited appeals** are available when standard timeframes would seriously jeopardize life, health, or ability to regain maximum function. May run concurrently with external review in urgent cases.

**ERISA overlay:** Self-funded (ASO) groups follow ERISA claims procedure regulations rather than state insurance law — different timelines, different notice requirements, and the member's ultimate remedy is federal court rather than a state DOI complaint. The same denial is handled through two distinct regulatory frameworks depending on whether the group is fully-insured or self-funded.

## Concurrent Review

### Triggers

**Automatic:**
- Any inpatient admission (commercial plans typically review all acute stays)
- Initial certification expiring (1–3 days typical for medical; longer for surgical based on MCG/InterQual expected LOS)
- Emergency admission notification within 24–48 hours
- Level-of-care change (ICU ↔ med/surg)
- Transfer between facilities

**Escalation triggers:**
- LOS exceeding MCG/InterQual benchmark for the DRG or condition
- High-dollar threshold breach
- Readmission within 30 days of a prior discharge
- Complex discharge planning needs identified early

### Who Conducts It

| Role | Scope |
|---|---|
| Concurrent review nurse | Licensed RN with acute care background. Collects clinical updates via phone with the hospital case manager, payer portal upload, or EHR access where a data-sharing arrangement exists. Applies continued-stay criteria. **Can approve additional days; cannot deny.** |
| Medical Director | Required for any adverse determination: denial of continued days, level-of-care downgrade, or determination that inpatient criteria are no longer met. Peer-to-peer offered first. |
| Hospital case manager | Direct counterpart at the facility. Quality of this relationship materially affects friction and denial volume. |

### Review Cadence

```
Admission
    ↓
Initial certification (1–3 days typical)
    ↓
Concurrent review at day of expiry
    ↓
Nurse collects clinical update
    ↓
Apply continued-stay criteria
    ↓
├── Criteria met → certify additional days → repeat
└── Criteria not met → Medical Director review
                       → peer-to-peer offered
                       → overturned: certify
                       → upheld: adverse determination
                         from a date certain forward
```

Review frequency typically every 1–3 days depending on acuity and staffing model.

### Timeframes

| Element | Standard |
|---|---|
| Concurrent review decision | 24 hours |
| Emergency admission notification | 24–48 hours from admission |
| Expedited appeal during stay | 72 hours, often faster |

### Discharge Planning Overlay

Concurrent review is not purely a denial function. The reviewer identifies post-acute needs early — SNF, home health, DME, infusion — and initiates those authorizations before discharge. In well-run programs this is the larger share of value: preventing avoidable days by removing discharge barriers rather than denying days after the fact.

### Financial Mechanics by Contract Type

An adverse concurrent determination does not retroactively deny the whole stay. It sets a date from which continued days are non-covered. The facility may appeal (expedited, while the member is still admitted), discharge the member, continue and absorb cost, or issue a member notice of non-coverage where the contract permits.

For DRG-paid facilities the impact of a denied day is muted — payment is per-discharge, not per-diem. For per-diem contracts every denied day is a direct revenue loss. Concurrent review friction correlates strongly with contract type.

---

## Retrospective Review

### When It Applies

| Trigger | Detail |
|---|---|
| No prior authorization obtained | Most common. Service required PA, none on file. Plan policy varies: outright administrative denial vs. retro review with a filing window (commonly 30–90 days post-service). The two paths carry **different appeal rights**. |
| Emergency and urgent care | Emergency services cannot require PA. Medical necessity assessed retrospectively under the prudent layperson standard. |
| Retroactive eligibility | Coverage added or reinstated after the service date. Common in Medicaid and COBRA reinstatements. |
| Post-payment audit findings | Claim paid, then flagged by a post-payment rules engine or SIU review. |
| Level-of-care disputes | Observation vs. inpatient. Frequently appealed; persistent payer-provider friction. |
| Delegated vendor reconciliation | Sample review for delegation oversight. |

### Decision Standard

Retrospective review is a chart review. The decision rests on the medical record **as it existed at the time of service** — not on outcome.

> A bad outcome does not make an approved service unnecessary. A good outcome does not make an unnecessary service justified.

The reviewer assesses: given what was known and documented at the time, was this service medically necessary?

**Records request:** typical response window 30–45 days. Non-response is itself a denial reason in most contracts — the provider bears the documentation burden.

**Criteria application:** same MCG/InterQual criteria as prospective review. Same escalation rule — nurse can approve, only a physician can deny.

### Outcome Paths

| Finding | Result |
|---|---|
| Medically necessary, no auth on file | Approve; pay or reprocess claim |
| Medically necessary, wrong level of care | Partial — reprice to appropriate level |
| Not medically necessary | Deny; recover if already paid |
| Records not received | Deny for insufficient documentation |

### Timeframes

| Element | Standard |
|---|---|
| Retro review decision | 30 days from receipt of complete information |
| Records request response window | 30–45 days |
| Provider filing window for retro auth | 30–90 days post-service (plan-specific) |
| Overpayment recovery look-back | State-specific; commonly 12–24 months commercial |

### Connection to the Overpayment Process

When retrospective review finds a paid claim was not medically necessary, the finding feeds the overpayment process:

```
Retro review adverse determination
        ↓
Overpayment record created
        ↓
Demand letter to provider
        ↓
Provider response window
        ↓
├── Agrees → refund or offset consent
├── Disputes → appeal process
└── No response → recoupment via offset
```

In MiCPS terms, retrospective review outcomes must reach the overpayment module — the same path that duplicate detection and COB errors feed.

### Provider Relations Dimension

Retrospective denial is the most contentious form of UM. The service is delivered, the cost incurred, and the plan asserts after the fact that it should not have been. Retro denial volume correlates directly with provider abrasion and contract negotiation friction. Well-run programs minimize retro review by making prospective authorization easy — the goal is to move review upstream, not to build retro capacity.

---

## Urgent and Expedited Prior Authorization

### Definitional Standard

A request qualifies for expedited handling when the standard timeframe would seriously jeopardize the member's life, health, or ability to regain maximum function — or, for a member with severe pain, would subject them to pain that cannot be adequately managed without the requested care. Standard derives from ACA and ERISA claims procedure regulations.

### Who Can Request It

| Requester | Rule |
|---|---|
| Treating physician | **When a physician requests expedited review, the plan must honor it.** The plan does not get to second-guess the urgency determination. Most commonly misunderstood rule among intake staff. |
| Member or authorized representative | Plan may apply the prudent layperson standard, but bias should be toward granting. |
| Plan-initiated | Intake staff or nurse may flag based on clinical presentation. |

If the plan declines expedited status, the request converts to the standard timeframe **and the plan must promptly notify the requester**. That notification is a regulatory obligation and a common audit finding when missed.

### Timeframes

| Scenario | Commercial standard |
|---|---|
| Expedited pre-service | 72 hours |
| Expedited concurrent (continued stay) | 24 hours |
| Expedited with incomplete information | 24 hrs to request info, then 48 hrs after receipt |
| Expedited appeal | 72 hours |
| Expedited external review (IRO) | 72 hours, binding |

Several states impose shorter windows — 24 hours for expedited pre-service is common. Whichever is shorter governs for fully-insured plans. Self-funded ERISA plans follow the federal standard unless the plan document commits to more.

### Operational Handling

- **Intake:** distinct path required. Portal should have an explicit expedited checkbox with a required clinical justification field. Phone and fax remain important — a physician calling about an urgent case should not be routed to a portal.
- **Routing:** bypasses the standard queue entirely. Direct to nurse reviewer with immediate Medical Director escalation if criteria are not clearly met.
- **After-hours:** 72 hours includes weekends and holidays; the clock does not pause. Requires extended-hours staffing or on-call nurse and Medical Director coverage. Most common point of failure — a Friday afternoon request with no weekend coverage breaches Monday morning.
- **Notification:** as expeditiously as the medical condition requires. Verbal notification followed by written confirmation is standard. Verbal-first matters; waiting for the letter defeats the purpose.

### Failure Modes

| Failure | Detail |
|---|---|
| Clock start ambiguity | Does the 72 hours run from receipt of request or from receipt of complete clinical? Regulations generally say from receipt of request, with a bounded extension. Plans treating the clock as starting only when documentation is complete are exposed on audit. |
| Silent downgrade | Request flagged expedited by the provider, processed as standard without notification. Common audit finding. |
| Weekend and holiday gaps | Most frequent cause of actual timeframe breaches. |
| Auth record lands late | Clinical decision made in 8 hours; auth record does not reach AUTH-FILE until overnight batch. Member receives care same day, claim arrives, MAUTHCK0 finds no auth. See Known Gaps section. |

---

## Known Gaps — UM-to-Claims Boundary

This section documents where UM and claims fail at their handoff. Each side may be individually correct; the gap lives between them. These are the highest-value items in this contribution.

### 8.1 — Auth Record Latency

UM approves an auth; the record reaches AUTH-FILE in the overnight batch. Any claim submitted before that batch completes finds no auth and denies. Highest impact on expedited approvals where care is often delivered the same day. UM measures the 72-hour decision. Claims reads a file that refreshes nightly. Nobody owns the interval.

**Retroactive auth backdating.** When an auth is granted after the service date — retro review approval, appeal overturn, retroactive eligibility — the auth record requires an effective date preceding its creation date. Whether MAUTHCK0 handles a backdated auth correctly, and whether previously denied claims automatically reprocess, is unknown. VALIDATE: behavior unconfirmed.

### 8.2 — Auth-to-Claim Matching Failures

The auth is valid; the claim denies anyway because match logic fails.

| Mismatch | Cause |
|---|---|
| Procedure code | Auth for planned CPT; different CPT performed |
| Units | Auth for 10 PT visits; provider bills 12 |
| Date range | Surgery rescheduled outside auth validity window |
| Servicing provider NPI | Auth issued to requesting physician; claim submitted by facility or different rendering provider |
| Modifier | Auth without modifier; claim submitted with -59 or -RT/-LT |

The rendering-vs-requesting NPI mismatch is both common and invisible — from the member's perspective the auth was approved and the claim denied for no discernible reason.

**MAUTHCK0 date tolerance** — already registered as a critical ghost node. Undocumented tolerance logic auto-approves claims falling within N days of auth expiry. VALIDATE: the value of N is unknown. **The plan does not currently know its own auth expiry behavior.**

### 8.3 — Delegated Vendor Auth Flow

Where a radiology benefit manager or specialty pharmacy manager owns the auth decision, their approval must reach AUTH-FILE for the claim to pay.

Failure points: vendor feed delayed or failed silently; vendor auth number format differs from Mivan's expected key structure; vendor approves at a different granularity than the claim requires.

When this breaks, the provider holds a valid authorization from the entity Mivan delegated to, and the claim denies. Provider abrasion is high because the provider did everything correctly.

### 8.4 — Partially Certified Inpatient Stays

Concurrent review certifies days 1–5 and denies days 6–8. The facility submits one institutional claim covering the full admission. VALIDATE: how MiCPS handles a single claim against a partial authorization — split, reduce, deny entirely, or pend for manual review — is undocumented. For DRG-paid facilities the financial impact differs entirely from per-diem contracts, which may mean the logic branches on contract type.

### 8.5 — Observation vs. Inpatient

Facility bills inpatient; plan asserts observation was appropriate. Generates retrospective review, denial, appeal, and frequently ends in negotiated settlement rather than clean adjudication. VALIDATE: whether a level-of-care downgrade reprices the claim automatically or requires manual intervention is unknown.

### 8.6 — Emergency Services and Prudent Layperson

Emergency services cannot require prior authorization, but retrospective medical necessity review is permitted. Applying that review too aggressively — denying based on final diagnosis rather than presenting symptoms — is both a regulatory exposure and an appeal driver. Chest pain that turns out to be reflux is still an emergency at presentation.

### 8.7 — No-Auth Handling Inconsistency

Whether a claim without a required auth is denied administratively or routed to retrospective review appears to vary. The two paths carry different appeal rights and different provider notification requirements. Inconsistent routing exposes the plan on appeal and makes the provider experience unpredictable.

### 8.8 — Appeal Overturn to Claim Reprocessing

When an appeal is won the auth is granted — but the claim already denied and may have been written off or balance-billed to the member. VALIDATE: what triggers reprocessing, who owns it, and whether it is automated or manual is unclear.

This is a member-harm path, not just an operational gap. A member balance-billed for a service that was ultimately authorized has a legitimate grievance and a plausible regulatory complaint.

### 8.9 — Auth Record Data Quality

- Criteria version applied at decision time not consistently captured — makes appeals and audits difficult to defend two years later
- Free-text denial rationale rather than structured reason codes — limits trend analysis and makes CARC mapping inconsistent
- Peer-to-peer outcomes not consistently recorded against the auth

### Priority Ranking

Ranked by combined financial exposure and member impact:

| Rank | Gap | Rationale |
|---|---|---|
| 1 | Auth record latency | Affects every expedited approval; systemic |
| 2 | Partially certified stays | High dollar, undocumented logic |
| 3 | Appeal overturn reprocessing | Direct member harm path |
| 4 | Delegated vendor auth flow | High provider abrasion, plan is at fault |
| 5 | MAUTHCK0 date tolerance | Unknown behavior in production |