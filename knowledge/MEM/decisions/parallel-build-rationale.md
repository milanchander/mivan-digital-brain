---
layer: MEM
node_type: decision
topic: Why COBOL and Java are built in parallel for MICPS-4471
date: 2026-08-07
captured_by: Milan Chander
status: validated
related_nodes:
  - knowledge/L3-systems/mivan-system-landscape.md
  - knowledge/L4-application/micps-application-knowledge.md
  - src/stories/MICPS-4471.md
ghost_node_id: null
graduation_target: knowledge/L3-systems/mivan-system-landscape.md (modernization architecture section)
---

# Decision — Parallel Build Approach for MICPS-4471

## Context
MICPS-4471 requires a new near-duplicate claim 
detection capability. Mivan is mid-modernization — 
MiCPS mainframe is still production but Wave 1 
cloud-native services are in flight. A decision 
was needed on whether to build in COBOL only, 
Java only, or both in parallel.

## Content
**Decision: Build in both COBOL and Java in parallel.**

Rationale:
1. The business needs the feature now — COBOL 
   delivers it on the current production platform 
   without waiting for the modernization program
2. The modernization program needs the Java version 
   ready for cutover — building it now means no 
   rework when Wave 5 reaches overpayment
3. The Digital Brain enables both developers to 
   work from the same knowledge context — the 
   parallel build cost is lower than it would 
   have been without AI-native tooling
4. Shadow mode validation requires both 
   implementations to exist simultaneously — 
   this story produces them

**Outcome:**
- MOVPDUP1.cbl — COBOL implementation, 
  production-ready, deployed to MiCPS TEST
- DuplicateClaimDetectionService.java — 
  Java implementation, 13 tests passing, 
  ready for shadow mode validation

## Open Questions
None — decision implemented and validated.

## Action Required
Graduate to L3 modernization architecture 
section as a documented pattern for all 
future Wave 1-5 stories.

## Graduation Checklist
- [x] Validated by domain SME
- [x] Open questions resolved
- [x] Target layer identified
- [ ] Not yet merged to L3 — pending next L3 update
