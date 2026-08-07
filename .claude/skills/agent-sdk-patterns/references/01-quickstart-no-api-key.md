# 01 — Quickstart: Build an LLM App Without an API Key

## The Key Insight

The Claude Agent SDK does NOT require an `ANTHROPIC_API_KEY`. It reads authentication from your local Claude Code installation via `setting_sources`. If Claude Code works on your machine (Accenture Claude or any enterprise deployment), the SDK works too.

## How Authentication Works

```
Your App (Python)
    │
    ▼
claude-agent-sdk
    │
    ▼ setting_sources=["user", "project", "local"]
    │
    ├── ~/.claude/settings.json          ← "user" settings (Claude Code config)
    ├── .claude/settings.json            ← "project" settings
    └── .claude/settings.local.json      ← "local" settings (gitignored)
    │
    ▼
Claude Code's authentication layer
    │
    ▼
Claude API (authenticated via your existing license)
```

The SDK uses the same authentication mechanism that Claude Code uses. No API key is stored anywhere in your code or environment.

## Minimal Working Example

### Step 1: Install

```bash
pip install "claude-agent-sdk>=0.1.48" fastapi uvicorn
```

### Step 2: Create `app.py`

```python
import asyncio
import json
from fastapi import FastAPI, WebSocket
from claude_agent_sdk import (
    AssistantMessage,
    ClaudeAgentOptions,
    ClaudeSDKClient,
    ResultMessage,
    TextBlock,
)

app = FastAPI()

SETTING_SOURCES = ["user", "project", "local"]


@app.websocket("/ws/chat")
async def chat(ws: WebSocket):
    await ws.accept()

    async def send(payload: dict):
        await ws.send_text(json.dumps(payload))

    try:
        raw = await ws.receive_text()
        body = json.loads(raw)
        user_message = body.get("message", "")

        # Create SDK client — NO API KEY NEEDED
        options = ClaudeAgentOptions(
            model="claude-sonnet-4-6",
            setting_sources=SETTING_SOURCES,
            permission_mode="bypassPermissions",
            max_turns=50,
        )

        client = ClaudeSDKClient(options=options)
        await client.connect()

        await client.query(user_message)

        async for message in client.receive_response():
            if isinstance(message, AssistantMessage):
                for block in message.content or []:
                    if isinstance(block, TextBlock) and block.text.strip():
                        await send({"type": "text", "content": block.text.strip()})

            if isinstance(message, ResultMessage):
                cost = getattr(message, "total_cost_usd", None)
                session_id = getattr(message, "session_id", None)
                await send({
                    "type": "complete",
                    "cost_usd": cost,
                    "session_id": session_id,
                })

        await client.disconnect()

    except Exception as e:
        await send({"type": "error", "message": str(e)})


@app.get("/")
async def index():
    return {"status": "ok", "message": "LLM app running — no API key needed"}
```

### Step 3: Run

```bash
uvicorn app:app --host 0.0.0.0 --port 8000
```

### Step 4: Test with a simple HTML page

```html
<!DOCTYPE html>
<html>
<body>
  <input id="msg" placeholder="Ask anything..." />
  <button onclick="send()">Send</button>
  <div id="output"></div>

  <script>
    let ws;
    function send() {
      const msg = document.getElementById('msg').value;
      ws = new WebSocket('ws://localhost:8000/ws/chat');
      ws.onopen = () => ws.send(JSON.stringify({ message: msg }));
      ws.onmessage = (e) => {
        const data = JSON.parse(e.data);
        if (data.type === 'text') {
          document.getElementById('output').innerText += data.content + '\n';
        }
      };
    }
  </script>
</body>
</html>
```

## Knowledge Base Chatbot Example

A common use case: a web app that queries a knowledge base built from markdown files (QBR docs, meeting notes, technical docs, etc.):

