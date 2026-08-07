# 11 — Conversation Resume & Session Persistence

## How Conversation Resume Works

The Claude Agent SDK stores conversation history in `.jsonl` files locally. When you pass `resume=session_id` and `continue_conversation=True`, the SDK loads the full conversation from disk and continues where it left off.

```
Session 1: User asks question → AI responds → session_id = "abc123"
                                                    │
                                                    ▼ (stored on disk)
                                          SDK session files (.jsonl)
                                                    │
Session 2: resume="abc123" → SDK loads history → conversation continues
```

## Extracting session_id

The `session_id` comes from `ResultMessage` at the end of each query:

```python
from claude_agent_sdk import ResultMessage

async for message in client.receive_response():
    if isinstance(message, ResultMessage):
        session_id = getattr(message, "session_id", None)
        # Save this for later resume
```

## Where to Store session_id

Store the session_id alongside whatever entity the conversation belongs to:

```python
# After initial conversation
store.save_conversation(
    entity_id=item_id,
    session_id=session_id,
    # ... other metadata
)

# When resuming
saved = store.get_conversation(entity_id)
resume_session_id = saved["session_id"]
```

Examples of entities with session_ids:
- **Chat session** → `chats.session_id`
- **Document analysis** → `analyses.session_id`
- **Generated content** → `generations.generation_session_id`
- **Test execution** → `executions.session_id`

## Resume Pattern

```python
async def handle_resume(ws, body):
    """Resume a previous conversation."""
    session_id = body.get("session_id")
    message = body.get("message", "")
    model = body.get("model")

    if not session_id or not message:
        await send({"type": "error", "message": "Resume requires session_id and message"})
        return

    # CRITICAL: model is REQUIRED on resume
    options = ClaudeAgentOptions(
        model=model or config.DEFAULT_MODEL,
        resume=session_id,
        continue_conversation=True,
        setting_sources=config.SETTING_SOURCES,
        permission_mode=config.PERMISSION_MODE,
        allowed_tools=allowed_tools,      # Must re-specify
        agents=get_all_agents(),          # Must re-specify
        mcp_servers=mcp_servers,          # Must re-specify
        max_turns=config.MAX_TURNS,
    )

    client = ClaudeSDKClient(options=options)
    await client.connect()

    await client.query(message)
    async for msg in client.receive_response():
        # ... handle messages (same as initial query)
        pass

    await client.disconnect()
```

### Key Rules for Resume

1. **`model` is REQUIRED** — Always pass the model on resume. The SDK needs to know which model to use.

2. **Re-attach MCP servers** — Resume path must re-launch all MCP servers (Playwright, Jira, DB, etc.). The previous session's MCP processes are gone.

3. **Re-specify `allowed_tools`** — Tool permissions must be set on each session, including resumes.

4. **Re-attach `agents`** — Subagent definitions must be passed again.

5. **`setting_sources` still required** — Authentication doesn't carry over; specify it on every session.

## Three Conversation Patterns

### Pattern 1: Follow-Up (Same WebSocket, Same Client)

The WebSocket stays open. The `ClaudeSDKClient` is still connected. Just call `.query()` again:

```python
# Initial query
await client.query("Analyze this document")
async for msg in client.receive_response(): ...

# Follow-up (same connection)
await client.query("What about the second section?")
async for msg in client.receive_response(): ...
```

**Frontend sends:**
```json
{ "type": "follow_up", "message": "What about the second section?" }
```

### Pattern 2: Resume (New WebSocket, New Client, Same Conversation)

The user closed the tab or navigated away. Open a new WebSocket and resume:

```python
options = ClaudeAgentOptions(
    model="claude-sonnet-4-6",
    resume=saved_session_id,
    continue_conversation=True,
    setting_sources=["user", "project", "local"],
    ...
)
client = ClaudeSDKClient(options=options)
await client.connect()
await client.query("Continue from where we left off")
```

**Frontend sends:**
```json
{ "type": "resume", "session_id": "abc123", "message": "Continue", "model": "claude-sonnet-4-6" }
```

### Pattern 3: New Conversation

Start fresh. No `resume`, no `continue_conversation`:

```python
options = ClaudeAgentOptions(
    model="claude-sonnet-4-6",
    setting_sources=["user", "project", "local"],
    ...
)
client = ClaudeSDKClient(options=options)
await client.connect()
await client.query("New topic entirely")
```

**Frontend sends:**
```json
{ "message": "New topic entirely" }
```

## WebSocket Handler with All Three Patterns

