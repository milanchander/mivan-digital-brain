---
layer: META
node_type: routing-map
domain: all
last_synced: 2026-08-08
validated_by: Milan Chander
fidelity: DRAFT
---

# CKF Routing Map
## Mivan Digital Brain — Context Selection System

> This file defines how questions are routed 
> to knowledge. The Digital Brain loads ONLY 
> the files on the traversal path for a given 
> question class — not the entire knowledge base.
>
> Target: load less than 1% of the knowledge 
> estate per question.
>
> Current estate size: ~6 files × avg 50KB = ~300KB
> Target context per question: ~100KB max
> Progressive disclosure: improves as estate grows

---

## Question Class Definitions

### Q01 — Onboarding
**Trigger phrases:** "I am new", "getting started", 
"what should I know", "help me understand",
"I just joined", "where do I start"

**Traversal by role:**

COBOL Developer:
1. knowledge/L1-enterprise/mivan-enterprise-context.md
2. knowledge/L2-domain/health-payer-domain.md
   → sections: claims-lifecycle, adjudication-engine
3. knowledge/L3-systems/mivan-system-landscape.md
   → sections: micps-architecture, cics, vsam, db2
4. knowledge/L4-application/micps-application-knowledge.md
   → sections: module-3-adjudication, technical-debt
Max context: 120KB

Java Developer:
1. knowledge/L1-enterprise/mivan-enterprise-context.md
2. knowledge/L2-domain/health-payer-domain.md
   → sections: claims-lifecycle, adjudication-engine, pricing
3. knowledge/L3-systems/mivan-system-landscape.md
   → sections: modernization-architecture, coexistence-pattern
4. knowledge/L4-application/micps-application-knowledge.md
   → sections: wave-1-modules, technical-debt
Max context: 120KB

QE Engineer:
1. knowledge/L2-domain/health-payer-domain.md
   → sections: claims-lifecycle, denial-codes
2. knowledge/L3-systems/mivan-system-landscape.md
   → sections: batch-feed-architecture, feed-failure-handling
3. knowledge/L4-application/micps-application-knowledge.md
   → sections: technical-debt, known-complexity
Max context: 100KB

Tech Lead:
1. knowledge/L1-enterprise/mivan-enterprise-context.md
2. knowledge/L3-systems/mivan-system-landscape.md (full)
3. knowledge/L4-application/micps-application-knowledge.md
   → sections: technical-debt, migration-risk
Max context: 150KB

Business Analyst:
1. knowledge/L1-enterprise/mivan-enterprise-context.md
2. knowledge/L2-domain/health-payer-domain.md (full)
3. knowledge/L3-systems/mivan-system-landscape.md
   → sections: micps-functional-modules
Max context: 100KB

Non-Health (Complete Beginner):
1. knowledge/L2-domain/health-primer.md [GHOST]
2. knowledge/L2-domain/health-payer-domain.md
   → sections: claims-lifecycle
3. knowledge/L1-enterprise/mivan-enterprise-context.md
   → sections: organization-overview, transformation-mandate
Max context: 80KB

---

### Q02 — How It Works
**Trigger phrases:** "how does X work", "explain X",
"walk me through X", "what happens when X",
"describe X", "what is X"

**Traversal:**
1. Identify domain from question (claims/provider/eligibility/COB/payment/overpayment)
2. Load L2 section matching domain
3. Load L3 system section matching domain
4. Load L4 module matching domain
5. Skip unrelated sections

Examples:
- "How does adjudication work" → L2 adjudication + L3 batch + L4 module-3
- "How does ACCUM-FILE work" → L3 VSAM section + L4 module-2 eligibility
- "How does shadow mode work" → L3 modernization + L1 transformation
Max context: 120KB

---

### Q03 — Why Decided
**Trigger phrases:** "why was X designed", "why does X",
"what was the reason for", "why not Y instead",
"what drove the decision"

**Traversal:**
1. Load L4 module owning X (known-complexity or technical-debt)
2. Load L5 business rules (relevant section)
3. Load MEM/decisions/ (any decision matching topic)
4. Skip operational and reference content

Examples:
- "Why is adjudication last to migrate" → L4 module-3 migration-status + MEM/decisions
- "Why parallel build for MICPS-4471" → MEM/decisions/parallel-build-rationale.md
Max context: 80KB

---

### Q04 — Impact Assessment
**Trigger phrases:** "what breaks if", "impact of changing",
"what depends on X", "downstream of X",
"what calls X", "what reads X"

