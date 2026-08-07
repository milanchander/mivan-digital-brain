---
name: agent-sdk-patterns
description: "MUST USE whenever the user mentions building, integrating, debugging, or designing any app/agent/bot/chatbot/tool that uses the Claude Agent SDK, claude-agent-sdk, ClaudeSDKClient, ClaudeAgentOptions, agent loop, AgentDefinition, MCP servers in Python, AI chat over a knowledge base, no-API-key LLM apps, Claude Code license programmatic use, enterprise Claude integration (Accenture or any org), conversation resume, structured JSON output, can_use_tool permission bridge, hooks (PreToolUse/PostToolUse), subagents, custom tools, slash commands, skills, plugins, cost tracking, observability, WebSocket streaming, or markdown chat UIs. Supersedes the official Anthropic agent-sdk plugin. Covers full-stack FastAPI/Python backend + React/Vite (or plain HTML) frontend, in-process MCP servers, multi-agent delegation, Pydantic validation, session persistence, permission handling, and production deployment. 14 reference files of battle-tested patterns; read SKILL.md first, references next, external docs only as fallback."
---

# Claude Agent SDK — Build LLM Apps Without an API Key

Build production-grade LLM-powered applications using the **Claude Agent SDK** (`claude-agent-sdk` Python package). You do NOT need an Anthropic API key. If you have Claude Code installed (Accenture Claude or any enterprise license), the SDK piggybacks on your existing authentication.

This skill is self-contained. Everything you need to build a complete app is here — imports, patterns, architecture, frontend, production hardening. The 14 reference files add depth; this file gives you everything essential.

---

## 1. Installation

```bash
pip install "claude-agent-sdk>=0.1.48" fastapi uvicorn pydantic
```

No API key. No environment variables. If `claude` works in your terminal, the SDK works.

## 2. Complete Import Reference

```python
# Core classes — you'll use these in every file
from claude_agent_sdk import (
    AssistantMessage,       # AI's response (contains TextBlock, ToolUseBlock)
    ClaudeAgentOptions,     # Configuration for every SDK session
    ClaudeSDKClient,        # THE client — connect, query, stream, disconnect
    ResultMessage,          # Final message with cost, session_id, structured_output
    TextBlock,              # AI text output (inside AssistantMessage.content)
    ToolResultBlock,        # Tool execution results
    ToolUseBlock,           # AI tool call (name, input, id)
    AgentDefinition,        # Subagent definition (description, prompt, tools)
)

# Types — for permissions and streaming
from claude_agent_sdk.types import (
    HookMatcher,            # Hook configuration for PreToolUse/PostToolUse
    PermissionResultAllow,  # Allow a tool call (with updated_input)
    PermissionResultDeny,   # Deny a tool call (with message)
    StreamEvent,            # Raw SSE streaming events (character-by-character)
    ToolPermissionContext,  # Context passed to can_use_tool callback
)
```

**ALWAYS use `ClaudeSDKClient`** — it supports conversations, follow-ups, session resume, and one-shot queries. The SDK also exports a standalone `query()` function, but avoid it — `ClaudeSDKClient` is preferred for all use cases.

## 3. The Key Pattern (No API Key)

```python
SETTING_SOURCES = ["user", "project", "local"]  # EVERY session needs this
```

This tells the SDK to read authentication from your Claude Code installation:
- `"user"` — `~/.claude/settings.json` (where your auth token lives)
- `"project"` — `.claude/settings.json` (project permissions)
- `"local"` — `.claude/settings.local.json` (gitignored overrides)

**NEVER omit this.** Without `setting_sources`, the SDK looks for `ANTHROPIC_API_KEY` which you don't have.

## 4. Available Models

| Model ID | Model | Best For |
|----------|-------|----------|
| `claude-sonnet-4-6` | Claude Sonnet 4.6 | Default (preferred) — best speed/quality balance |
| `claude-opus-4-8` | Claude Opus 4.8 | Most capable, complex reasoning |
| `claude-haiku-4-5-20251001` | Claude Haiku 4.5 | Fastest, cheapest, simple tasks |

For enterprise Bedrock: `us.anthropic.claude-sonnet-4-6`, `us.anthropic.claude-opus-4-8`

## 5. Available Tools

Tools the AI agent can use (pass in `allowed_tools`):