```python
async def handle_chat(ws: WebSocket):
    await ws.accept()

    async def send(payload):
        try:
            await ws.send_text(json.dumps(payload))
        except Exception:
            pass

    client = None
    try:
        raw = await ws.receive_text()
        body = json.loads(raw)

        # ── Resume path ──
        if body.get("type") == "resume":
            options = ClaudeAgentOptions(
                model=body.get("model") or config.DEFAULT_MODEL,
                resume=body["session_id"],
                continue_conversation=True,
                setting_sources=config.SETTING_SOURCES,
                permission_mode=config.PERMISSION_MODE,
                allowed_tools=build_allowed_tools(),
                max_turns=config.MAX_TURNS,
            )
            client = ClaudeSDKClient(options=options)
            await client.connect()
            await client.query(body["message"])
            # ... stream response
            # ... enter follow-up loop

        # ── New conversation path ──
        else:
            options = ClaudeAgentOptions(
                model=body.get("model") or config.DEFAULT_MODEL,
                setting_sources=config.SETTING_SOURCES,
                permission_mode=config.PERMISSION_MODE,
                allowed_tools=build_allowed_tools(),
                max_turns=config.MAX_TURNS,
            )
            client = ClaudeSDKClient(options=options)
            await client.connect()
            await client.query(body["message"])
            # ... stream response

        # ── Follow-up loop (both paths converge here) ──
        while True:
            raw = await asyncio.wait_for(ws.receive_text(), timeout=900)
            msg = json.loads(raw)
            if msg.get("type") == "follow_up" and msg.get("message"):
                await client.query(msg["message"])
                # ... stream response
            elif msg.get("type") == "close":
                break

    finally:
        if client:
            try:
                await client.disconnect()
            except Exception:
                pass
```

## Resume Checklist — Everything That Must Be Re-Attached

When resuming a conversation, the SDK restores the conversation history from disk. But everything ELSE must be re-created:

| What | Must Re-Attach? | Why |
|------|-----------------|-----|
| `model` | **YES — REQUIRED** | SDK needs to know which model to call |
| `setting_sources` | **YES** | Authentication doesn't carry over |
| `mcp_servers` | **YES** | Previous MCP processes are gone — they must be re-launched |
| `allowed_tools` | **YES** | Tool permissions are per-session |
| `agents` | **YES** | Subagent definitions must be re-registered |
| `permission_mode` | **YES** | Autonomous/interactive mode per-session |
| `can_use_tool` + `hooks` | **YES** (if interactive) | Permission bridge must be rebuilt |
| `output_format` | **YES** (if structured) | Schema constraints are per-session |
| `system_prompt` | No | Carried in conversation history |

### Complete Resume Example with Full MCP Re-Attachment

```python
async def handle_resume(ws, body, send):
    """Resume with full MCP server + permission re-attachment."""
    session_id = body["session_id"]
    message = body["message"]
    model = body.get("model") or config.DEFAULT_MODEL
    autonomous = body.get("autonomous", True)

    await send({"type": "status", "message": "Resuming conversation..."})

    # Re-build MCP servers (previous processes are dead)
    mcp_servers = {}
    jira_configs = [c for c in store.list_mcp_configs() if c["type"] == "jira" and c["enabled"]]
    if jira_configs:
        mcp_servers["mcp-atlassian"] = unwrap_mcp_config(jira_configs[0]["config"])
    db_configs = [c for c in store.list_mcp_configs() if c["type"] == "database" and c["enabled"]]
    if db_configs:
        mcp_servers["database"] = unwrap_mcp_config(db_configs[0]["config"])

    # Re-build allowed tools with MCP wildcards
    allowed_tools = ["Read", "Grep", "Glob", "Skill", "Agent", "ToolSearch"]
    for name in mcp_servers:
        allowed_tools.append(f"mcp__{name}__*")

    # Re-build permission bridge if interactive
    perm_extras = {}
    if not autonomous:
        can_use_tool, ws_listener, msg_queue, hooks = build_permission_bridge(send, ws)
        perm_extras = {"can_use_tool": can_use_tool, "hooks": hooks}

    options = ClaudeAgentOptions(
        model=model,
        resume=session_id,
        continue_conversation=True,
        setting_sources=config.SETTING_SOURCES,
        permission_mode="bypassPermissions" if autonomous else "default",
        allowed_tools=allowed_tools,
        agents=get_all_agents(),
        mcp_servers=mcp_servers,
        max_turns=config.MAX_TURNS,
        **perm_extras,
    )

    client = ClaudeSDKClient(options=options)
    await client.connect()

    # Start permission listener if interactive
    listener_task = None
    if not autonomous:
        listener_task = asyncio.create_task(ws_listener())

    try:
        await client.query(message)
        result = await stream_response(client, send)
        await send({
            "type": "complete",
            "session_id": session_id,
            "cost_usd": result["cost"],
            "conversation_active": True,
        })
        # Enter follow-up loop...
    finally:
        if listener_task:
            listener_task.cancel()
        await client.disconnect()
```

## Storing session_id Per Entity Type

Different features store session_id in different places:

```python
# Chat conversation → conversations table
store.save_conversation(conversation_id, session_id=sid)

# Content generation → the generated entity (suite, document, report, etc.)
store.update_entity(entity_id, generation_session_id=sid)

# Per-item generation → individual record
store.update_item(item_id, data_session_id=sid)

# Analysis run → analysis record
store.save_analysis(analysis_id, session_id=sid, status="complete")
```

The key insight: store `session_id` alongside whatever entity the conversation produced, so you can resume from the entity's detail page.

## Session Lifetime

SDK session files are stored locally (typically in `~/.claude/` or a temp directory). They persist across process restarts, which is what makes resume work.

**Important considerations:**
- Session files grow with conversation length. Very long conversations use more disk.
- There's no built-in session expiry — implement your own cleanup if needed.
- Session files are local to the machine. Resume won't work across different servers unless the session storage is shared.
- The `session_id` is an opaque string — don't parse it or make assumptions about its format.
- Always store the `model` alongside `session_id` so you know which model to resume with.
