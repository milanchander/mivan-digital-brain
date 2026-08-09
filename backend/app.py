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
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

from fastapi import FastAPI, HTTPException, WebSocket
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


def load_knowledge_base():
    """Pre-load core knowledge files at startup
    so the agent does not need to read them
    for every question."""
    knowledge = {}
    files_to_preload = [
        ("l1", "knowledge/L1-enterprise/mivan-enterprise-context.md"),
        ("l2_commercial", "knowledge/L2-domain/commercial-claims.md"),
        ("l2_ma", "knowledge/L2-domain/medicare-advantage.md"),
        ("l2_medicaid", "knowledge/L2-domain/medicaid-managed-care.md"),
        ("l3", "knowledge/L3-systems/mivan-system-landscape.md"),
        ("routing", "knowledge/routing-map.md"),
        ("ghosts", "knowledge/ghost-nodes.md"),
    ]
    for key, path in files_to_preload:
        full_path = PROJECT_ROOT / path
        if full_path.exists():
            content = full_path.read_text(encoding="utf-8")
            knowledge[key] = content[:8000]
        else:
            knowledge[key] = f"[{path} not found]"
    return knowledge


KNOWLEDGE_BASE = load_knowledge_base()

PRELOADED_CONTEXT = f"""
---
PRE-LOADED KNOWLEDGE (use this before reading files):

## L1 — Enterprise Context
{KNOWLEDGE_BASE['l1'][:3000]}

## L2 — Commercial Claims
{KNOWLEDGE_BASE['l2_commercial'][:2000]}

## L2 — Medicare Advantage
{KNOWLEDGE_BASE['l2_ma'][:2000]}

## L2 — Medicaid
{KNOWLEDGE_BASE['l2_medicaid'][:1000]}

## L3 — System Landscape (summary)
{KNOWLEDGE_BASE['l3'][:3000]}

## Ghost Nodes Registry
{KNOWLEDGE_BASE['ghosts'][:2000]}

---
INSTRUCTION: Answer from the pre-loaded knowledge above when possible. Only use file reading tools (Read/Grep/Glob) when the question requires deeper detail not covered above. This dramatically reduces response time.
---
"""

print(f"Knowledge base pre-loaded: {len(KNOWLEDGE_BASE)} files ready")
print(f"Context size: ~{sum(len(v) for v in KNOWLEDGE_BASE.values())} chars")

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


# ── Contributions (Knowledge Contribution Framework) ──
# Approve writes the curated draft to the MEM layer on disk. Graduation to a
# formal L1-L6 node is a deliberate, separate, agent-driven pass — NOT automated.
CONTRIB_DIR = PROJECT_ROOT / "knowledge" / "MEM" / "contributions"
GHOST_ID_RE = re.compile(r"^[A-Z0-9-]+$")


@app.post("/contributions/save")
def save_contribution(payload: dict):
    # 1. Validate required, non-empty fields.
    required = ["ghostNodeId", "contributorName", "targetLayer", "markdown", "submittedAt"]
    missing = [k for k in required if not str(payload.get(k, "")).strip()]
    if missing:
        raise HTTPException(status_code=400, detail="Missing or empty field(s): " + ", ".join(missing))

    ghost_id = str(payload["ghostNodeId"]).strip()
    # 2. Path-traversal guard — reject anything that is not uppercase alnum + hyphens.
    if not GHOST_ID_RE.match(ghost_id):
        raise HTTPException(
            status_code=400,
            detail="ghostNodeId must be uppercase letters, digits, and hyphens only (got: " + ghost_id + ")",
        )

    markdown = payload["markdown"]
    try:
        # 3. Build path + ensure directory exists.
        CONTRIB_DIR.mkdir(parents=True, exist_ok=True)
        datestr = datetime.now().strftime("%Y-%m-%d")
        stem = f"{ghost_id}-{datestr}"
        target = CONTRIB_DIR / f"{stem}.md"
        # 4. Never overwrite — append a numeric suffix.
        n = 2
        while target.exists():
            target = CONTRIB_DIR / f"{stem}-{n}.md"
            n += 1
        # 5. Write UTF-8.
        target.write_text(markdown, encoding="utf-8")
    except Exception as e:  # 7. Surface the real error.
        raise HTTPException(status_code=500, detail="Filesystem error: " + str(e))

    rel = target.relative_to(PROJECT_ROOT).as_posix()
    # 6. Success.
    return {
        "saved": True,
        "path": rel,
        "message": "Contribution saved to MEM layer. Graduate to a formal layer when validated.",
    }


