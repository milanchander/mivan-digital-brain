# 04 — ClaudeAgentOptions Full Reference

## Constructor

```python
from claude_agent_sdk import ClaudeAgentOptions

options = ClaudeAgentOptions(
    model="claude-sonnet-4-6",
    setting_sources=["user", "project", "local"],
    permission_mode="bypassPermissions",
    max_turns=100,
    # ... all fields below
)
```

## All Fields

### Required for No-API-Key Mode

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `model` | `str` | Yes | Model ID: `"claude-sonnet-4-6"`, `"claude-opus-4-6"`, `"claude-haiku-4-5-20251001"` |
| `setting_sources` | `list[str]` | **YES** | **MUST be `["user", "project", "local"]`** for no-API-key auth |

### Execution Control

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `max_turns` | `int` | SDK default | Max conversation turns (recommended: 50-200) |
| `max_cost_usd` | `float` | None | Cost ceiling per session in USD |
| `permission_mode` | `str` | `"default"` | `"bypassPermissions"` (auto), `"default"` (interactive), `"acceptEdits"` |
| `cwd` | `str` | None | Working directory for file operations |

### System Prompt

| Field | Type | Description |
|-------|------|-------------|
| `system_prompt` | `dict` or `str` | Custom system prompt configuration |

**Preset with append (recommended):**
```python
system_prompt={
    "type": "preset",
    "preset": "claude_code",       # Use Claude Code's built-in system prompt
    "append": "You are a helpful assistant for analyzing QBR documents.",
}
```

This gives you all of Claude Code's tool-use capabilities PLUS your custom instructions appended.

**Custom string:**
```python
system_prompt="You are a specialized medical document analyzer."
```

### Tools & Permissions

| Field | Type | Description |
|-------|------|-------------|
| `allowed_tools` | `list[str]` | Whitelist of tools the agent can use |
| `disallowed_tools` | `list[str]` | Explicit blocklist — agent CANNOT use these even if allowed elsewhere |
| `can_use_tool` | `Callable` | Async callback for interactive permission requests |
| `hooks` | `dict` | PreToolUse/PostToolUse lifecycle hooks |
| `include_partial_messages` | `bool` | When `True`, enables `StreamEvent` for token-by-token streaming. Required for typewriter-effect chat UIs |

**Common allowed_tools configurations:**

```python
# Read-only knowledge base (safest)
allowed_tools=["Read", "Grep", "Glob", "Skill", "ToolSearch"]

# Read + write (for code generation)
allowed_tools=["Read", "Grep", "Glob", "Write", "Edit", "Bash", "Skill", "ToolSearch"]

# With MCP servers (add wildcards for each server)
allowed_tools=[
    "Read", "Grep", "Glob", "Skill", "ToolSearch",
    "mcp__playwright__*",        # All Playwright tools
    "mcp__mcp-atlassian__*",     # All Jira tools
    "mcp__database__*",          # All database tools
]

# Subagent delegation
allowed_tools=[
    "Read", "Grep", "Glob", "Skill", "Agent", "ToolSearch",
    "TodoWrite", "TaskCreate", "TaskGet", "TaskList", "TaskUpdate",
]
```

### Agents (Subagent Delegation)

| Field | Type | Description |
|-------|------|-------------|
| `agents` | `dict[str, AgentDefinition]` | Named subagents the AI can delegate to |

```python
from claude_agent_sdk import AgentDefinition

options = ClaudeAgentOptions(
    agents={
        "researcher": AgentDefinition(
            description="Research specialist for finding information",
            prompt="You research topics thoroughly...",
            tools=["Read", "Grep", "Glob", "Skill"],
        ),
        "writer": AgentDefinition(
            description="Writing specialist for creating content",
            prompt="You write clear, concise content...",
            tools=["Read", "Write", "Edit"],
        ),
    },
    ...
)
```

### MCP Servers

| Field | Type | Description |
|-------|------|-------------|
| `mcp_servers` | `dict[str, dict]` | MCP server configurations (name -> config) |

```python
options = ClaudeAgentOptions(
    mcp_servers={
        "playwright": {
            "type": "stdio",
            "command": "npx",
            "args": ["@playwright/mcp@latest", "--viewport-size", "1920x1080"],
        },
        "filesystem": {
            "type": "stdio",
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/docs"],
        },
    },
    allowed_tools=[
        "mcp__playwright__*",   # Wildcard: all tools from this MCP
        "mcp__filesystem__*",
    ],
    ...
)
```

### Structured Output

| Field | Type | Description |
|-------|------|-------------|
| `output_format` | `dict` | JSON schema for structured output |

```python
options = ClaudeAgentOptions(
    output_format={
        "type": "json_schema",
        "schema": {
            "type": "object",
            "properties": {
                "items": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "title": {"type": "string"},
                            "summary": {"type": "string"},
                            "priority": {"type": "string", "enum": ["high", "medium", "low"]},
                        },
                        "required": ["title", "summary"],
                    },
                },
            },
            "required": ["items"],
        },
        "strict": True,  # ALWAYS use strict: True — enforces compliance at token level
    },
    ...
)
```

**CRITICAL**: Always set `"strict": True`. This constrains token generation so the model CANNOT deviate from the schema. Without it, schema is advisory only.

### Session Resume

| Field | Type | Description |
|-------|------|-------------|
| `resume` | `str` | session_id from a previous ResultMessage |
| `continue_conversation` | `bool` | Must be `True` when using `resume` |

```python
# Resume a previous conversation
options = ClaudeAgentOptions(
    model="claude-sonnet-4-6",                 # REQUIRED on resume
    resume="session-abc123",                    # From ResultMessage.session_id
    continue_conversation=True,                 # Must be True
    setting_sources=["user", "project", "local"],
    permission_mode="bypassPermissions",
    # Re-attach MCP servers and tools for the resumed session
    mcp_servers=mcp_servers,
    allowed_tools=allowed_tools,
    agents=all_agents,
)
```

## Permission Modes

| Mode | Behavior | Use Case |
|------|----------|----------|
| `"bypassPermissions"` | Agent uses any allowed tool without asking | Autonomous bots, batch processing |
| `"default"` | Agent asks permission via `can_use_tool` callback | Interactive apps with human oversight |
| `"acceptEdits"` | Auto-approves Read/Edit, asks for Bash/Write | Semi-autonomous with safety for destructive ops |

## Complete Example: All Options

```python
options = ClaudeAgentOptions(
    # Authentication (no API key)
    model="claude-sonnet-4-6",
    setting_sources=["user", "project", "local"],

    # Execution limits
    max_turns=100,
    permission_mode="bypassPermissions",

    # System prompt
    system_prompt={
        "type": "preset",
        "preset": "claude_code",
        "append": "You are a document analysis assistant.",
    },

    # Tools
    allowed_tools=["Read", "Grep", "Glob", "Skill", "Agent", "ToolSearch"],
    disallowed_tools=["Write", "Edit", "Bash"],  # Explicit blocklist (safety)
    include_partial_messages=True,                 # Stream partial content during generation

    # Subagents
    agents={
        "analyzer": AgentDefinition(
            description="Document analyzer",
            prompt="Analyze documents for key insights...",
            tools=["Read", "Grep", "Glob"],
        ),
    },

    # MCP servers
    mcp_servers={
        "filesystem": {
            "type": "stdio",
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-filesystem", "./docs"],
        },
    },

    # Structured output
    output_format={
        "type": "json_schema",
        "schema": {"type": "object", "properties": {...}, "required": [...]},
        "strict": True,
    },

    # Working directory
    cwd="/path/to/project",
)
```
