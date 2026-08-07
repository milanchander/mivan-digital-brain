# 03 — SDK Client Patterns

## Use ClaudeSDKClient (Always)

**`ClaudeSDKClient` is the preferred pattern for ALL use cases** — chat, generation, analysis, batch jobs. It supports everything: multi-turn conversations, follow-ups, session resume, AND one-shot queries (just call `.query()` once then disconnect).

The SDK also exports a standalone `query()` function, but it has limitations (no follow-up, no session resume, no conversation continuation). It exists for backwards compatibility — avoid it in new code.

| Pattern | Use For |
|---------|---------|
| `ClaudeSDKClient` (multi-turn) | Chat, interactive tools, anything with follow-ups |
| `ClaudeSDKClient` (single query) | One-shot generation, structured output, batch jobs |
| `query()` standalone | Legacy code only — avoid in new code |

## Pattern 1: Multi-Turn Conversation (ClaudeSDKClient)

```python
from claude_agent_sdk import (
    AssistantMessage,
    ClaudeAgentOptions,
    ClaudeSDKClient,
    ResultMessage,
    TextBlock,
    ToolUseBlock,
)

async def run_conversation(user_message: str, send_to_frontend):
    options = ClaudeAgentOptions(
        model="claude-sonnet-4-6",
        setting_sources=["user", "project", "local"],
        permission_mode="bypassPermissions",
        max_turns=50,
        include_partial_messages=True,  # Enable StreamEvent for token streaming
    )

    client = ClaudeSDKClient(options=options)
    await client.connect()

    try:
        # Initial query
        await client.query(user_message)

        async for message in client.receive_response():
            if isinstance(message, AssistantMessage):
                for block in message.content or []:
                    if isinstance(block, TextBlock) and block.text.strip():
                        await send_to_frontend({
                            "type": "text",
                            "content": block.text.strip(),
                        })
                    elif isinstance(block, ToolUseBlock):
                        await send_to_frontend({
                            "type": "tool_call",
                            "tool": block.name,
                            "input": block.input,
                        })

            if isinstance(message, ResultMessage):
                cost = getattr(message, "total_cost_usd", None)
                session_id = getattr(message, "session_id", None)
                await send_to_frontend({
                    "type": "complete",
                    "cost_usd": cost,
                    "session_id": session_id,
                })

        # Client stays alive — follow-up queries reuse the same conversation
        # await client.query("Tell me more about point 3")
        # async for message in client.receive_response(): ...

    finally:
        await client.disconnect()
```

### Lifecycle

```
ClaudeSDKClient(options)     # 1. Create with options
    │
await client.connect()       # 2. Establish connection
    │
await client.query(prompt)   # 3. Send first message
    │
async for msg in client.receive_response():
    # AssistantMessage       # 4a. AI text + tool calls (streaming)
    # StreamEvent            # 4b. Raw SSE events (optional)
    # ResultMessage          # 4c. Final result with metadata
    │
await client.query(followup) # 5. Follow-up (same conversation)
    │
async for msg in client.receive_response():
    # ... more messages      # 6. Stream follow-up response
    │
await client.disconnect()   # 7. Cleanup
```

## Pattern 2: One-Shot Query

For single-use operations where you don't need follow-ups:

```python
async def generate_summary(text: str) -> dict:
    options = ClaudeAgentOptions(
        model="claude-sonnet-4-6",
        setting_sources=["user", "project", "local"],
        permission_mode="bypassPermissions",
        max_turns=10,
        output_format={
            "type": "json_schema",
            "schema": {
                "type": "object",
                "properties": {
                    "summary": {"type": "string"},
                    "key_points": {
                        "type": "array",
                        "items": {"type": "string"},
                    },
                },
                "required": ["summary", "key_points"],
            },
            "strict": True,
        },
    )

    client = ClaudeSDKClient(options=options)
    await client.connect()

    try:
        await client.query(f"Summarize this text:\n\n{text}")

        result_data = None
        async for message in client.receive_response():
            if isinstance(message, ResultMessage):
                structured = getattr(message, "structured_output", None)
                if structured:
                    result_data = structured
                else:
                    import json
                    result_text = getattr(message, "result", "") or ""
                    result_data = json.loads(result_text)

        return result_data or {"summary": "", "key_points": []}

    finally:
        await client.disconnect()
```

## Message Types You Receive

### AssistantMessage

Contains the AI's text output and tool calls:

```python
if isinstance(message, AssistantMessage):
    for block in message.content or []:
        if isinstance(block, TextBlock):
            print(block.text)  # AI's text output
        elif isinstance(block, ToolUseBlock):
            print(block.name)   # Tool name (e.g., "Read", "Grep")
            print(block.input)  # Tool input dict
            print(block.id)     # Tool use ID
```

### ToolResultBlock

Contains results from tool executions:

```python
from claude_agent_sdk import ToolResultBlock

if isinstance(block, ToolResultBlock):
    print(block.tool_use_id)  # Matches ToolUseBlock.id
    print(block.content)      # Tool result content
    print(block.is_error)     # Whether tool failed
```

### ResultMessage

