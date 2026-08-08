---
layer: MEM
node_type: memory-index
domain: all
last_synced: 2026-08-08
---

# Memory Layer — MEM
## Mivan Digital Brain — Ripple-Free Capture Buffer

> The MEM layer is schema-exempt. Content here 
> does not need to conform to L1-L6 structure.
> It is a capture buffer for knowledge that is 
> not yet ready for a formal layer.
>
> MEM is where knowledge STARTS — not where it ends.
> Every MEM entry should eventually graduate to 
> a formal layer or be explicitly retired.

## What Goes Here

| Type | Description | Example |
|---|---|---|
| decision | Architecture or design decisions | Why we chose Aurora over RDS |
| sme-session | Notes from James Whitfield or other SME sessions | ACCUM-FILE layout notes from 2026-08-07 |
| draft | Business rules or specs not yet validated | Draft COB payer agreement mapping |
| incident | Post-incident notes and retrospectives | ADJUD-MAIN ABEND root cause analysis |
| field-note | Observations from code reading or system exploration | VSAM CI/CA size observations |

## Index of MEM Entries

| File | Type | Topic | Date | Status |
|---|---|---|---|---|
| decisions/aws-deployment-approach.md | decision | Backend deployment to AWS | 2026-08-08 | draft |
| decisions/parallel-build-rationale.md | decision | Why COBOL and Java built in parallel | 2026-08-08 | validated |
| sme-sessions/README.md | index | SME session template | 2026-08-08 | template |

## Graduation Criteria

A MEM entry graduates to a formal layer when:
- It has been validated by a domain SME
- It is stable enough to be referenced by other nodes
- It has a clear home in L1-L6

A MEM entry is retired when:
- It has been superseded by a formal layer node
- It was incorrect and has been corrected elsewhere
- It is no longer relevant
