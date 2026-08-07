# 05 — Subagents (Multi-Agent Delegation)

## What Are Subagents?

Subagents let your main AI session delegate specialized tasks to focused agents. Each subagent has its own prompt, tool access, and role — but shares the parent session's authentication and model.

```
Main Agent (orchestrator)
    │
    ├── "researcher" subagent    → Read, Grep, Glob
    ├── "writer" subagent        → Read, Write, Edit
    ├── "analyst" subagent       → Bash, Read, Grep
    └── "browser" subagent       → Playwright MCP tools
```

## Defining Subagents

```python
from claude_agent_sdk import AgentDefinition

# Each subagent has: description, prompt, tools
researcher = AgentDefinition(
    description=(
        "Research specialist. Use when you need to find information "
        "in the knowledge base, search files, or gather context before "
        "making decisions."
    ),
    prompt="""You are a research specialist. Your job is to find relevant
information in the codebase and knowledge base.

When given a research task:
1. Use Glob to find relevant files by pattern
2. Use Grep to search for specific terms
3. Use Read to examine file contents
4. Synthesize findings into a clear summary

Be thorough. Check multiple locations. Report what you found AND what
you didn't find (absence of information is also valuable).""",
    tools=["Read", "Grep", "Glob", "Skill", "ToolSearch"],
)

writer = AgentDefinition(
    description=(
        "Content writer. Use when you need to create or edit documents, "
        "generate reports, or write code."
    ),
    prompt="""You are a content creation specialist. You write clear,
concise, well-structured content.

When creating content:
1. Read existing files for context and style
2. Write new content matching the existing style
3. Edit files precisely using the Edit tool
4. Verify changes by reading the file after editing""",
    tools=["Read", "Write", "Edit", "Grep", "Glob"],
)

analyzer = AgentDefinition(
    description=(
        "Data analysis specialist. Use when you need to run commands, "
        "analyze output, process data, or perform calculations."
    ),
    prompt="""You are a data analysis specialist. You process information
methodically and produce structured insights.""",
    tools=["Bash", "Read", "Grep", "Glob"],
)
```

## Registering Subagents

Pass subagents as a dict to `ClaudeAgentOptions.agents`:

```python
from claude_agent_sdk import ClaudeAgentOptions

ALL_AGENTS = {
    "researcher": researcher,
    "writer": writer,
    "analyst": analyzer,
}

options = ClaudeAgentOptions(
    model="claude-sonnet-4-6",
    setting_sources=["user", "project", "local"],
    permission_mode="bypassPermissions",
    agents=ALL_AGENTS,
    allowed_tools=["Read", "Grep", "Glob", "Agent", "Skill", "ToolSearch"],
    max_turns=100,
)
```

**CRITICAL**: Include `"Agent"` in `allowed_tools` — otherwise the main agent cannot delegate to subagents.

## Key Rules

### 1. Never hardcode `model` on subagents

```python
# WRONG — locks subagent to a specific model
researcher = AgentDefinition(
    model="claude-sonnet-4-6",  # DON'T DO THIS
    ...
)

# CORRECT — subagent inherits model from parent session
researcher = AgentDefinition(
    description="...",
    prompt="...",
    tools=["Read", "Grep", "Glob"],
    # No model= field — inherits from parent
)
```

### 2. Give each subagent minimal tool access

Don't give every subagent all tools. Restrict each to what it actually needs:

```python
# Research agent: read-only
researcher = AgentDefinition(tools=["Read", "Grep", "Glob", "Skill"])

# Writer: read + write, no shell access
writer = AgentDefinition(tools=["Read", "Write", "Edit", "Grep"])

# Browser agent: only Playwright tools
browser_agent = AgentDefinition(tools=[
    "mcp__playwright__browser_navigate",
    "mcp__playwright__browser_snapshot",
    "mcp__playwright__browser_click",
    "mcp__playwright__browser_type",
    "mcp__playwright__browser_take_screenshot",
])
```

### 3. Include Skill tool for domain knowledge

If your app has skills (domain knowledge files), give subagents the `Skill` tool:

```python
researcher = AgentDefinition(
    prompt="""...
CRITICAL: Load ALL relevant skills before starting research.
Use the Skill tool to load domain-specific knowledge.""",
    tools=["Read", "Grep", "Glob", "Skill", "ToolSearch"],
)
```

