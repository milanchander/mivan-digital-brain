"""
Mivan Digital Brain — Chat backend (Claude Agent SDK, no API key).

Serves a WebSocket that streams answers from Claude, grounded in the
markdown knowledge base under ``knowledge/`` (layers L1-L6). Authentication
piggybacks on your local Claude Code login via ``setting_sources`` — there is
no ANTHROPIC_API_KEY to configure.

Run:  python app.py    (from the backend/ directory)
"""

import asyncio
import json
import sys
from pathlib import Path

from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware

from claude_agent_sdk import (
    AssistantMessage,
    ClaudeAgentOptions,
    ClaudeSDKClient,
    ResultMessage,
    TextBlock,
    ToolUseBlock,
)
from claude_agent_sdk.types import StreamEvent

from connectors.github_connector import router as github_router
from connectors.servicenow_connector import router as servicenow_router
from connectors.confluence_connector import router as confluence_router

# Project root = parent of this backend/ directory. The agent runs here so its
# Read/Grep/Glob tools can reach the knowledge/ folder.
PROJECT_ROOT = Path(__file__).resolve().parent.parent

MODEL = "claude-sonnet-4-6"

# Base grounding. The frontend also sends its own rich system prompt, which we
# append after this so the agent has both instructions and baked-in context.
BASE_SYSTEM = """You are the Mivan Digital Brain — an AI knowledge assistant for the Mivan Health Plan MiCPS claims processing system.

The authoritative knowledge base lives as markdown files under the `knowledge/` directory, organized into layers:
  knowledge/L1-enterprise/    — organization-wide context
  knowledge/L2-domain/        — health-payer / claims domain knowledge
  knowledge/L3-systems/       — MiCPS system landscape and architecture
  knowledge/L4-application/   — MiCPS application knowledge
  knowledge/L5-business-rules/— claims adjudication business rules
  knowledge/L6-task-intelligence/ — training tracks and task procedures

When answering, use the Grep and Read tools to find and cite exact content from these files. Prefer grounded answers drawn from the knowledge base over general knowledge, and mention which layer a fact comes from when it helps. Be specific and technical — reference real program names, table names, and migration waves. Keep answers concise but complete, and always format them as GitHub-flavored markdown."""

app = FastAPI(title="Mivan Digital Brain Chat")

# Allow the static index.html (opened via file:// or any local server) to connect.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health():
    return {"status": "ok", "project_root": str(PROJECT_ROOT), "model": MODEL}


# ── MCP connectors (mock mode) ──
app.include_router(github_router)
app.include_router(servicenow_router)
app.include_router(confluence_router)


@app.get("/connectors/status")
def all_connectors_status():
    return {
        "connectors": [
            {
                "name": "GitHub",
                "status": "connected",
                "mode": "mock",
                "endpoint": "/connectors/github",
                "description": "Mivan Health GitHub Enterprise — repos, PRs, commits, issues"
            },
            {
                "name": "ServiceNow",
                "status": "connected",
                "mode": "mock",
                "endpoint": "/connectors/servicenow",
                "description": "Mivan ServiceNow — incidents, change requests, problem records"
            },
            {
                "name": "Confluence",
                "status": "connected",
                "mode": "mock",
                "endpoint": "/connectors/confluence",
                "description": "Mivan Confluence — runbooks, architecture docs, operational guides"
            },
            {
                "name": "Jira",
                "status": "not_configured",
                "mode": None,
                "endpoint": None,
                "description": "Mivan Jira — stories, defects, sprint data. Credentials required."
            }
        ],
        "mock_mode": True,
        "note": "Running in mock mode. Set MOCK_MODE=false and configure credentials for live data."
    }