| Tool | Purpose | Safe? |
|------|---------|-------|
| `Read` | Read files | Yes |
| `Grep` | Search file contents | Yes |
| `Glob` | Find files by pattern | Yes |
| `Write` | Create/overwrite files | Destructive |
| `Edit` | Edit existing files | Destructive |
| `Bash` | Run shell commands | Destructive |
| `Agent` | Delegate to subagents | Yes |
| `Skill` | Load Claude Code skills (input: `{"skill": "skill-name"}`) | Yes |
| `ToolSearch` | Search for available tools | Yes |
| `TodoWrite` | Create progress checklists | Yes |
| `TaskCreate/Update/List` | Task management | Yes |
| `mcp__<server>__*` | All tools from an MCP server (wildcard) | Depends |
| `mcp__<server>__<tool>` | Specific MCP tool | Depends |

**Safe default for read-only chatbot:**
```python
allowed_tools = ["Read", "Grep", "Glob", "Skill", "ToolSearch"]
```

**Full access (use with permission bridge for safety):**
```python
allowed_tools = ["Read", "Grep", "Glob", "Write", "Edit", "Bash", "Agent", "Skill", "ToolSearch"]
```

## 6. ClaudeSDKClient — The Only Pattern You Need

### Lifecycle

```
ClaudeSDKClient(options)         # Create
  await client.connect()         # Connect
  await client.query(prompt)     # Send message
  async for msg in client.receive_response():   # Stream response
      # AssistantMessage → text + tool calls (paragraph-level chunks)
      # StreamEvent → character-by-character tokens (requires include_partial_messages=True)
      # ResultMessage → final result + session_id + cost
  await client.query(followup)   # Follow-up (same conversation)
  async for msg in client.receive_response(): ...
  await client.disconnect()      # Cleanup
```

### `include_partial_messages=True` for Reliable Token Streaming

Set `include_partial_messages=True` in `ClaudeAgentOptions` when you want **reliable** character-by-character streaming via `StreamEvent`. Without it, `StreamEvent` behavior is inconsistent — you may only get `AssistantMessage` chunks at paragraph/block boundaries.

```python
options = ClaudeAgentOptions(
    model="claude-sonnet-4-6",
    setting_sources=["user", "project", "local"],
    include_partial_messages=True,   # Recommended for char-by-char streaming UIs
    ...
)
```

**Set it when:**
- Building chat UIs with typewriter-effect streaming
- Users see the AI "typing" character-by-character
- You want predictable streaming behavior

**You can skip it when:**
- Batch jobs that wait for `ResultMessage`
- Paragraph-level updates via `AssistantMessage.content` are enough
- Pure structured output workflows (`output_format` with `strict: True`)

**Note**: `AssistantMessage` always fires regardless. The flag only affects `StreamEvent` (fine-grained token deltas).

### Complete Streaming Pattern

> **Requires `include_partial_messages=True` in `ClaudeAgentOptions`** for `StreamEvent` (token-level) to fire. Without it, only `AssistantMessage` (paragraph-level) chunks arrive.

```python
from claude_agent_sdk.types import StreamEvent  # Required import for streaming

async def stream_response(client, send):
    """Stream SDK response to a WebSocket send function.
    Returns dict with cost, turns, duration, session_id.

    NOTE: Requires options.include_partial_messages=True for StreamEvent to fire.
    """
    result = {"cost": None, "turns": None, "duration": None, "session_id": None}

    async for message in client.receive_response():
        if isinstance(message, AssistantMessage):
            for block in message.content or []:
                if isinstance(block, TextBlock) and block.text.strip():
                    await send({"type": "thought", "text": block.text.strip()})
                elif isinstance(block, ToolUseBlock):
                    detail = (block.input or {}).get("file_path") or (block.input or {}).get("skill") or ""
                    await send({"type": "tool_call", "tool": block.name, "detail": str(detail)[:80]})

        if isinstance(message, StreamEvent):
            event = message.event
            if isinstance(event, dict) and event.get("type") == "content_block_delta":
                delta = event.get("delta", {})
                if delta.get("type") == "text_delta":
                    await send({"type": "stream_text", "text": delta.get("text", "")})

        if isinstance(message, ResultMessage):
            result["cost"] = getattr(message, "total_cost_usd", None)
            result["turns"] = getattr(message, "num_turns", None)
            result["duration"] = getattr(message, "duration_ms", None)
            result["session_id"] = getattr(message, "session_id", None)

    return result
```