### 4. Write clear descriptions — they control delegation

The main agent decides WHICH subagent to use based on the `description`. Make it specific:

```python
# WEAK description — main agent won't know when to use it
AgentDefinition(description="A helper agent")

# STRONG description — clear trigger conditions
AgentDefinition(
    description=(
        "Jira story analyzer. Use when the user provides a Jira issue key "
        "and needs it converted into test cases, requirements, or action items. "
        "Has access to Jira MCP tools for fetching issues and searching fields."
    )
)
```

## Dynamic Agent Loading

For apps that need configurable agents (loaded from DB or JSON files):

```python
import json
from pathlib import Path
from claude_agent_sdk import AgentDefinition


def load_agents_from_json(agents_dir: Path) -> dict[str, AgentDefinition]:
    """Load agent definitions from JSON files."""
    agents = {}
    for json_file in agents_dir.glob("*.json"):
        with open(json_file) as f:
            defn = json.load(f)

        if not defn.get("enabled", True):
            continue

        agents[json_file.stem] = AgentDefinition(
            description=defn.get("description", ""),
            prompt=defn.get("prompt", ""),
            tools=defn.get("tools", []),
        )

    return agents


def get_all_agents() -> dict[str, AgentDefinition]:
    """Load agents from JSON + DB, with fallback to static definitions."""
    try:
        agents_dir = Path(__file__).parent / "agents"
        return load_agents_from_json(agents_dir)
    except Exception:
        return ALL_AGENTS  # Fallback to static definitions
```

### Simple JSON file (`agents/researcher.json`):

```json
{
    "name": "researcher",
    "enabled": true,
    "description": "Research specialist for finding information in the knowledge base",
    "prompt": "You are a research specialist...",
    "tools": ["Read", "Grep", "Glob", "Skill", "ToolSearch"]
}
```

### Full JSON Agent Definition (with memory, signals, versioning):

Real production agents use a richer schema. The loader converts these to `AgentDefinition` instances:

```json
{
    "name": "accessibility-tester",
    "version": "1.0.0",
    "description": "Accessibility testing specialist for WCAG 2.1 AA compliance, ARIA attributes, keyboard navigation, screen reader compatibility, and color contrast.",
    "prompt": "You are an accessibility testing specialist. You ensure web applications meet WCAG 2.1 AA standards.\n\nWorkflow:\n1. Load relevant skills\n2. Navigate to the target page\n3. Run automated accessibility checks\n4. Test keyboard navigation\n5. Check ARIA attributes\n6. Verify color contrast ratios\n7. Take screenshots showing issues",
    "tools": [
        "mcp__playwright__browser_navigate",
        "mcp__playwright__browser_snapshot",
        "mcp__playwright__browser_click",
        "mcp__playwright__browser_evaluate",
        "mcp__playwright__browser_take_screenshot",
        "Skill",
        "TodoWrite",
        "ToolSearch"
    ],
    "memory": {
        "personality": [
            {
                "title": "Inclusive design advocate",
                "importance": 9,
                "content": "You test from the perspective of users with disabilities."
            }
        ],
        "procedure": [
            {
                "title": "Systematic audit",
                "importance": 10,
                "content": "Test in order: (1) Automated scan, (2) Keyboard nav, (3) Focus management, (4) ARIA audit, (5) Color contrast."
            }
        ],
        "skill": [
            {
                "title": "Keyboard navigation",
                "importance": 9,
                "content": "Tab through entire page. Verify logical tab order. Check focus indicators are visible."
            }
        ],
        "anti_trait": [
            {
                "title": "No automated-only testing",
                "importance": 9,
                "content": "Automated tools catch only 30-40% of issues. Always perform manual testing too."
            }
        ]
    },
    "signals": {
        "keywords": ["accessibility", "a11y", "wcag", "aria", "screen reader"],
        "categories": ["accessibility"],
        "confidence_threshold": 0.2
    },
    "model_preference": "medium",
    "max_turns": 100,
    "enabled": true
}
```

### JSON Agent Definition Schema

