# 09 — Permission Handling

## Permission Modes

The SDK supports three permission modes that control how the AI agent accesses tools:

| Mode | Behavior | Use Case |
|------|----------|----------|
| `"bypassPermissions"` | Agent uses any allowed tool automatically | Autonomous bots, batch jobs, background tasks |
| `"acceptEdits"` | Auto-approves reads/edits, prompts for Bash/Write | Semi-autonomous with safety for destructive ops |
| `"default"` | Agent asks permission for every tool via `can_use_tool` | Interactive apps with human oversight |

## Autonomous Mode (Simple)

For apps that run without human intervention:

```python
options = ClaudeAgentOptions(
    permission_mode="bypassPermissions",
    allowed_tools=["Read", "Grep", "Glob", "Skill"],  # Restrict what's available
    ...
)
```

The agent can use any tool in `allowed_tools` without asking. Safety comes from restricting the tool list, not from runtime approval.

## Interactive Mode (Permission Bridge)

For apps where users should approve certain actions (running shell commands, writing files, etc.):

```python
import asyncio
import json
from claude_agent_sdk import ClaudeAgentOptions
from claude_agent_sdk.types import (
    HookMatcher,
    PermissionResultAllow,
    PermissionResultDeny,
    ToolPermissionContext,
)


def build_permission_bridge(send, ws):
    """Create a permission bridge between SDK and WebSocket frontend.

    When the agent wants to use a tool that requires approval, this:
    1. Sends a 'permission_request' to the frontend via WebSocket
    2. Waits for a 'permission_response' from the frontend
    3. Returns Allow or Deny to the SDK

    Args:
        send: Async function to send JSON to frontend.
        ws: WebSocket connection for receiving responses.

    Returns:
        (can_use_tool, ws_listener, message_queue, hooks) tuple.
    """
    pending: dict[str, asyncio.Future] = {}
    message_queue: asyncio.Queue = asyncio.Queue()

    async def can_use_tool(
        tool_name: str,
        input_data: dict,
        context: ToolPermissionContext,
    ) -> PermissionResultAllow | PermissionResultDeny:
        """Called by the SDK when the agent wants to use a tool."""
        request_id = f"perm_{id(input_data)}_{tool_name}"

        # AskUserQuestion: agent is asking the user a question (different UI)
        if tool_name == "AskUserQuestion":
            await send({
                "type": "permission_request",
                "request_id": request_id,
                "tool": tool_name,
                "kind": "question",
                "questions": input_data.get("questions", []),
            })
        else:
            # Standard tool approval request
            description = ""
            if tool_name == "Bash":
                description = input_data.get("command", "")[:200]
            elif tool_name in ("Write", "Edit"):
                description = input_data.get("file_path", "")
            else:
                description = str(input_data)[:200]

            await send({
                "type": "permission_request",
                "request_id": request_id,
                "tool": tool_name,
                "kind": "tool_approval",
                "description": description,
                "input": {k: str(v)[:100] for k, v in (input_data or {}).items()},
            })

        # Wait for user response (5-minute timeout)
        future: asyncio.Future = asyncio.get_event_loop().create_future()
        pending[request_id] = future

        try:
            response = await asyncio.wait_for(future, timeout=300)
        except asyncio.TimeoutError:
            return PermissionResultDeny(message="Permission request timed out (5 minutes)")
        finally:
            pending.pop(request_id, None)

        if response.get("allow"):
            updated = input_data
            # For AskUserQuestion, attach user's answers to the response
            if tool_name == "AskUserQuestion" and response.get("answers"):
                updated = {"questions": input_data.get("questions", []), "answers": response["answers"]}
            return PermissionResultAllow(updated_input=updated)
        else:
            return PermissionResultDeny(
                message=response.get("message", "User denied this action")
            )

    async def ws_listener():
        """Background task: route incoming WS messages to pending Futures."""
        try:
            while True:
                raw = await ws.receive_text()
                msg = json.loads(raw)

                if msg.get("type") == "permission_response":
                    rid = msg.get("request_id")
                    if rid in pending and not pending[rid].done():
                        pending[rid].set_result(msg)
                else:
                    await message_queue.put(msg)
        except Exception:
            for fut in pending.values():
                if not fut.done():
                    fut.set_result({"allow": False})

    # Dummy PreToolUse hook — required to keep the stream open during can_use_tool
    async def _dummy_hook(input_data, tool_use_id, context):
        return {"continue_": True}

    hooks = {"PreToolUse": [HookMatcher(matcher=None, hooks=[_dummy_hook])]}

    return can_use_tool, ws_listener, message_queue, hooks
```