Final message with session metadata:

```python
if isinstance(message, ResultMessage):
    cost = getattr(message, "total_cost_usd", None)      # float: total USD spent
    turns = getattr(message, "num_turns", None)           # int: conversation turns
    duration = getattr(message, "duration_ms", None)      # int: milliseconds elapsed
    session_id = getattr(message, "session_id", None)     # str: for resume later
    structured = getattr(message, "structured_output", None)  # dict: if output_format used
    result_text = getattr(message, "result", "") or ""    # str: raw text result
```

### StreamEvent (optional, for raw streaming)

```python
from claude_agent_sdk.types import StreamEvent

if isinstance(message, StreamEvent):
    event = message.event
    if isinstance(event, dict) and event.get("type") == "content_block_delta":
        delta = event.get("delta", {})
        if delta.get("type") == "text_delta":
            text_chunk = delta.get("text", "")
            # Send to frontend for character-by-character streaming
```

## Streaming Helper Pattern

Extract the streaming logic into a reusable function:

```python
async def stream_response(client, send):
    """Stream SDK response to a WebSocket send function.
    Returns (result_text, cost, turns, duration, session_id).
    """
    result_text = ""
    cost = turns = duration = session_id = None

    async for message in client.receive_response():
        if isinstance(message, AssistantMessage):
            for block in message.content or []:
                if isinstance(block, TextBlock) and block.text.strip():
                    await send({"type": "thought", "text": block.text.strip()})
                elif isinstance(block, ToolUseBlock):
                    await send({"type": "tool_call", "tool": block.name})

        if isinstance(message, ResultMessage):
            result_text = getattr(message, "result", "") or ""
            cost = getattr(message, "total_cost_usd", None)
            turns = getattr(message, "num_turns", None)
            duration = getattr(message, "duration_ms", None)
            session_id = getattr(message, "session_id", None)

    return result_text, cost, turns, duration, session_id
```

## Pattern 3: Standalone query() Function (AVOID — Legacy)

> **Prefer `ClaudeSDKClient` for all new code.** The standalone `query()` function exists for backwards compatibility but cannot resume conversations or accept follow-ups. Included here for documentation completeness only.

The SDK also exports a standalone `query()` function — an async generator that handles the client lifecycle internally. No `connect()`/`disconnect()` needed:

```python
from claude_agent_sdk import (
    AssistantMessage,
    ClaudeAgentOptions,
    ResultMessage,
    TextBlock,
    ToolUseBlock,
    query,
)
from claude_agent_sdk.types import StreamEvent

async def generate_skill(prompt: str, send):
    """One-shot generation using standalone query() function."""
    options = ClaudeAgentOptions(
        model="claude-sonnet-4-6",
        setting_sources=["user", "project", "local"],
        permission_mode="bypassPermissions",
        output_format={
            "type": "json_schema",
            "schema": MY_SCHEMA,
            "strict": True,
        },
        allowed_tools=["Read", "Grep", "Glob", "Skill", "ToolSearch"],
        agents=get_all_agents(),
        disallowed_tools=["Write", "Edit", "Bash"],
        include_partial_messages=True,
        max_turns=50,
    )

    collected_text = []
    cost = None

    # query() is an async generator — no connect/disconnect needed
    async for message in query(prompt=prompt, options=options):
        if isinstance(message, AssistantMessage):
            for block in message.content or []:
                if isinstance(block, TextBlock) and block.text.strip():
                    collected_text.append(block.text.strip())
                    await send({"type": "thought", "text": block.text.strip()})
                elif isinstance(block, ToolUseBlock):
                    await send({"type": "tool_call", "tool": block.name})

        if isinstance(message, StreamEvent):
            event = message.event
            if isinstance(event, dict) and event.get("type") == "content_block_delta":
                delta = event.get("delta", {})
                if delta.get("type") == "text_delta":
                    await send({"type": "stream_text", "text": delta.get("text", "")})

        if isinstance(message, ResultMessage):
            cost = getattr(message, "total_cost_usd", None)
            structured = getattr(message, "structured_output", None)
            # Process structured output...

    return {"text": "\n".join(collected_text), "cost": cost}
```

### When to use query() vs ClaudeSDKClient

| Feature | `query()` | `ClaudeSDKClient` |
|---------|-----------|-------------------|
| Lifecycle management | Automatic | Manual (connect/disconnect) |
| Follow-up queries | No | Yes (call .query() again) |
| Session resume | No | Yes (via session_id) |
| Conversation continuation | No | Yes |
| Best for | Batch jobs, single-shot generation, skill gen | Chat, interactive tools, multi-turn workflows |

## Error Handling

Always wrap SDK operations in try/finally with disconnect:

```python
client = None
try:
    client = ClaudeSDKClient(options=options)
    await client.connect()
    await client.query(prompt)
    async for message in client.receive_response():
        # ... handle messages
        pass
except Exception as e:
    log.exception("SDK error")
    await send({"type": "error", "message": str(e)})
finally:
    if client:
        try:
            await client.disconnect()
        except Exception:
            pass  # Ignore cleanup errors
```
