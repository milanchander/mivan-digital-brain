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

### Java Feature Builder
Location: `skills/java-feature-builder.md`

Activate this skill when a developer pastes a Jira story in MICPS format and asks to implement or build it. Read `skills/java-feature-builder.md` for the full skill definition before proceeding.

This skill enforces a structured 8-step generation process and will not generate code until the input story passes validation.

### COBOL to Java Migrator
Location: `skills/cobol-to-java-migrator.md`

Activate this skill when a developer provides a COBOL program and asks to migrate it, convert it to Java, or build the Java equivalent. Read `skills/cobol-to-java-migrator.md` for the full skill definition before proceeding.

This skill produces a production-quality Java 21 Spring Boot service with full paragraph-level traceability, a shadow mode validation harness, and migration notes. It will not generate code until copybook/schema gaps are acknowledged by the developer.

### Java Test Generator
Location: `skills/java-test-generator.md`

Activate this skill when a developer provides a Java class and asks to generate tests, write tests for it, or improve test coverage. Read `skills/java-test-generator.md` for the full skill definition before proceeding.

This skill produces a JUnit 5 test suite with happy path, boundary value, negative path, exception, acceptance criteria, and migration parity tests. The richer the context (Jira story, COBOL equivalent), the more complete the suite.

## Conventions

- Knowledge artifacts are Markdown files with YAML frontmatter (`layer`, `domain`, `source`, `last_synced`)
- Connector sync scripts are idempotent — safe to re-run
- Secrets and credentials go in `config/` and are never committed; use AWS Secrets Manager or environment variables
- Domain scope: **claims** and **provider** — scope all knowledge ingestion to these domains unless told otherwise
