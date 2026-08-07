# 14 — Advanced SDK Features

Covers features beyond the core patterns: custom in-process tools, hooks for tool lifecycle interception, slash commands, observability, and cost tracking.

## Custom Tools (In-Process)

Beyond MCP servers, you can define **in-process custom tools** that run directly in your Python app. These appear to the agent as regular tools but execute as Python functions you control. Use when you want tight integration with your app's database, business logic, or proprietary APIs without spinning up a separate MCP process.

For full details, see the official docs: https://code.claude.com/docs/en/agent-sdk/custom-tools

**When to use:**
- Tools that need access to your app's database connection, auth context, or in-memory state
- Lightweight tools where running a separate MCP process is overkill
- Tools that wrap business logic with type-safe Pydantic schemas

**When NOT to use:**
- Tools available as MCP servers (use those — battle-tested)
- Tools that should be reusable across multiple apps (build an MCP server instead)

## Hooks (Tool Lifecycle Interception)

Hooks let you intercept tool calls BEFORE and AFTER execution. The SDK supports `PreToolUse` and `PostToolUse` hooks via `HookMatcher` from `claude_agent_sdk.types`.

### PreToolUse Hook — Block, Modify, or Log

```python
from claude_agent_sdk.types import HookMatcher

async def pre_tool_hook(input_data: dict, tool_use_id: str, context):
    """Called BEFORE each tool execution.

    Returns:
        {"continue_": True}  → Allow tool to execute
        {"continue_": False, "decision": "block", "reason": "..."}  → Block tool
    """
    tool_name = input_data.get("tool_name", "")

    # Log every tool call for observability
    log.info(f"Tool call: {tool_name} - {input_data}")

    # Block destructive operations on production paths
    if tool_name == "Bash":
        command = input_data.get("tool_input", {}).get("command", "")
        if "rm -rf /" in command or "DROP DATABASE" in command.upper():
            return {
                "continue_": False,
                "decision": "block",
                "reason": "Refusing destructive command",
            }

    return {"continue_": True}


async def post_tool_hook(input_data: dict, tool_use_id: str, context):
    """Called AFTER each tool execution. Use for metrics, audit logs."""
    log.info(f"Tool completed: {input_data.get('tool_name')}")
    return {"continue_": True}


# Wire into ClaudeAgentOptions
options = ClaudeAgentOptions(
    ...
    hooks={
        "PreToolUse": [HookMatcher(matcher=None, hooks=[pre_tool_hook])],
        "PostToolUse": [HookMatcher(matcher=None, hooks=[post_tool_hook])],
    },
)
```

### Filtered Hooks (Match Specific Tools)

`HookMatcher.matcher` accepts a tool name pattern. `None` matches all tools:

```python
# Hook only on Bash tool
HookMatcher(matcher="Bash", hooks=[bash_audit_hook])

# Hook on all tools
HookMatcher(matcher=None, hooks=[audit_all_hook])
```

### When Hooks Fire vs `can_use_tool`

| Mechanism | Purpose | Where Used |
|-----------|---------|------------|
| `can_use_tool` callback | Interactive permission request (sync user prompt) | Permission bridge with WebSocket |
| `PreToolUse` hook | Programmatic check, logging, blocking | Audit logging, policy enforcement |
| `PostToolUse` hook | Metrics, post-execution logging | Telemetry, audit trails |

You can combine them: use `can_use_tool` for user-interactive approvals AND `PreToolUse` for automated policy checks.

For details: https://code.claude.com/docs/en/agent-sdk/hooks

## Cost Tracking

Every `ResultMessage` exposes session cost via `total_cost_usd`. Track it across sessions to enforce budgets:

```python
class CostTracker:
    def __init__(self, max_cost_usd: float = 100.0):
        self.max_cost_usd = max_cost_usd
        self.session_costs: dict[str, float] = {}  # session_id -> cost

    def record(self, session_id: str, cost: float):
        self.session_costs[session_id] = self.session_costs.get(session_id, 0.0) + cost

    def check_limit(self, session_id: str) -> bool:
        """Returns True if session is within budget."""
        return self.session_costs.get(session_id, 0.0) < self.max_cost_usd

    def total_spent(self) -> float:
        return sum(self.session_costs.values())


# Usage in your handler
tracker = CostTracker(max_cost_usd=50.0)

async for message in client.receive_response():
    if isinstance(message, ResultMessage):
        cost = getattr(message, "total_cost_usd", 0.0) or 0.0
        sid = getattr(message, "session_id", None)
        if sid:
            tracker.record(sid, cost)
            if not tracker.check_limit(sid):
                await send({"type": "error", "message": f"Cost limit ${tracker.max_cost_usd} exceeded"})
                break
```

**Persist costs to your database** for long-running budgets across server restarts. Don't just hold in memory.

For details: https://code.claude.com/docs/en/agent-sdk/cost-tracking

## Observability

Structured logging + tracing for production AI apps. Three signals matter:

### 1. Tool Call Audit Trail

Log every tool invocation (via `PreToolUse` hook or directly in your streaming loop):