def build_options(frontend_system_prompt: str) -> ClaudeAgentOptions:
    append = BASE_SYSTEM
    if frontend_system_prompt:
        append += "\n\n--- Additional domain context ---\n\n" + frontend_system_prompt
    return ClaudeAgentOptions(
        model=MODEL,
        setting_sources=["user", "project", "local"],  # no API key needed
        permission_mode="bypassPermissions",
        cwd=str(PROJECT_ROOT),
        max_turns=20,
        include_partial_messages=True,  # token-by-token streaming
        system_prompt={
            "type": "preset",
            "preset": "claude_code",
            "append": append,
        },
        allowed_tools=["Read", "Grep", "Glob"],
        disallowed_tools=["Write", "Edit", "Bash"],  # read-only assistant
    )


async def stream_turn(client: ClaudeSDKClient, send):
    """Stream one assistant turn to the frontend.

    Emits only what the chat UI needs: tool_call (search activity),
    stream_text (token deltas), and complete (final metadata).
    """
    async for message in client.receive_response():
        if isinstance(message, AssistantMessage):
            for block in message.content or []:
                if isinstance(block, ToolUseBlock):
                    detail = ""
                    inp = block.input or {}
                    detail = inp.get("pattern") or inp.get("file_path") or inp.get("path") or ""
                    await send({"type": "tool_call", "tool": block.name, "detail": str(detail)[:80]})

        if isinstance(message, StreamEvent):
            event = message.event
            if isinstance(event, dict) and event.get("type") == "content_block_delta":
                delta = event.get("delta", {})
                if delta.get("type") == "text_delta":
                    txt = delta.get("text", "")
                    if txt:
                        await send({"type": "stream_text", "text": txt})

        if isinstance(message, ResultMessage):
            await send({
                "type": "complete",
                "session_id": getattr(message, "session_id", None),
                "cost_usd": getattr(message, "total_cost_usd", None),
                "num_turns": getattr(message, "num_turns", None),
            })


@app.websocket("/ws/chat")
async def chat(ws: WebSocket):
    await ws.accept()

    async def send(payload):
        await ws.send_text(json.dumps(payload))

    client = None
    try:
        body = json.loads(await ws.receive_text())

        options = build_options(body.get("system_prompt", ""))
        client = ClaudeSDKClient(options=options)
        await client.connect()
        await send({"type": "status", "message": "Connected to the Digital Brain."})

        # First message — optionally prefix the current page context.
        # Accept both old ("page_context") and new ("system") field names.
        first = body.get("message", "")
        page_ctx = (body.get("system") or body.get("page_context") or "").strip()
        if page_ctx:
            first = (
                "The user is currently viewing this page in the portal:\n\n"
                f"<page_context>\n{page_ctx}\n</page_context>\n\n"
                f"User question: {first}"
            )

        await client.query(first)
        await stream_turn(client, send)

        # Follow-up loop on the same connection / conversation.
        # Accepts {message, session_id} (new) or {type:"follow_up", message} (legacy).
        while True:
            raw = await asyncio.wait_for(ws.receive_text(), timeout=900)
            msg = json.loads(raw)
            if msg.get("type") == "close":
                break
            follow_text = msg.get("message") if (
                msg.get("type") == "follow_up" or msg.get("session_id") is not None
            ) else None
            if follow_text:
                await client.query(follow_text)
                await stream_turn(client, send)
    except asyncio.TimeoutError:
        try:
            await send({"type": "error", "message": "Session timed out due to inactivity."})
        except Exception:
            pass
    except Exception as e:
        try:
            await send({"type": "error", "message": str(e)})
        except Exception:
            pass
    finally:
        if client:
            try:
                await client.disconnect()
            except Exception:
                pass


if __name__ == "__main__":
    import uvicorn

    config = uvicorn.Config(app, host="127.0.0.1", port=8000, log_level="info")
    server = uvicorn.Server(config)

    # On Windows, spawning the `claude` CLI subprocess (how the SDK connects)
    # requires the Proactor event loop. Run uvicorn's server coroutine inside a
    # Proactor loop; otherwise it defaults to a Selector loop, which cannot
    # create subprocesses and fails with "Failed to start Claude Code".
    if sys.platform == "win32":
        with asyncio.Runner(loop_factory=asyncio.ProactorEventLoop) as runner:
            runner.run(server.serve())
    else:
        asyncio.run(server.serve())