@app.get("/contributions/list")
def list_contributions():
    if not CONTRIB_DIR.exists():
        return {"contributions": []}
    name_re = re.compile(r"^(.*)-(\d{4}-\d{2}-\d{2})(?:-\d+)?\.md$")
    out = []
    for f in sorted(CONTRIB_DIR.glob("*.md")):
        st = f.stat()
        m = name_re.match(f.name)
        out.append({
            "filename": f.name,
            "path": f.relative_to(PROJECT_ROOT).as_posix(),
            "ghostNodeId": m.group(1) if m else f.stem,
            "date": m.group(2) if m else None,
            "size": st.st_size,
            "modified": datetime.fromtimestamp(st.st_mtime, tz=timezone.utc).isoformat(),
        })
    return {"contributions": out}


# Minimal prompt for the curation path — it synthesizes the supplied Q&A and must
# NOT read the knowledge layer, which is what burns turns on long inputs.
CURATE_SYSTEM = """You are the Mivan Digital Brain knowledge curator. A domain expert has completed a knowledge contribution interview (or filled a template). Synthesize the supplied questions and answers into a properly formatted markdown knowledge entry.

Work ONLY from the content provided in the message. Do NOT read files, search the codebase, or use any tools — everything you need is already in the message. Output only the requested markdown."""


def build_options(frontend_system_prompt: str = "", mode: str = "chat") -> ClaudeAgentOptions:
    """Build agent options for a request.

    mode="chat"   → full grounding + file tools, small turn budget (fast Q&A).
    mode="curate" → minimal prompt, NO tools, larger turn budget (long synthesis).
    """
    if mode == "curate":
        append = CURATE_SYSTEM
        if frontend_system_prompt:
            append += "\n\n" + frontend_system_prompt
        max_turns = 25
        allowed_tools: list[str] = []          # pure synthesis — no file reads
    else:
        append = BASE_SYSTEM + PRELOADED_CONTEXT
        if frontend_system_prompt:
            append += "\n\n--- Additional domain context ---\n\n" + frontend_system_prompt
        max_turns = 8
        allowed_tools = ["Read", "Grep", "Glob"]

    return ClaudeAgentOptions(
        model=MODEL,
        setting_sources=["user", "project", "local"],  # no API key needed
        permission_mode="bypassPermissions",
        cwd=str(PROJECT_ROOT),
        max_turns=max_turns,
        include_partial_messages=True,  # token-by-token streaming
        system_prompt={
            "type": "preset",
            "preset": "claude_code",
            "append": append,
        },
        allowed_tools=allowed_tools,
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

        mode = body.get("mode", "chat")
        first = body.get("message", "")

        if mode == "curate":
            # Curation: the frontend's `system` field is the curator system prompt,
            # and `message` is the interview Q&A. No page-context wrapping, no tools.
            options = build_options(body.get("system", ""), mode="curate")
        else:
            options = build_options(body.get("system_prompt", ""), mode="chat")
            # First message — optionally prefix the current page context.
            # Accept both old ("page_context") and new ("system") field names.
            page_ctx = (body.get("system") or body.get("page_context") or "").strip()
            if page_ctx:
                first = (
                    "The user is currently viewing this page in the portal:\n\n"
                    f"<page_context>\n{page_ctx}\n</page_context>\n\n"
                    f"User question: {first}"
                )

        client = ClaudeSDKClient(options=options)
        await client.connect()
        await send({"type": "status", "message": "Connected to the Digital Brain."})

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
