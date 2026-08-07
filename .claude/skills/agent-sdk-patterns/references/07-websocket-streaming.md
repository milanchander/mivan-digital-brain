# 07 — WebSocket Streaming Handlers

## Why WebSocket?

AI operations take 5-120+ seconds. REST endpoints would block and timeout. WebSocket handlers stream results in real-time: thinking steps, tool calls, progress updates, and the final result.

```
Frontend                    Backend (FastAPI)              Claude Agent SDK
   │                            │                               │
   │── WS connect ─────────────>│                               │
   │                            │── ClaudeSDKClient.connect() ─>│
   │── { message: "..." } ────>│                               │
   │                            │── client.query(msg) ─────────>│
   │                            │                               │
   │<─ { type: "thought" } ────│<─ AssistantMessage ───────────│
   │<─ { type: "tool_call" } ──│<─ AssistantMessage ───────────│
   │<─ { type: "stream_text" }─│<─ StreamEvent ────────────────│
   │<─ { type: "thought" } ────│<─ AssistantMessage ───────────│
   │<─ { type: "complete" } ───│<─ ResultMessage ──────────────│
   │                            │                               │
   │── { type: "follow_up" } ─>│── client.query(followup) ───>│
   │<─ ... streaming ... ─────│<─ ... messages ... ────────────│
   │<─ { type: "complete" } ───│<─ ResultMessage ──────────────│
   │                            │                               │
   │── WS close ───────────────>│── client.disconnect() ───────>│
```

## Complete WebSocket Handler

```python
import asyncio
import json
import logging
from contextlib import suppress

from fastapi import WebSocket, WebSocketDisconnect
from claude_agent_sdk import (
    AssistantMessage,
    ClaudeAgentOptions,
    ClaudeSDKClient,
    ResultMessage,
    TextBlock,
    ToolUseBlock,
)
from claude_agent_sdk.types import StreamEvent

import config

log = logging.getLogger(__name__)


async def handle_chat(ws: WebSocket):
    """WebSocket handler for AI chat with conversation continuation."""
    await ws.accept()

    async def send(payload: dict):
        """Send JSON to frontend, silently ignore if WS is closed."""
        try:
            await ws.send_text(json.dumps(payload))
        except Exception:
            pass

    client = None
    try:
        # ── 1. Receive initial message ──
        raw = await ws.receive_text()
        body = json.loads(raw)

        # ── 2. Handle resume (reconnect to previous conversation) ──
        if body.get("type") == "resume":
            session_id = body.get("session_id")
            message = body.get("message", "")

            if not session_id or not message:
                await send({"type": "error", "message": "Resume requires session_id and message"})
                return

            await send({"type": "status", "message": "Resuming conversation..."})

            options = ClaudeAgentOptions(
                model=body.get("model") or config.DEFAULT_MODEL,
                resume=session_id,
                continue_conversation=True,
                setting_sources=config.SETTING_SOURCES,
                permission_mode=config.PERMISSION_MODE,
                allowed_tools=["Read", "Grep", "Glob", "Skill", "ToolSearch"],
                include_partial_messages=True,  # Enable StreamEvent for token streaming
                max_turns=body.get("max_turns") or config.MAX_TURNS,
            )

            client = ClaudeSDKClient(options=options)
            await client.connect()
            await client.query(message)

            result = await _stream_response(client, send)
            await send({
                "type": "complete",
                "session_id": session_id,
                "cost_usd": result["cost"],
                "conversation_active": True,
            })

            # Fall through to follow-up loop below
            await _follow_up_loop(client, ws, send)
            return

        # ── 3. Standard new conversation ──
        user_message = body.get("message", "")
        if not user_message:
            await send({"type": "error", "message": "Message is required"})
            return

        await send({"type": "status", "message": "Starting..."})

        options = ClaudeAgentOptions(
            model=body.get("model") or config.DEFAULT_MODEL,
            setting_sources=config.SETTING_SOURCES,
            permission_mode=config.PERMISSION_MODE,
            system_prompt={
                "type": "preset",
                "preset": "claude_code",
                "append": body.get("system_prompt", ""),
            },
            allowed_tools=["Read", "Grep", "Glob", "Skill", "ToolSearch"],
            include_partial_messages=True,  # Enable StreamEvent for token streaming
            max_turns=body.get("max_turns") or config.MAX_TURNS,
        )

        client = ClaudeSDKClient(options=options)
        await client.connect()

        await send({"type": "status", "message": "Connected to AI..."})

        # ── 4. Initial query + stream ──
        await client.query(user_message)
        result = await _stream_response(client, send)

        await send({
            "type": "complete",
            "cost_usd": result["cost"],
            "num_turns": result["turns"],
            "duration_ms": result["duration"],
            "session_id": result["session_id"],
            "conversation_active": True,
        })

        # ── 5. Follow-up conversation loop ──
        await _follow_up_loop(client, ws, send)

    except WebSocketDisconnect:
        log.info("WebSocket disconnected by client")
    except Exception as exc:
        log.exception("WebSocket handler error")
        with suppress(Exception):
            await send({"type": "error", "message": str(exc)})
    finally:
        if client:
            try:
                await client.disconnect()
            except Exception:
                pass


SUPPRESS_TOOLS = frozenset({"ToolSearch"})  # Hidden from UI display
TODO_TOOLS = frozenset({"TodoWrite", "TodoRead"})  # Get dedicated handling


async def process_todo_write(block_input: dict, send):
    """Intercept TodoWrite tool calls and emit structured todo_update.

    TodoWrite always sends the FULL todo list (not deltas).
    Frontend replaces its state wholesale on each update.
    """
    todos = block_input.get("todos", [])
    if not todos:
        return
    await send({
        "type": "todo_update",
        "todos": [
            {
                "content": t.get("content", ""),
                "status": t.get("status", "pending"),
                "activeForm": t.get("activeForm", ""),
            }
            for t in todos
        ],
    })


async def _stream_response(client, send) -> dict:
    """Stream ClaudeSDKClient response to WebSocket.

    Returns dict with: cost, turns, duration, session_id.
    """
    result = {"cost": None, "turns": None, "duration": None, "session_id": None}

    async for message in client.receive_response():
        # ── Text + tool calls ──
        if isinstance(message, AssistantMessage):
            for block in message.content or []:
                if isinstance(block, TextBlock) and block.text.strip():
                    await send({"type": "thought", "text": block.text.strip()})
                elif isinstance(block, ToolUseBlock):
                    # CRITICAL: intercept TodoWrite for progress checklist UI
                    if block.name == "TodoWrite":
                        await process_todo_write(block.input or {}, send)
                    elif block.name in SUPPRESS_TOOLS or block.name in TODO_TOOLS:
                        pass  # Don't show in generic tool_call UI
                    else:
                        tool_input = block.input or {}
                        detail = (
                            tool_input.get("file_path")
                            or tool_input.get("url")
                            or tool_input.get("command")
                            or tool_input.get("skill")
                            or tool_input.get("pattern")
                            or ""
                        )
                        if isinstance(detail, str) and len(detail) > 80:
                            detail = "..." + detail[-77:]
                        await send({
                            "type": "tool_call",
                            "tool": block.name,
                            "detail": detail,
                        })

        # ── Character-by-character streaming (optional) ──
        if isinstance(message, StreamEvent):
            event = message.event
            if isinstance(event, dict) and event.get("type") == "content_block_delta":
                delta = event.get("delta", {})
                if delta.get("type") == "text_delta":
                    await send({"type": "stream_text", "text": delta.get("text", "")})

        # ── Final result with metadata ──
        if isinstance(message, ResultMessage):
            result["cost"] = getattr(message, "total_cost_usd", None)
            result["turns"] = getattr(message, "num_turns", None)
            result["duration"] = getattr(message, "duration_ms", None)
            result["session_id"] = getattr(message, "session_id", None)

    return result


async def _follow_up_loop(client, ws: WebSocket, send):
    """Listen for follow-up messages on the same WebSocket."""
    while True:
        try:
            raw = await asyncio.wait_for(
                ws.receive_text(),
                timeout=config.SESSION_MAX_IDLE_SECONDS,
            )
            msg = json.loads(raw)

            if msg.get("type") == "follow_up" and msg.get("message"):
                follow_up = msg["message"]
                await send({"type": "status", "message": f"Follow-up received..."})

                await client.query(follow_up)
                result = await _stream_response(client, send)

                await send({
                    "type": "follow_up_complete",
                    "cost_usd": result["cost"],
                    "conversation_active": True,
                })

            elif msg.get("type") == "close":
                break

        except (asyncio.TimeoutError, WebSocketDisconnect, Exception):
            break
```