### ResultMessage Attributes (what you get back)

| Attribute | Type | Purpose |
|-----------|------|---------|
| `result` | `str` | Raw text result |
| `session_id` | `str` | Save this for conversation resume |
| `total_cost_usd` | `float` | Session cost in USD |
| `num_turns` | `int` | Conversation turns used |
| `duration_ms` | `int` | Wall-clock milliseconds |
| `structured_output` | `dict` | Parsed JSON when `output_format` is used |

Access via `getattr(message, "session_id", None)` — all attributes are optional.

## 7. ClaudeAgentOptions — Quick Reference

```python
options = ClaudeAgentOptions(
    # === REQUIRED (no API key) ===
    model="claude-sonnet-4-6",
    setting_sources=["user", "project", "local"],

    # === Execution ===
    max_turns=100,                          # Conversation depth limit
    permission_mode="bypassPermissions",    # Or "default" for interactive
    cwd="/path/to/project",                 # Working directory for file ops
    include_partial_messages=True,          # REQUIRED for StreamEvent (token-by-token streaming)

    # === System Prompt ===
    system_prompt={
        "type": "preset",
        "preset": "claude_code",            # Inherit Claude Code's full capabilities
        "append": "You are a knowledge assistant. Search the docs directory.",
    },

    # === Tools ===
    allowed_tools=["Read", "Grep", "Glob", "Skill", "Agent", "ToolSearch"],
    disallowed_tools=["Write", "Bash"],     # Explicit blocklist (safety)

    # === MCP Servers (external tools) ===
    mcp_servers={
        "knowledge": {
            "type": "stdio",
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/docs"],
        },
    },

    # === Subagents ===
    agents={
        "researcher": AgentDefinition(
            description="Research specialist for finding information",
            prompt="You find relevant information in the knowledge base...",
            tools=["Read", "Grep", "Glob", "Skill"],
        ),
    },

    # === Structured Output (strict JSON) ===
    output_format={
        "type": "json_schema",
        "schema": {"type": "object", "properties": {...}, "required": [...]},
        "strict": True,  # ALWAYS True — constrains token generation
    },

    # === Session Resume ===
    resume="session-abc123",                # From previous ResultMessage.session_id
    continue_conversation=True,             # Must be True when using resume

    # === Permissions (interactive mode) ===
    can_use_tool=my_callback,               # Async callback for tool approval
    hooks={"PreToolUse": [HookMatcher(matcher=None, hooks=[my_hook])]},
)
```

## 8. Minimal Working App (Copy-Paste-Run)

### Frontend: React + Vite (DEFAULT)

Use **React 18 + Vite** as the default frontend. It scales as the app grows, has proper state management, and is the standard most developers know. Setup: `npm create vite@latest frontend -- --template react` then `cd frontend && npm install`.

For quick throwaway prototypes, plain HTML served by FastAPI also works (see [reference 10](references/10-frontend-integration.md) for both patterns). But for anything being shared or maintained, start with React.

The `useChat` hook in [reference 10](references/10-frontend-integration.md) gives you a production-grade WebSocket client with streaming, follow-up, and session resume out of the box.

### Backend: FastAPI + WebSocket

