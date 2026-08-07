# Mivan Digital Brain — Chat Backend

Streams answers from Claude, grounded in the `knowledge/` markdown files (L1–L6),
over a WebSocket. **No Anthropic API key required** — authentication piggybacks on
your local Claude Code login via the Agent SDK's `setting_sources`.

## Prerequisites

- Python 3.10+
- Claude Code installed and logged in (`claude` works in your terminal)

## Run

```powershell
# From this backend/ directory
./start.ps1
```

That creates a `.venv`, installs dependencies, and starts the server on
`http://127.0.0.1:8000`. The chat WebSocket is at `ws://127.0.0.1:8000/ws/chat`.

Health check: open `http://127.0.0.1:8000/health`.

Manual alternative:

```powershell
python -m venv .venv
./.venv/Scripts/Activate.ps1
pip install -r requirements.txt
python app.py
```

## Then open the portal

Open `../index.html` in your browser, click **Ask the Digital Brain**, and start
chatting. The chat connects to the backend automatically — no key prompt.

## How it works

- `setting_sources=["user","project","local"]` → the SDK reads your Claude Code
  auth token instead of an API key.
- The agent runs with `cwd` set to the project root and is given read-only
  `Read` / `Grep` / `Glob` tools, so it searches and cites the real
  `knowledge/L1–L6` files.
- Responses stream token-by-token (`include_partial_messages=True`).
