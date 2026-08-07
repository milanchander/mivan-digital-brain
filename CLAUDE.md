# Mivan Digital Brain

## Project Overview

AI-native knowledge layer for Mivan Health Plan, instantiated from Accenture's proven Digital Brain framework. Targets Mivan Health Plan's claims and provider applications, surfacing structured organizational knowledge through MCP-based connectors and a layered knowledge architecture.

## Knowledge Architecture (L1–L6)

| Layer | Name | Description |
|-------|------|-------------|
| L1 | Enterprise | Organization-wide policies, standards, and principles |
| L2 | Domain | Claims and provider domain knowledge, terminology, and rules |
| L3 | Systems | Architecture of Mivan Health Plan's systems — APIs, data models, integrations |
| L4 | Application | Application-specific behavior, configs, and runbooks |
| L5 | Business Rules | Adjudication rules, eligibility logic, provider network rules |
| L6 | Task Intelligence | Step-by-step procedural knowledge for recurring developer and QE tasks |

Knowledge lives under `knowledge/L{1-6}-*/`.

## MCP Connectors

Connectors ingest and sync knowledge from source systems into the appropriate knowledge layers. Each connector lives under `connectors/<system>/`.

| Connector | Source | Primary Layers |
|-----------|--------|----------------|
| Jira | Mivan Jira | L6 (task patterns, ticket history) |
| GitHub | Mivan GitHub | L3, L4 (code, runbooks, ADRs) |
| ServiceNow | Mivan ServiceNow | L5, L6 (incidents, change records) |
| Confluence | Mivan Confluence | L1, L2, L3 (docs, architecture, domain knowledge) |

## Agent Harnesses

- `harnesses/developer/` — AI harness for software engineers: code context, runbooks, ADR lookup, PR assistance
- `harnesses/qe/` — AI harness for QE: test strategy, defect patterns, coverage gaps

## Target Infrastructure

- **Cloud**: AWS (Mivan-managed)
- **Primary domains**: Claims processing, Provider applications

## Directory Structure

```
mivan-digital-brain/
├── CLAUDE.md
├── config/                   # Environment and harness configuration
├── connectors/
│   ├── confluence/
│   ├── github/
│   ├── jira/
│   └── servicenow/
├── harnesses/
│   ├── developer/
│   └── qe/
└── knowledge/
    ├── L1-enterprise/
    ├── L2-domain/
    ├── L3-systems/
    ├── L4-application/
    ├── L5-business-rules/
    └── L6-task-intelligence/
```

## Skills

This project has seven Claude Code skills. Claude Code automatically activates the appropriate skill based on developer intent.

Always read the relevant skill file completely before activating it. Never skip the validation or analysis steps defined in each skill.

### Java Skills

#### Skill 1 — Java Feature Builder
File: `skills/java-feature-builder.md`
Activate when: Developer pastes a Jira story and says "implement this" or "build this feature"

#### Skill 2 — COBOL to Java Migrator
File: `skills/cobol-to-java-migrator.md`
Activate when: Developer provides a COBOL program and says "migrate this" or "convert to Java"

#### Skill 3 — Java Test Generator
File: `skills/java-test-generator.md`
Activate when: Developer provides a Java class and says "generate tests" or "write tests for this"

#### Skill 4 — Java Code Reviewer
File: `skills/java-code-reviewer.md`
Activate when: Developer provides Java code and says "review this" or "code review"

### COBOL Skills

#### Skill 5 — COBOL Feature Builder
File: `skills/cobol-feature-builder.md`
Activate when: Developer pastes a Jira story and says "implement this in COBOL" or "build this COBOL feature"

#### Skill 6 — COBOL Test Generator
File: `skills/cobol-test-generator.md`
Activate when: Developer provides a COBOL program and says "generate tests", "write ZUnit tests for this", or "improve test coverage"

#### Skill 7 — COBOL Code Reviewer
File: `skills/cobol-code-reviewer.md`
Activate when: Developer provides COBOL code and says "review this", "code review", or "check this COBOL"

## Conventions

- Knowledge artifacts are Markdown files with YAML frontmatter (`layer`, `domain`, `source`, `last_synced`)
- Connector sync scripts are idempotent — safe to re-run
- Secrets and credentials go in `config/` and are never committed; use AWS Secrets Manager or environment variables
- Domain scope: **claims** and **provider** — scope all knowledge ingestion to these domains unless told otherwise
