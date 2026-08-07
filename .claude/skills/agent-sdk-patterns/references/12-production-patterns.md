# 12 — Production Patterns

## Error Handling

### Always Disconnect in Finally

```python
client = None
try:
    client = ClaudeSDKClient(options=options)
    await client.connect()
    await client.query(prompt)
    async for message in client.receive_response():
        # ... handle messages
        pass
except WebSocketDisconnect:
    log.info("Client disconnected")
except Exception as exc:
    log.exception("Handler error")
    await send({"type": "error", "message": str(exc)})
finally:
    if client:
        try:
            await client.disconnect()
        except Exception:
            pass  # Ignore cleanup errors
```

### WebSocket Send Wrapper

Never let a failed send crash the handler:

```python
async def send(payload: dict):
    """Send JSON to WebSocket, silently ignore if closed."""
    try:
        await ws.send_text(json.dumps(payload))
    except Exception:
        pass
```

### Route-Level Error Handling

Wrap every REST route in try/except:

```python
@router.get("/api/items/{item_id}")
async def get_item(item_id: str):
    try:
        item = store.get_item(item_id)
        if not item:
            raise HTTPException(404, "Item not found")
        return item
    except HTTPException:
        raise
    except Exception:
        log.exception("Failed to get item")
        raise HTTPException(500, "Internal server error")
```

## Cost Control

### Per-Session Cost Ceiling

```python
MAX_COST_USD = float(os.getenv("APP_MAX_COST_USD", "50.0"))

# In your handler, check after each ResultMessage
if isinstance(message, ResultMessage):
    cost = getattr(message, "total_cost_usd", None)
    if cost and cost > MAX_COST_USD:
        log.warning(f"Session exceeded cost limit: ${cost:.4f} > ${MAX_COST_USD}")
        await send({"type": "error", "message": f"Cost limit exceeded (${cost:.2f})"})
        break  # Stop the session
```

### Configurable Limits

```python
# config.py
MAX_TURNS = int(os.getenv("APP_MAX_TURNS", "100"))
MAX_COST_USD = float(os.getenv("APP_MAX_COST_USD", "50.0"))
SESSION_MAX_IDLE_SECONDS = int(os.getenv("APP_SESSION_IDLE_MAX", "900"))
RESULT_TEXT_MAX_LENGTH = int(os.getenv("APP_RESULT_TEXT_MAX", "2000"))
```

### Per-Request Overrides

Let clients override limits per request (with a ceiling):

```python
effective_max_turns = min(
    body.get("max_turns") or config.MAX_TURNS,
    config.MAX_TURNS,  # Never exceed the system limit
)
```

## Security

### Sanitize Audit Data

Never persist credentials, tokens, or PII from AI tool calls:

```python
import re

_SENSITIVE_PATTERNS = [
    re.compile(r'(?i)(password|passwd|secret|token|api.?key|authorization)\s*[:=]\s*\S+'),
    re.compile(r'(?i)bearer\s+\S+'),
    re.compile(r'\b\d{3}-\d{2}-\d{4}\b'),  # SSN pattern
]


def sanitize_audit_data(data) -> dict | str | list:
    """Recursively redact sensitive values from audit data."""
    if isinstance(data, str):
        result = data
        for pattern in _SENSITIVE_PATTERNS:
            result = pattern.sub('[REDACTED]', result)
        return result
    elif isinstance(data, dict):
        return {k: sanitize_audit_data(v) for k, v in data.items()}
    elif isinstance(data, list):
        return [sanitize_audit_data(item) for item in data]
    return data
```

### Restrict Tool Access

Give AI the minimum tools it needs:

```python
# Knowledge base chatbot: read-only
allowed_tools = ["Read", "Grep", "Glob", "Skill"]

# Document analyzer: read + MCP
allowed_tools = ["Read", "Grep", "Glob", "mcp__filesystem__*"]

# Code generator: more access, but no shell
allowed_tools = ["Read", "Write", "Edit", "Grep", "Glob"]

# Full access (use with permission bridge for safety)
allowed_tools = ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "Agent", "Skill"]
```