```python
import asyncio
import json
import os
from pathlib import Path
from fastapi import FastAPI, WebSocket
from claude_agent_sdk import (
    AssistantMessage,
    ClaudeAgentOptions,
    ClaudeSDKClient,
    ResultMessage,
    TextBlock,
    ToolUseBlock,
)

app = FastAPI()

SETTING_SOURCES = ["user", "project", "local"]
KNOWLEDGE_DIR = os.getenv("KNOWLEDGE_DIR", "./knowledge")


def build_system_prompt() -> str:
    """Build a system prompt that includes the knowledge directory context."""
    return (
        "You are a knowledge assistant. The user has a directory of markdown files "
        f"at '{KNOWLEDGE_DIR}' containing their knowledge base. "
        "Use the Read, Grep, and Glob tools to search and read these files "
        "when answering questions. Always cite which file(s) you found the answer in. "
        "If you cannot find an answer in the knowledge base, say so clearly."
    )


@app.websocket("/ws/chat")
async def chat(ws: WebSocket):
    await ws.accept()

    async def send(payload: dict):
        try:
            await ws.send_text(json.dumps(payload))
        except Exception:
            pass

    client = None
    try:
        raw = await ws.receive_text()
        body = json.loads(raw)
        user_message = body.get("message", "")

        options = ClaudeAgentOptions(
            model=body.get("model", "claude-sonnet-4-6"),
            setting_sources=SETTING_SOURCES,
            permission_mode="bypassPermissions",
            max_turns=30,
            include_partial_messages=True,   # Enable StreamEvent for char-by-char streaming
            system_prompt={
                "type": "preset",
                "preset": "claude_code",
                "append": build_system_prompt(),
            },
            allowed_tools=["Read", "Grep", "Glob", "Skill", "ToolSearch"],
        )

        client = ClaudeSDKClient(options=options)
        await client.connect()
        await client.query(user_message)

        async for message in client.receive_response():
            if isinstance(message, AssistantMessage):
                for block in message.content or []:
                    if isinstance(block, TextBlock) and block.text.strip():
                        await send({"type": "text", "content": block.text.strip()})
                    elif isinstance(block, ToolUseBlock):
                        await send({
                            "type": "tool_call",
                            "tool": block.name,
                            "detail": str(block.input)[:200],
                        })

            if isinstance(message, ResultMessage):
                session_id = getattr(message, "session_id", None)
                cost = getattr(message, "total_cost_usd", None)
                await send({
                    "type": "complete",
                    "session_id": session_id,
                    "cost_usd": cost,
                })

        # Keep connection open for follow-ups
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
                    if isinstance(message, ResultMessage):
                        await send({"type": "complete"})
            elif msg.get("type") == "close":
                break

    except Exception as e:
        await send({"type": "error", "message": str(e)})
    finally:
        if client:
            try:
                await client.disconnect()
            except Exception:
                pass
```

**Frontend rendering**: When you render the AI's response in your UI, use a markdown renderer (`react-markdown` + `remark-gfm` for React, `marked.js` + `DOMPurify` for vanilla JS). Claude responses contain markdown — headings, code blocks, lists, tables. Rendering as plain text breaks the formatting. See [reference 10](10-frontend-integration.md).

## What setting_sources Actually Does

| Source | File Location | What It Contains | When To Use |
|--------|--------------|------------------|-------------|
| `"user"` | `~/.claude/settings.json` | Global Claude Code config, authentication tokens | **Always include** — this is where auth lives |
| `"project"` | `.claude/settings.json` | Project-specific settings, permissions, MCP configs | Include for project-scoped settings |
| `"local"` | `.claude/settings.local.json` | Developer-local overrides (gitignored) | Include for per-developer customization |

**CRITICAL**: Always use `["user", "project", "local"]`. Omitting `"user"` means no authentication. Omitting `"project"` means no project-level permissions. Omitting `"local"` means no local overrides.

## Supported Models

The model you specify in `ClaudeAgentOptions(model=...)` depends on what your Claude Code license supports:

| Model ID | Model | Notes |
|----------|-------|-------|
| `claude-sonnet-4-6` | Claude Sonnet 4.6 | Best balance of speed + quality |
| `claude-opus-4-6` | Claude Opus 4.6 | Most capable, slower, higher cost |
| `claude-haiku-4-5-20251001` | Claude Haiku 4.5 | Fastest, cheapest, good for simple tasks |

For enterprise Bedrock deployments:
| Model ID | Notes |
|----------|-------|
| `us.anthropic.claude-sonnet-4-6` | Cross-region Bedrock |
| `us.anthropic.claude-opus-4-6-v1` | Cross-region Bedrock |

## Common Issues

### "No authentication found"
Your Claude Code installation may not be configured. Run `claude` in terminal to verify it works.

### "Model not available"
Your enterprise license may restrict certain models. Try `claude-sonnet-4-6` first (most widely available).

### "Permission denied"
Use `permission_mode="bypassPermissions"` for autonomous operation, or implement a permission bridge (see reference 09).

### Package version
Ensure `claude-agent-sdk>=0.1.48`. Earlier versions may have different APIs.

```bash
pip install --upgrade claude-agent-sdk
```