| Field | Type | Required | Purpose |
|-------|------|----------|---------|
| `name` | `string` | Yes | Agent identifier (kebab-case) |
| `version` | `string` | No | Semver for tracking changes |
| `description` | `string` | Yes | Trigger description — main agent reads this to decide when to delegate |
| `prompt` | `string` | Yes | System prompt for the subagent |
| `tools` | `list[str]` | Yes | Allowed tools (MCP tools use `mcp__server__tool` format) |
| `memory` | `object` | No | Persistent traits organized by type (see below) |
| `signals` | `object` | No | Auto-routing: keywords and categories for signal-based delegation |
| `model_preference` | `string` | No | `"fast"`, `"medium"`, `"capable"` — hint, not binding |
| `max_turns` | `int` | No | Per-agent turn limit |
| `enabled` | `bool` | Yes | `false` to disable without deleting |

### Memory Types for Agent Personality

The `memory` field gives agents persistent traits that the loader appends to the prompt:

| Type | Purpose | Example |
|------|---------|---------|
| `personality` | Core traits and perspective | "You test from the perspective of users with disabilities" |
| `procedure` | Step-by-step workflows | "Test in order: automated scan, keyboard nav, ARIA audit..." |
| `skill` | Domain knowledge | "Tab through entire page. Verify logical tab order." |
| `anti_trait` | What to avoid | "Never rely solely on automated tools" |

Each entry has `title`, `content`, and `importance` (1-10). Higher importance entries appear first in the prompt.

### Production Loader (JSON Files + DB Overlay)

```python
import json
from pathlib import Path
from claude_agent_sdk import AgentDefinition


def load_agent_definitions(definitions_dir: str, db_definitions: list[dict] | None = None) -> dict:
    """Load agents from JSON files + DB. DB definitions override filesystem (user customization wins)."""
    agents: dict[str, dict] = {}

    # 1. Load built-in agents from JSON files
    dir_path = Path(definitions_dir)
    if dir_path.exists():
        for path in sorted(dir_path.glob("*.json")):
            try:
                agent = json.loads(path.read_text())
                agent["source"] = "builtin"
                agents[agent["name"]] = agent
            except (json.JSONDecodeError, KeyError) as exc:
                log.warning(f"Skipping invalid agent {path.name}: {exc}")

    # 2. Overlay DB definitions (user customizations win)
    for db_agent in db_definitions or []:
        agents[db_agent["name"]] = db_agent

    return agents


def to_sdk_agents(definitions: dict) -> dict[str, AgentDefinition]:
    """Convert JSON definitions to SDK AgentDefinition objects."""
    result = {}
    for name, defn in definitions.items():
        if not defn.get("enabled", True):
            continue
        prompt = _build_agent_prompt(defn)
        result[name] = AgentDefinition(
            description=defn.get("description", ""),
            prompt=prompt,
            tools=defn.get("tools", []),
        )
    return result


def _build_agent_prompt(defn: dict) -> str:
    """Build prompt from base prompt + memory entries sorted by importance."""
    parts = [defn.get("prompt", "")]
    memory = defn.get("memory", {})
    if not memory:
        return parts[0]
    section_labels = {
        "personality": "Core Traits",
        "procedure": "Procedures",
        "skill": "Skills",
        "anti_trait": "Anti-Patterns (Avoid)",
    }
    for key, label in section_labels.items():
        entries = memory.get(key, [])
        if not entries:
            continue
        sorted_entries = sorted(entries, key=lambda e: e.get("importance", 5), reverse=True)
        lines = [f"\n\n## {label}"]
        for entry in sorted_entries:
            lines.append(f"- **{entry.get('title', '')}**: {entry.get('content', '')}")
        parts.append("\n".join(lines))
    return "\n".join(parts)


def get_all_agents() -> dict[str, AgentDefinition]:
    """Load agents with fallback to static definitions."""
    try:
        definitions = load_agent_definitions("./agents/definitions", db_definitions)
        return to_sdk_agents(definitions)
    except Exception:
        return STATIC_AGENTS  # Fallback
```

## Detecting Subagent Activity in Stream

When the main agent delegates to a subagent, you'll see `Agent` tool calls in the stream:

```python
if isinstance(block, ToolUseBlock):
    if block.name == "Agent":
        agent_name = block.input.get("agent_name", "")
        agent_prompt = block.input.get("prompt", "")[:100]
        await send({
            "type": "subagent_start",
            "agent": agent_name,
            "task": agent_prompt,
        })
    else:
        await send({
            "type": "tool_call",
            "tool": block.name,
        })
```
