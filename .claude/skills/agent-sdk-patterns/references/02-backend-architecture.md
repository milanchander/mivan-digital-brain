# 02 — Backend Architecture for LLM Apps

## Recommended Project Structure

```
my-llm-app/
├── backend/
│   ├── main.py              # FastAPI entry point, router mounting, startup hooks
│   ├── config.py            # All configuration from env vars with defaults
│   ├── middleware.py         # Request ID tracing, global error handler
│   ├── agents/
│   │   ├── __init__.py      # Re-exports
│   │   ├── definitions.py   # AgentDefinition subagents
│   │   ├── prompts.py       # System prompt builders
│   │   ├── schemas.py       # JSON schemas for output_format (strict: True)
│   │   └── validators.py    # Pydantic validators for AI output
│   ├── services/
│   │   ├── __init__.py
│   │   ├── mcp_loader.py    # MCP server config builder
│   │   └── tool_utils.py    # Tool name mapping, suppression, audit
│   ├── routes/
│   │   ├── __init__.py
│   │   ├── health.py        # GET /api/health, GET /api/stats
│   │   └── items.py         # Your domain CRUD endpoints
│   ├── ws_handlers/
│   │   ├── __init__.py
│   │   └── chat.py          # WebSocket handler for AI conversations
│   ├── store/
│   │   ├── __init__.py      # Re-exports all CRUD functions
│   │   └── db.py            # Database connection + schema
│   ├── .env                 # Local env vars (gitignored)
│   └── requirements.txt
├── frontend/                # React, Vue, or vanilla HTML
│   └── ...
├── .claude/
│   ├── settings.json        # Project-level Claude settings
│   └── settings.local.json  # Local overrides (gitignored)
└── README.md
```

## Config Module

Centralize all configuration. Never scatter env vars across files.

```python
# backend/config.py
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent

# App
HOST = os.getenv("APP_HOST", "0.0.0.0")
PORT = int(os.getenv("APP_PORT", "8000"))
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()

# Claude Agent SDK
DEFAULT_MODEL = os.getenv("APP_MODEL", "claude-sonnet-4-6")
MAX_TURNS = int(os.getenv("APP_MAX_TURNS", "100"))
MAX_COST_USD = float(os.getenv("APP_MAX_COST_USD", "50.0"))
PERMISSION_MODE = os.getenv("APP_PERMISSION_MODE", "bypassPermissions")
SETTING_SOURCES: list[str] = ["user", "project", "local"]

# Session limits
SESSION_MAX_IDLE_SECONDS = int(os.getenv("APP_SESSION_IDLE_MAX", "900"))

# CORS
CORS_ORIGINS: list[str] = os.getenv("APP_CORS_ORIGINS", "*").split(",")
```

## Main Entry Point

```python
# backend/main.py
import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

import config
from middleware import RequestIDMiddleware
from routes import health, items
from ws_handlers import chat

logging.basicConfig(level=config.LOG_LEVEL)

app = FastAPI(title="My LLM App", version="1.0.0")

# Middleware
app.add_middleware(RequestIDMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=config.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# REST routes
app.include_router(health.router, prefix="/api")
app.include_router(items.router, prefix="/api")

# WebSocket endpoints
app.add_api_websocket_route("/ws/chat", chat.handle_chat)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host=config.HOST, port=config.PORT, reload=True)
```

## Middleware

```python
# backend/middleware.py
import uuid
import logging
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse

log = logging.getLogger(__name__)


class RequestIDMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4())[:8])
        request.state.request_id = request_id
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        return response


async def global_exception_handler(request: Request, exc: Exception):
    request_id = getattr(request.state, "request_id", "unknown")
    log.exception(f"[{request_id}] Unhandled error")
    return JSONResponse(
        status_code=500,
        content={"error": "Internal server error", "request_id": request_id},
    )
```

## Route Pattern

All routes should use try/except with structured logging:

```python
# backend/routes/health.py
import logging
from fastapi import APIRouter, HTTPException

log = logging.getLogger(__name__)
router = APIRouter()


@router.get("/health")
async def health():
    return {"status": "ok"}


@router.get("/stats")
async def stats():
    try:
        import store
        return store.get_stats()
    except Exception:
        log.exception("Failed to get stats")
        raise HTTPException(500, "Failed to get stats")
```

## Requirements

```
# backend/requirements.txt

# AI agent engine — NO API KEY NEEDED with setting_sources
claude-agent-sdk>=0.1.48

# Web framework
fastapi>=0.104.0
uvicorn[standard]>=0.24.0

# Data validation
pydantic>=2.0

# Database (pick one)
# aiosqlite>=0.19.0      # SQLite (development)
# asyncpg>=0.29.0        # PostgreSQL (production)
```

## Key Architecture Decisions

### AI operations are WebSocket-only

REST endpoints handle CRUD. AI-powered operations (chat, generation, analysis) use WebSocket handlers for real-time streaming. Never create REST endpoints that block for 30+ seconds waiting for AI responses.

```
REST endpoints:   CRUD operations (fast, synchronous)
WebSocket:        AI conversations (streaming, async, long-running)
```

### Separate agents/ from ws_handlers/

Keep AI engine logic (prompts, schemas, validators, subagents) separate from WebSocket plumbing. This lets you test AI logic independently and reuse it across different handlers.

### Store is a thin re-export layer

The `store/__init__.py` re-exports all CRUD functions from submodules. Callers use `import store; store.create_item(...)` without knowing the internal module structure.

### Config is a single-file package

All environment variables in one place. Every other module imports `config` and reads values. No scattered `os.getenv()` calls.