```python
import json
import logging
from datetime import datetime

audit_log = logging.getLogger("agent.audit")

async def audit_tool_call(tool_name: str, tool_input: dict, session_id: str):
    audit_log.info(json.dumps({
        "timestamp": datetime.utcnow().isoformat(),
        "session_id": session_id,
        "tool": tool_name,
        "input": sanitize(tool_input),  # Redact secrets first
    }))
```

### 2. Session Metrics

Track cost, turns, duration per session for observability dashboards:

```python
metrics = {
    "session_id": session_id,
    "model": model,
    "cost_usd": cost,
    "num_turns": turns,
    "duration_ms": duration,
    "tool_call_count": tool_count,
    "succeeded": status == "complete",
}
# Send to Prometheus, Datadog, CloudWatch, etc.
```

### 3. Error Tracking

Capture exceptions with full SDK context:

```python
try:
    async for message in client.receive_response():
        ...
except Exception as exc:
    error_log.exception(json.dumps({
        "session_id": session_id,
        "model": model,
        "error": str(exc),
        "error_type": type(exc).__name__,
    }))
    # Send to Sentry, Rollbar, etc.
```

For details: https://code.claude.com/docs/en/agent-sdk/observability

## Slash Commands

When `system_prompt={"type": "preset", "preset": "claude_code"}`, the agent has access to Claude Code's built-in slash commands (`/help`, `/clear`, `/compact`, etc.). You can also define custom slash commands via the Claude Code skill system.

Custom slash commands are markdown files in `.claude/commands/` that the agent can invoke. They're useful for repeatable prompt templates.

```
.claude/commands/summarize.md
```

```markdown
---
description: Summarize the current conversation
---

Summarize the key points from our conversation so far. Use bullet points.
Include any decisions made and action items.
```

The agent invokes them as `/summarize`. For details: https://code.claude.com/docs/en/agent-sdk/slash-commands

## Skills (Claude Code Skills)

When `setting_sources=["user", "project", "local"]` is set, the agent automatically discovers skills in:
- `~/.claude/skills/` (user-level)
- `.claude/skills/` (project-level)

Tell the agent to load them via the `Skill` tool: `{"skill": "skill-name"}`. Include `Skill` in `allowed_tools`.

Skills are markdown files with YAML frontmatter:

```markdown
---
name: my-domain-knowledge
description: Knowledge about my domain that should be loaded for relevant tasks
---

# Domain Knowledge

Content the agent should know...
```

For details: https://code.claude.com/docs/en/agent-sdk/skills

## Plugins

Plugins are bundled Claude Code extensions — combinations of agents, skills, commands, MCP servers, and hooks. They install at the user or project level and are discovered automatically when `setting_sources` includes the relevant level.

For details: https://code.claude.com/docs/en/agent-sdk/plugins

## Tool Search (Dynamic Tool Discovery)

The `ToolSearch` tool lets the agent search its available tools at runtime — useful when you have many MCP servers and the agent needs to discover which tool to use.

```python
allowed_tools = ["ToolSearch", ...other tools...]
```

In prompts, you can instruct the agent: *"Use ToolSearch to find the right tool before invoking it."* This is especially useful with the MCP `mcp__server__*` wildcard pattern — the agent doesn't need to memorize every tool name.

For details: https://code.claude.com/docs/en/agent-sdk/tool-search

## Modifying System Prompts

Three patterns for system prompts:

```python
# Pattern 1: Preset + append (recommended — inherits Claude Code capabilities)
system_prompt={
    "type": "preset",
    "preset": "claude_code",
    "append": "You are a knowledge assistant for QBR documents.",
}

# Pattern 2: Custom string (replaces preset entirely — you lose Claude Code's tool-use prompting)
system_prompt="You are a specialized medical analyzer."

# Pattern 3: No system_prompt (SDK uses minimal default)
# Omit the field
```

**Default to Pattern 1** — appending preserves Claude Code's tool-use, skill-loading, and reasoning patterns while letting you inject domain context.

For details: https://code.claude.com/docs/en/agent-sdk/modifying-system-prompts

## Permission System Deep-Dive

See [reference 09](09-permission-handling.md) for the WebSocket permission bridge. For the full permission model: https://code.claude.com/docs/en/agent-sdk/permissions

## Useful SDK Internals

- **Agent Loop**: How the SDK orchestrates think → tool call → observe → think cycles. https://code.claude.com/docs/en/agent-sdk/agent-loop
- **Sessions**: How session state persists and resumes. https://code.claude.com/docs/en/agent-sdk/sessions
- **Streaming Output**: All message types and timing. https://code.claude.com/docs/en/agent-sdk/streaming-output

## When to Read External Docs

This skill covers 90%+ of what you need. Consult the official Anthropic docs (linked above) only when:

1. You hit a specific edge case in custom tools, plugins, or slash commands not covered here
2. You need the canonical type signatures (the docs may be more current)
3. You're debugging an SDK-internal issue (agent loop behavior, session storage details)
4. You're building Claude Code extensions (plugins) vs apps that USE the SDK

For 95% of LLM app building, the patterns in this skill's 14 files are sufficient.