### Using the Permission Bridge

```python
import json

async def handle_interactive_chat(ws):
    await ws.accept()

    async def send(payload):
        await ws.send_text(json.dumps(payload))

    body = json.loads(await ws.receive_text())
    autonomous = body.get("autonomous", True)

    if autonomous:
        perm_mode = "bypassPermissions"
        perm_extras = {}
    else:
        can_use_tool, ws_listener, msg_queue, hooks = build_permission_bridge(send, ws)
        perm_mode = "default"
        perm_extras = {"can_use_tool": can_use_tool, "hooks": hooks}

    options = ClaudeAgentOptions(
        model="claude-sonnet-4-6",
        setting_sources=["user", "project", "local"],
        permission_mode=perm_mode,
        allowed_tools=["Read", "Grep", "Glob", "Bash", "Write", "Edit", "Skill"],
        max_turns=50,
        **perm_extras,
    )

    client = ClaudeSDKClient(options=options)
    await client.connect()

    # Start permission listener (if interactive)
    listener_task = None
    if not autonomous:
        listener_task = asyncio.create_task(ws_listener())

    try:
        await client.query(body.get("message", ""))
        async for message in client.receive_response():
            # ... handle messages
            pass
    finally:
        if listener_task:
            listener_task.cancel()
        await client.disconnect()
```

### Frontend Permission UI (React Example)

```jsx
function PermissionRequest({ request, onRespond }) {
  return (
    <div style={{
      background: '#2d1b69',
      border: '1px solid #7c3aed',
      borderRadius: 8,
      padding: 16,
      margin: '8px 0',
    }}>
      <div style={{ color: '#c4b5fd', fontWeight: 600 }}>
        Permission Required: {request.tool}
      </div>
      <div style={{ color: '#a78bfa', fontSize: 13, margin: '8px 0' }}>
        {request.description}
      </div>
      <div style={{ display: 'flex', gap: 8 }}>
        <button
          onClick={() => onRespond(request.request_id, true)}
          style={{ background: '#22c55e', color: '#fff', padding: '6px 16px', borderRadius: 6 }}
        >
          Allow
        </button>
        <button
          onClick={() => onRespond(request.request_id, false)}
          style={{ background: '#ef4444', color: '#fff', padding: '6px 16px', borderRadius: 6 }}
        >
          Deny
        </button>
      </div>
    </div>
  );
}

// In your WebSocket handler:
ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  if (data.type === 'permission_request') {
    setPermissionRequests(prev => [...prev, data]);
  }
};

function handlePermissionResponse(requestId, allow) {
  ws.send(JSON.stringify({
    type: 'permission_response',
    request_id: requestId,
    allow: allow,
  }));
  setPermissionRequests(prev => prev.filter(r => r.request_id !== requestId));
}
```

## Choosing the Right Mode

| Scenario | Mode | Why |
|----------|------|-----|
| Knowledge base chatbot | `bypassPermissions` + `allowed_tools: [Read, Grep, Glob]` | Read-only, no risk |
| Code generation assistant | `acceptEdits` | Auto-approve reads, prompt for writes |
| DevOps automation | `"default"` + permission bridge | Human approves shell commands |
| Batch processing | `bypassPermissions` | No human in the loop |
| Security scanner | `bypassPermissions` + restricted tools | Automated but tool-restricted |

## Toggling Autonomous Mode Per Session

Let users choose at session start:

```python
# Backend: read autonomous flag from request
autonomous = body.get("autonomous", True)

if autonomous:
    perm_mode = "bypassPermissions"
    perm_extras = {}
else:
    can_use_tool, ws_listener, msg_queue, hooks = build_permission_bridge(send, ws)
    perm_mode = "default"
    perm_extras = {"can_use_tool": can_use_tool, "hooks": hooks}
```

```javascript
// Frontend: send autonomous flag with initial message
ws.send(JSON.stringify({
    message: userMessage,
    autonomous: isAutonomousMode,
}));
```