### Configurable Text Length Limits

Prevent unbounded storage:

```python
RESULT_TEXT_MAX_LENGTH = 2000
AUDIT_DETAIL_MAX_LENGTH = 200

# When saving
result_text = result_text[:RESULT_TEXT_MAX_LENGTH] if result_text else ""
audit_detail = detail[:AUDIT_DETAIL_MAX_LENGTH] if detail else ""
```

## Request Tracing

Add request IDs to all requests for debugging:

```python
import uuid
from starlette.middleware.base import BaseHTTPMiddleware


class RequestIDMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4())[:8])
        request.state.request_id = request_id
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        return response
```

## Session Idle Timeout

Close idle WebSocket connections to free resources:

```python
try:
    raw = await asyncio.wait_for(
        ws.receive_text(),
        timeout=config.SESSION_MAX_IDLE_SECONDS,  # 900 seconds = 15 minutes
    )
except asyncio.TimeoutError:
    await send({"type": "status", "message": "Session timed out due to inactivity"})
    break  # Exit the follow-up loop
```

## Logging

Structured logging for debugging:

```python
import logging
log = logging.getLogger("myapp.ws.chat")

# At session start
log.info(f"New chat session: model={model}, max_turns={max_turns}")

# At tool calls
log.debug(f"Tool call: {tool_name} ({detail})")

# At completion
log.info(f"Session complete: cost=${cost:.4f}, turns={turns}, duration={duration}ms")

# At errors
log.exception("Handler error")  # Includes full traceback
```

## Deployment Options

### Local Development

```bash
cd backend
python main.py  # or uvicorn main:app --reload
```

### Docker

```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && \
    playwright install --with-deps chromium

COPY backend/ .

# NOTE: Claude Agent SDK needs access to ~/.claude/ for authentication
# Mount your local .claude directory or set ANTHROPIC_API_KEY
# If using enterprise Claude Code, the host's ~/.claude must be accessible

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Docker caveat**: The SDK reads from `~/.claude/` for authentication. In a container:
- **Option A**: Mount `~/.claude/` from the host: `docker run -v ~/.claude:/root/.claude ...`
- **Option B**: Set `ANTHROPIC_API_KEY` env var (if you have one): `docker run -e ANTHROPIC_API_KEY=sk-... ...`
- **Option C**: Use a persistent volume for `.claude` and run `claude` inside the container first

### Startup Script

```bash
#!/bin/bash
# start.sh

# Kill stale processes
for port in 8000 3000; do
    lsof -ti :$port | xargs kill -9 2>/dev/null
done

# Start backend
cd backend
python main.py &
BACKEND_PID=$!

# Start frontend (if using React/Vite)
cd ../frontend
npm run dev &
FRONTEND_PID=$!

echo "Backend: http://localhost:8000"
echo "Frontend: http://localhost:3000"

wait $BACKEND_PID $FRONTEND_PID
```

## Checklist Before Going Live

- [ ] `setting_sources=["user", "project", "local"]` on every ClaudeAgentOptions
- [ ] `strict: True` on every `output_format`
- [ ] Pydantic validation on all AI output before DB writes
- [ ] Error handling: try/finally with `client.disconnect()` in every handler
- [ ] Cost control: MAX_COST_USD configured and checked
- [ ] Session timeout: idle connections cleaned up
- [ ] Allowed tools: minimal set for each use case
- [ ] Audit sanitization: no credentials in logs or DB
- [ ] Request tracing: X-Request-ID on all requests
- [ ] CORS: configured for your frontend domain(s)
- [ ] Logging: structured, with log levels
- [ ] Resume: model passed on all resume paths
- [ ] Resume: MCP servers re-attached on resume paths