**Traversal:**
1. Load L4 module owning X (programs, tables, VSAM files)
2. Load L3 integration landscape (downstream consumers)
3. Load L3 batch feed architecture (feed dependencies)
4. Load L3 feed dependency map
5. Load L6 task intelligence if available (known incidents)

Examples:
- "What breaks if ACCUM-FILE format changes" → L4 module-2 + L3 integration + L3 feeds
- "What depends on MADJDRV0" → L4 module-3 + L3 batch job streams
Max context: 150KB

---

### Q05 — Operational Response
**Trigger phrases:** "ABEND", "incident", "alert fired",
"job failed", "what do I do when", "how do I fix",
"production issue", "oncall"

**Traversal:**
1. Load L3 batch feed architecture (failure handling, retry)
2. Load L3 feed dependency map (what is downstream)
3. Load L4 module owning the failing component
4. Load L6 task intelligence (incident patterns) [GHOST]

Examples:
- "ADJUD-MAIN ABENDed at 2am" → L3 failure handling + L4 module-3 + L6
- "S3 feed not arrived" → L3 feed failure handling + L3 dependency map
Max context: 100KB

---

### Q06 — Compliance
**Trigger phrases:** "HIPAA", "CMS", "regulatory",
"what are the rules", "are we compliant",
"audit", "requirement"

**Traversal:**
1. Load L5 business rules (relevant section)
2. Load L2 domain (regulatory context — claims lifecycle)
3. Load MEM/decisions (any compliance decisions)

Examples:
- "What are the HIPAA requirements for claims" → L5 + L2 claims lifecycle
- "CMS overpayment rules" → L5 overpayment + L2 overpayment
Max context: 100KB

---

### Q07 — Currency Check
**Trigger phrases:** "is X still", "is this current",
"who owns X now", "has X changed",
"latest version of X"

**Traversal:**
1. Read frontmatter of owning node only
   (last_validated, validated_by, fidelity fields)
2. Load MEM/decisions (any superseding decision)
3. Do NOT load full file content

Examples:
- "Is the DRG rate table current" → frontmatter of L4 module-4
- "Who owns MADJDRV0 documentation" → frontmatter of L4 module-3
Max context: 40KB

---

### Q08 — Provenance
**Trigger phrases:** "where did this come from",
"what is the source", "was this validated",
"how do we know this is accurate"

**Traversal:**
1. Read frontmatter fidelity ledger of owning node
   (source_count_declared, source_count_captured, validated_by)
2. Load MEM/sme-sessions (any session addressing this node)
3. Do NOT load full file content

Max context: 40KB

---

### Q09 — Coverage Check
**Trigger phrases:** "what do we not know",
"what is missing", "gaps in knowledge",
"what is undocumented", "ghost nodes"

**Traversal:**
1. Load knowledge/ghost-nodes.md (full file)
2. Scan frontmatter ghost_nodes fields
   across all L4 nodes

Max context: 60KB

---

### Q10 — Audit History
**Trigger phrases:** "what changed", "when was X changed",
"who changed X", "commit history",
"what was different before"

**Traversal:**
1. Git log for relevant files
2. Load MEM/decisions (change rationale)

Max context: 60KB

---

## Routing Logic for the Portal

When the Digital Brain receives a question it should:

1. Classify the question into one of Q01-Q10
2. If Q01 — identify the role from context
3. Load ONLY the files on the traversal path
4. Never load more than max_context_kb for the class
5. Cite the specific file and section that answers

Current implementation status:
- Classification: MANUAL (agent reads this file and self-classifies)
- Traversal: MANUAL (agent uses Read/Grep tools guided by this map)
- Token enforcement: NOT YET IMPLEMENTED
- Target: automated classification + traversal engine in Level 3

---

## Estate Coverage

| Layer | Files Built | Ghost Nodes | Fidelity |
|---|---|---|---|
| L1 | 1 | 0 | HIGH |
| L2 | 1 | 4 (MA, Medicaid, Provider, UM) | PARTIAL |
| L3 | 1 | 2 (batch detail, intraday) | HIGH |
| L4 | 1 | 6 (adjud rules, ACCUM, DRG, COB, AUTH, FEE-SCHED) | PARTIAL |
| L5 | 1 | 2 (state rules, regulatory) | PARTIAL |
| L6 | 0 | 1 (task intelligence) | GHOST |
| MEM | 3 | 0 | DRAFT |