## WebSocket Protocol Specification

### Messages FROM Frontend to Backend

```typescript
// New conversation
{ message: string, model?: string, system_prompt?: string, max_turns?: number }

// Follow-up (same WS connection)
{ type: "follow_up", message: string }

// Resume previous conversation (new WS connection)
{ type: "resume", session_id: string, message: string, model?: string }

// Close conversation
{ type: "close" }
```

### Messages FROM Backend to Frontend

```typescript
// Status update
{ type: "status", message: string }

// AI thinking/text output
{ type: "thought", text: string }

// Tool being called
{ type: "tool_call", tool: string, detail?: string }

// Character-by-character streaming
{ type: "stream_text", text: string }

// Conversation complete
{
    type: "complete",
    cost_usd?: number,
    num_turns?: number,
    duration_ms?: number,
    session_id?: string,
    conversation_active: boolean,
}

// Follow-up response complete
{ type: "follow_up_complete", cost_usd?: number, conversation_active: boolean }

// Error
{ type: "error", message: string }
```

## Mounting WebSocket in FastAPI

```python
# main.py
from ws_handlers.chat import handle_chat

app.add_api_websocket_route("/ws/chat", handle_chat)
```

## Multiple WebSocket Handlers

For apps with multiple AI features, create separate handlers:

```python
# main.py
from ws_handlers.chat import handle_chat
from ws_handlers.generate import handle_generate
from ws_handlers.analyze import handle_analyze

app.add_api_websocket_route("/ws/chat", handle_chat)
app.add_api_websocket_route("/ws/generate", handle_generate)
app.add_api_websocket_route("/ws/analyze", handle_analyze)
```

Each handler manages its own ClaudeSDKClient lifecycle, options, and streaming.

## Session Idle Timeout

Always set a timeout on the follow-up loop to prevent zombie connections:

```python
raw = await asyncio.wait_for(
    ws.receive_text(),
    timeout=900,  # 15 minutes idle timeout
)
```

After timeout, the WebSocket closes gracefully. The frontend can resume later using `session_id`.