```python
import asyncio, json
from fastapi import FastAPI, WebSocket
from claude_agent_sdk import (
    AssistantMessage, ClaudeAgentOptions, ClaudeSDKClient,
    ResultMessage, TextBlock, ToolUseBlock,
)
from claude_agent_sdk.types import StreamEvent  # For token-by-token streaming

app = FastAPI()

@app.websocket("/ws/chat")
async def chat(ws: WebSocket):
    await ws.accept()
    async def send(payload): await ws.send_text(json.dumps(payload))

    client = None
    try:
        body = json.loads(await ws.receive_text())

        options = ClaudeAgentOptions(
            model="claude-sonnet-4-6",
            setting_sources=["user", "project", "local"],
            permission_mode="bypassPermissions",
            max_turns=30,
            include_partial_messages=True,   # REQUIRED for StreamEvent (char-by-char streaming)
            system_prompt={
                "type": "preset",
                "preset": "claude_code",
                "append": body.get("system_prompt", ""),
            },
            allowed_tools=["Read", "Grep", "Glob", "Skill", "ToolSearch"],
        )

        client = ClaudeSDKClient(options=options)
        await client.connect()
        await client.query(body["message"])

        async for message in client.receive_response():
            if isinstance(message, AssistantMessage):
                for block in message.content or []:
                    if isinstance(block, TextBlock) and block.text.strip():
                        await send({"type": "text", "content": block.text.strip()})
                    elif isinstance(block, ToolUseBlock):
                        await send({"type": "tool_call", "tool": block.name})
            if isinstance(message, StreamEvent):
                event = message.event
                if isinstance(event, dict) and event.get("type") == "content_block_delta":
                    delta = event.get("delta", {})
                    if delta.get("type") == "text_delta":
                        await send({"type": "stream_text", "text": delta.get("text", "")})
            if isinstance(message, ResultMessage):
                await send({
                    "type": "complete",
                    "session_id": getattr(message, "session_id", None),
                    "cost_usd": getattr(message, "total_cost_usd", None),
                })

        # Follow-up loop
        while True:
            raw = await asyncio.wait_for(ws.receive_text(), timeout=900)
            msg = json.loads(raw)
            if msg.get("type") == "follow_up" and msg.get("message"):
                await client.query(msg["message"])
                async for message in client.receive_response():
                    if isinstance(message, AssistantMessage):
                        for block in message.content or []:
                            if isinstance(block, TextBlock) and block.text.strip():
                                await send({"type": "text", "content": block.text.strip()})
                    if isinstance(message, StreamEvent):
                        event = message.event
                        if isinstance(event, dict) and event.get("type") == "content_block_delta":
                            delta = event.get("delta", {})
                            if delta.get("type") == "text_delta":
                                await send({"type": "stream_text", "text": delta.get("text", "")})
                    if isinstance(message, ResultMessage):
                        await send({"type": "complete", "conversation_active": True})
            elif msg.get("type") == "close":
                break
    except Exception as e:
        await send({"type": "error", "message": str(e)})
    finally:
        if client:
            try: await client.disconnect()
            except: pass

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)
```

Run: `python app.py` — your LLM app is live at `ws://localhost:8000/ws/chat`.

## 9. Session Resume Pattern

Save `session_id` from `ResultMessage`. Later, create a NEW client with `resume=` to continue:

```python
# Resume a previous conversation
options = ClaudeAgentOptions(
    model="claude-sonnet-4-6",                  # REQUIRED on resume
    resume=saved_session_id,                     # From ResultMessage.session_id
    continue_conversation=True,                  # REQUIRED with resume
    setting_sources=["user", "project", "local"],
    permission_mode="bypassPermissions",
    allowed_tools=allowed_tools,                 # Must re-specify
    agents=all_agents,                           # Must re-specify
    mcp_servers=mcp_servers,                     # Must re-specify (processes are dead)
    max_turns=100,
)
client = ClaudeSDKClient(options=options)
await client.connect()
await client.query("Continue from where we left off")
```

**Resume re-attaches everything**: model, auth, tools, agents, MCP servers. Only conversation history carries over from the session file.

## 10. Structured Output (Strict JSON)

Force the AI to produce exact JSON:

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
                            "name": {"type": "string"},
                            "summary": {"type": "string"},
                            "priority": {"type": "string", "enum": ["high", "medium", "low"]},
                        },
                        "required": ["name", "summary"],
                    },
                },
            },
            "required": ["items"],
        },
        "strict": True,  # ALWAYS True — model CANNOT deviate from schema
    },
    ...
)
```

Extract via `getattr(message, "structured_output", None)` on `ResultMessage`. Always validate with Pydantic before persisting. See [reference 08](references/08-output-parsing-validation.md).

## 11. MCP Servers (Give AI External Tools)

```python
mcp_servers = {
    # Knowledge base filesystem access
    "knowledge": {
        "type": "stdio",
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/docs"],
    },
    # Browser automation
    "playwright": {
        "type": "stdio",
        "command": "npx",
        "args": ["@playwright/mcp@latest", "--viewport-size", "1920x1080"],
    },
    # Database access
    "database": {
        "type": "stdio",
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-postgres", "postgresql://user:pass@localhost/db"],
    },
}

# Add wildcards for each MCP server to allowed_tools
allowed_tools = ["Read", "Grep", "Glob", "Skill", "ToolSearch"]
for name in mcp_servers:
    allowed_tools.append(f"mcp__{name}__*")
```

See [reference 06](references/06-mcp-servers.md) for Jira, GitHub, custom MCPs, and the config unwrapping pattern.

## 12. TodoWrite Progress Tracking (Critical for UX)

The AI agent uses **TodoWrite** to build progress checklists. Intercept it BEFORE generic tool display and send structured `todo_update` messages to the frontend for a checklist UI:

```python
TODO_TOOLS = frozenset({"TodoWrite", "TodoRead"})
SUPPRESS_TOOLS = frozenset({"ToolSearch"})


async def process_todo_write(block_input: dict, send):
    """Intercept TodoWrite and emit structured todo_update WS message.

    TodoWrite always sends the FULL todo list (not deltas). Frontend
    replaces its state wholesale on each update.
    """
    todos = block_input.get("todos", [])
    if not todos:
        return
    await send({
        "type": "todo_update",
        "todos": [
            {
                "content": t.get("content", ""),       # The task description
                "status": t.get("status", "pending"),   # pending | in_progress | completed
                "activeForm": t.get("activeForm", ""),  # Present-tense form ("Loading skills...")
            }
            for t in todos
        ],
    })


# Usage in your streaming loop:
async for message in client.receive_response():
    if isinstance(message, AssistantMessage):
        for block in message.content or []:
            if isinstance(block, ToolUseBlock):
                if block.name == "TodoWrite":
                    await process_todo_write(block.input or {}, send)  # Structured todos
                elif block.name not in SUPPRESS_TOOLS and block.name not in TODO_TOOLS:
                    await send({"type": "tool_call", "tool": block.name})  # Generic
```

### Make the Agent Plan with TodoWrite

Add a TASK PLANNING section to your prompt — this triggers TodoWrite for tasks with 3+ steps:

```python
prompt = f"""{user_request}

TASK PLANNING: Use TodoWrite to create a progress checklist BEFORE starting.
Update it as you go (mark each step in_progress then completed). Example:
TodoWrite({{"todos": [
    {{"content": "Analyze the request", "status": "in_progress", "activeForm": "Analyzing request"}},
    {{"content": "Gather context from knowledge base", "status": "pending", "activeForm": "Gathering context"}},
    {{"content": "Generate response", "status": "pending", "activeForm": "Generating response"}}
]}})
"""
```

### Allowed Tools for Task Planning

```python
allowed_tools = [
    "Read", "Grep", "Glob", "Skill", "Agent", "ToolSearch",
    "TodoWrite",                                           # Progress checklists
    "TaskCreate", "TaskGet", "TaskList", "TaskUpdate", "TaskStop",  # Task management (for complex flows)
]
```

## 13. WebSocket Message Protocol (Complete)

### Frontend → Backend

| Message | Purpose |
|---------|---------|
| `{ message, model?, system_prompt?, autonomous?, max_turns?, max_cost_usd? }` | New conversation |
| `{ type: "follow_up", message }` | Follow-up on same WS connection |
| `{ type: "resume", session_id, message, model, autonomous? }` | Resume previous conversation (new WS) |
| `{ type: "permission_response", request_id, allow, message?, answers? }` | User decision on tool permission or AskUserQuestion |
| `{ type: "close" }` | End conversation gracefully |

### Backend → Frontend (Generic — Use Only What Your App Needs)

| Type | Fields | Purpose |
|------|--------|---------|
| `status` | `message` | Progress update text ("Starting...", "Connected...") |
| `thought` | `text` | AI reasoning/text output (paragraph-level, render as markdown) |
| `stream_text` | `text` | Token-by-token streaming (requires `include_partial_messages=True`) |
| `tool_call` | `tool`, `detail?`, `input?` | Agent is using a tool |
| `tool_result` | `text`, `tool_name` | Tool execution result (optional — show if useful for UX) |
| `tool_error` | `text`, `tool_name` | Tool execution failed |
| `todo_update` | `todos[]` (each: `content`, `status`, `activeForm`) | TodoWrite progress checklist — replace state wholesale |
| `subagent_start` | `agent`, `task?` | Subagent delegation began (only if you use the Agent tool) |
| `subagent_result` | `agent`, `result?` | Subagent completed |
| `permission_request` | `request_id`, `tool`, `kind` (`"tool_approval"` or `"question"`), `description?`, `questions?` | Interactive permission gate (only with `can_use_tool`) |
| `screenshot` | `data` (base64 data URL), `path?`, `index?` | Captured by browser MCP tools (Playwright `browser_take_screenshot`) |
| `url_change` | `url` | Browser navigated (when using Playwright MCP) |
| `workflow_event` | `kind`, `data` | Optional: phase transitions for multi-stage workflows |
| `complete` | `session_id`, `cost_usd`, `num_turns`, `duration_ms`, `conversation_active` | Final result with metadata |
| `follow_up_complete` | `cost_usd`, `conversation_active` | Follow-up finished |
| `error` | `message` | Error condition |

Pick the minimum set your app needs. A simple chatbot needs: `status`, `thought`, `stream_text`, `complete`, `error`. Add `todo_update` if your prompts use TodoWrite. Add `permission_request` if interactive. Add `subagent_start` if you use the Agent tool with delegation. Add `screenshot` / `url_change` if you're using Playwright MCP.

---

## Deep-Dive Reference Files

This skill contains 14 reference files with production-grade detail:

| # | File | When You Need It |
|---|------|------------------|
| 01 | [quickstart-no-api-key.md](references/01-quickstart-no-api-key.md) | Full knowledge base chatbot example, how setting_sources auth works |
| 02 | [backend-architecture.md](references/02-backend-architecture.md) | FastAPI project structure, config module, middleware, routing |
| 03 | [sdk-client-patterns.md](references/03-sdk-client-patterns.md) | ClaudeSDKClient lifecycle deep-dive, message types, streaming helper |
| 04 | [agent-options-reference.md](references/04-agent-options-reference.md) | Every ClaudeAgentOptions field with examples and defaults |
| 05 | [subagents.md](references/05-subagents.md) | AgentDefinition, JSON agent files with memory/signals, dynamic loader |
| 06 | [mcp-servers.md](references/06-mcp-servers.md) | Playwright, filesystem, DB, Jira, GitHub, custom MCPs, unwrapping |
| 07 | [websocket-streaming.md](references/07-websocket-streaming.md) | Complete WS handler with follow-up loop, resume, idle timeout |
| 08 | [output-parsing-validation.md](references/08-output-parsing-validation.md) | ResultMessage extraction, quality tracking, Pydantic validators |
| 09 | [permission-handling.md](references/09-permission-handling.md) | Autonomous vs interactive, can_use_tool bridge, AskUserQuestion |
| 10 | [frontend-integration.md](references/10-frontend-integration.md) | React useChat hook, vanilla JS client, all message types |
| 11 | [conversation-resume.md](references/11-conversation-resume.md) | Session persistence, MCP re-attachment checklist, storage patterns |
| 12 | [production-patterns.md](references/12-production-patterns.md) | Error handling, cost control, security, deployment, Docker |
| 13 | [setup-and-start-scripts.md](references/13-setup-and-start-scripts.md) | `setup.sh` + `start.sh` templates for macOS, Linux, Windows, Docker |
| 14 | [advanced-sdk-features.md](references/14-advanced-sdk-features.md) | Custom in-process tools, hooks (PreToolUse/PostToolUse), slash commands, observability, cost tracking deep-dive |

## Quick Decision Guide

**"Simple chatbot over my docs"** → Sections 1-8 above + ref [01](references/01-quickstart-no-api-key.md), [10](references/10-frontend-integration.md)

**"Structured JSON output"** → Section 10 above + ref [04](references/04-agent-options-reference.md), [08](references/08-output-parsing-validation.md)

**"Browser automation"** → Section 11 above + ref [06](references/06-mcp-servers.md), [07](references/07-websocket-streaming.md)

**"Multi-agent system"** → ref [05](references/05-subagents.md), [06](references/06-mcp-servers.md), [09](references/09-permission-handling.md)

**"Going to production"** → ref [12](references/12-production-patterns.md), [13](references/13-setup-and-start-scripts.md) (error handling, cost, security, setup/start scripts)

**"Help me set up and run this"** → ref [13](references/13-setup-and-start-scripts.md) (setup.sh + start.sh for macOS/Linux/Windows/Docker)

## Critical Rules

1. **ALWAYS** use `setting_sources=["user", "project", "local"]` — this is how no-API-key works
2. **ALWAYS** use `ClaudeSDKClient` — avoid the standalone `query()` function
3. **ALWAYS** use `strict: True` on `output_format` — without it, schema is advisory only
4. **ALWAYS** disconnect in `finally` — prevents leaked connections
5. **ALWAYS** validate AI output with Pydantic before database writes
6. **ALWAYS** re-attach `model`, `mcp_servers`, `allowed_tools`, `agents` on session resume
7. **ALWAYS** render AI output as markdown in any chat UI — Claude responses are markdown by default. Use `react-markdown` + `remark-gfm` (React) or `marked.js` (vanilla). NEVER render as plain text — code blocks, lists, headings, tables look broken without markdown.
8. **NEVER** hardcode `model=` on `AgentDefinition` — subagents inherit from parent
9. **NEVER** default to "passed" or "success" — use "inconclusive" until proven
10. **AI operations use WebSocket** — REST for CRUD only, WebSocket for AI streaming
11. **MCP wildcards**: `mcp__servername__*` adds all tools from that MCP server

## Reading Order (For Claude in a Cold Session)

**ALWAYS read in this order. Do NOT skip to external URLs.**

1. **This SKILL.md** — contains everything essential to build a complete app (sections 1-13 above)
2. **Relevant reference files** — pick from the table above based on what you're building
3. **Setup scripts** — [reference 13](references/13-setup-and-start-scripts.md) when the user needs to run the app
4. **Advanced features** — [reference 14](references/14-advanced-sdk-features.md) for custom tools, hooks, observability
5. **External Anthropic docs (FALLBACK ONLY)** — only consult if a specific feature is not covered above

## Troubleshooting & Fallback References

If you hit a specific gap not covered in this skill, consult these official Anthropic docs (in order of relevance):

| Topic | URL |
|-------|-----|
| Python SDK GitHub | https://github.com/anthropics/claude-agent-sdk-python |
| SDK Overview | https://code.claude.com/docs/en/agent-sdk/overview |
| Python SDK (ClaudeSDKClient) | https://code.claude.com/docs/en/agent-sdk/python |
| Agent Loop Internals | https://code.claude.com/docs/en/agent-sdk/agent-loop |
| Claude Code Features | https://code.claude.com/docs/en/agent-sdk/claude-code-features |
| Sessions & Resume | https://code.claude.com/docs/en/agent-sdk/sessions |
| Streaming vs Single Mode | https://code.claude.com/docs/en/agent-sdk/streaming-vs-single-mode |
| User Input | https://code.claude.com/docs/en/agent-sdk/user-input |
| Streaming Output | https://code.claude.com/docs/en/agent-sdk/streaming-output |
| Structured Outputs | https://code.claude.com/docs/en/agent-sdk/structured-outputs |
| Custom Tools (in-process) | https://code.claude.com/docs/en/agent-sdk/custom-tools |
| MCP Integration | https://code.claude.com/docs/en/agent-sdk/mcp |
| Tool Search | https://code.claude.com/docs/en/agent-sdk/tool-search |
| Subagents | https://code.claude.com/docs/en/agent-sdk/subagents |
| Modifying System Prompts | https://code.claude.com/docs/en/agent-sdk/modifying-system-prompts |
| Slash Commands | https://code.claude.com/docs/en/agent-sdk/slash-commands |
| Skills | https://code.claude.com/docs/en/agent-sdk/skills |
| Plugins | https://code.claude.com/docs/en/agent-sdk/plugins |
| Permissions | https://code.claude.com/docs/en/agent-sdk/permissions |
| Hooks (PreToolUse/PostToolUse) | https://code.claude.com/docs/en/agent-sdk/hooks |
| Cost Tracking | https://code.claude.com/docs/en/agent-sdk/cost-tracking |
| Observability | https://code.claude.com/docs/en/agent-sdk/observability |
| TodoWrite Progress | https://code.claude.com/docs/en/agent-sdk/todo-tracking |

**Reminder**: Use these URLs **only** when you hit a specific edge case not covered in this skill's 14 files. The skill itself is self-sustaining — don't WebFetch these unless necessary.
