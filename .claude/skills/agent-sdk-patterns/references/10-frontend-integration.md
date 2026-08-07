# 10 — Frontend Integration

## WebSocket Client (Vanilla JavaScript)

```javascript
class LLMClient {
    constructor(wsUrl) {
        this.wsUrl = wsUrl;
        this.ws = null;
        this.onText = null;       // (text: string) => void
        this.onToolCall = null;   // (tool: string, detail: string) => void
        this.onStatus = null;     // (message: string) => void
        this.onComplete = null;   // (data: object) => void
        this.onError = null;      // (message: string) => void
        this.onPermission = null; // (request: object) => void
    }

    connect() {
        return new Promise((resolve, reject) => {
            this.ws = new WebSocket(this.wsUrl);
            this.ws.onopen = () => resolve();
            this.ws.onerror = (e) => reject(e);
            this.ws.onmessage = (event) => this._handleMessage(JSON.parse(event.data));
            this.ws.onclose = () => {};
        });
    }

    send(message, options = {}) {
        this.ws.send(JSON.stringify({ message, ...options }));
    }

    followUp(message) {
        this.ws.send(JSON.stringify({ type: 'follow_up', message }));
    }

    respondToPermission(requestId, allow) {
        this.ws.send(JSON.stringify({
            type: 'permission_response',
            request_id: requestId,
            allow,
        }));
    }

    close() {
        if (this.ws) {
            this.ws.send(JSON.stringify({ type: 'close' }));
            this.ws.close();
        }
    }

    _handleMessage(data) {
        switch (data.type) {
            case 'thought':
            case 'stream_text':
                this.onText?.(data.text || data.content);
                break;
            case 'tool_call':
                this.onToolCall?.(data.tool, data.detail || '');
                break;
            case 'status':
                this.onStatus?.(data.message);
                break;
            case 'complete':
            case 'follow_up_complete':
                this.onComplete?.(data);
                break;
            case 'error':
                this.onError?.(data.message);
                break;
            case 'permission_request':
                this.onPermission?.(data);
                break;
            case 'todo_update':
                this.onTodo?.(data.todos);
                break;
            case 'subagent_start':
                this.onSubagent?.(data.agent, data.task);
                break;
            case 'screenshot':
                this.onScreenshot?.(data);
                break;
            case 'url_change':
                this.onUrlChange?.(data.url);
                break;
            case 'workflow_event':
                this.onWorkflow?.(data);
                break;
        }
    }
}
```

### Complete Message Type Reference

All possible message types from the backend:

| Type | Fields | Purpose |
|------|--------|---------|
| `status` | `message` | Progress update (e.g., "Starting...", "Connected to AI...") |
| `thought` | `text` | AI thinking/reasoning text (chunked by paragraph) |
| `stream_text` | `text` | Character-by-character token streaming |
| `tool_call` | `tool`, `detail?` | AI is using a tool (e.g., "Read: /path/to/file") |
| `complete` | `cost_usd?`, `num_turns?`, `duration_ms?`, `session_id?`, `conversation_active` | Session complete with metadata |
| `follow_up_complete` | `cost_usd?`, `conversation_active` | Follow-up response complete |
| `error` | `message` | Error occurred |
| `permission_request` | `request_id`, `tool`, `kind`, `description?`, `questions?` | Agent needs user approval or answer |
| `todo_update` | `todos` (array of {content, status}) | Progress checklist from TodoWrite |
| `subagent_start` | `agent`, `task` | Subagent delegation began |
| `screenshot` | `data` (base64), `timestamp?` | Browser screenshot captured |
| `url_change` | `url` | Browser navigated to new URL |
| `workflow_event` | `kind`, `data` | Workflow phase transitions (plan/execute/validate/report) |

### Usage

```javascript
const client = new LLMClient('ws://localhost:8000/ws/chat');

client.onText = (text) => appendToChat(text);
client.onToolCall = (tool, detail) => showToolIndicator(tool, detail);
client.onStatus = (msg) => showStatus(msg);
client.onComplete = (data) => {
    showStatus(`Done. Cost: $${data.cost_usd?.toFixed(4) || '?'}`);
    sessionId = data.session_id;  // Save for resume
};
client.onError = (msg) => showError(msg);

await client.connect();
client.send('Summarize the key themes from our QBR documents', {
    model: 'claude-sonnet-4-6',
});

// Later — follow up in same conversation:
client.followUp('Which QBR had the most action items?');
```

## React Integration

### Custom Hook: useChat

```jsx
import { useCallback, useRef, useState } from 'react';

export function useChat(wsUrl) {
    const [messages, setMessages] = useState([]);
    const [isLoading, setIsLoading] = useState(false);
    const [sessionId, setSessionId] = useState(null);
    const [cost, setCost] = useState(null);
    const wsRef = useRef(null);

    const addMessage = useCallback((role, content, meta = {}) => {
        setMessages(prev => [...prev, { role, content, ...meta, id: Date.now() }]);
    }, []);

    const sendMessage = useCallback((message, options = {}) => {
        setIsLoading(true);
        addMessage('user', message);

        const ws = new WebSocket(wsUrl);
        wsRef.current = ws;

        let aiText = '';

        ws.onopen = () => {
            if (options.resume && sessionId) {
                ws.send(JSON.stringify({
                    type: 'resume',
                    session_id: sessionId,
                    message,
                    model: options.model || 'claude-sonnet-4-6',
                }));
            } else if (options.followUp) {
                ws.send(JSON.stringify({ type: 'follow_up', message }));
            } else {
                ws.send(JSON.stringify({
                    message,
                    model: options.model || 'claude-sonnet-4-6',
                    system_prompt: options.systemPrompt || '',
                    autonomous: options.autonomous !== false,
                }));
            }
        };

        ws.onmessage = (event) => {
            const data = JSON.parse(event.data);

            switch (data.type) {
                case 'thought':
                    aiText += data.text + '\n';
                    // Update last AI message in-place for streaming effect
                    setMessages(prev => {
                        const last = prev[prev.length - 1];
                        if (last?.role === 'assistant') {
                            return [...prev.slice(0, -1), { ...last, content: aiText }];
                        }
                        return [...prev, { role: 'assistant', content: aiText, id: Date.now() }];
                    });
                    break;

                case 'tool_call':
                    setMessages(prev => [...prev, {
                        role: 'tool',
                        content: `Using: ${data.tool}${data.detail ? ` — ${data.detail}` : ''}`,
                        id: Date.now(),
                    }]);
                    break;

                case 'complete':
                case 'follow_up_complete':
                    setIsLoading(false);
                    setSessionId(data.session_id || sessionId);
                    setCost(data.cost_usd);
                    break;

                case 'error':
                    setIsLoading(false);
                    addMessage('error', data.message);
                    break;
            }
        };

        ws.onclose = () => setIsLoading(false);
        ws.onerror = () => setIsLoading(false);
    }, [wsUrl, sessionId, addMessage]);

    const followUp = useCallback((message) => {
        if (wsRef.current?.readyState === WebSocket.OPEN) {
            addMessage('user', message);
            wsRef.current.send(JSON.stringify({ type: 'follow_up', message }));
            setIsLoading(true);
        } else {
            sendMessage(message, { resume: true });
        }
    }, [sendMessage, addMessage]);

    return { messages, isLoading, sessionId, cost, sendMessage, followUp };
}
```

### Chat Component (with Markdown Rendering)

```jsx
import { useChat } from './hooks/useChat';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import rehypeHighlight from 'rehype-highlight';
import 'highlight.js/styles/github-dark.css';

function ChatPage() {
    const { messages, isLoading, cost, sendMessage, followUp } = useChat('ws://localhost:8000/ws/chat');
    const [input, setInput] = useState('');

    const handleSend = () => {
        if (!input.trim()) return;
        if (messages.length > 0) {
            followUp(input);
        } else {
            sendMessage(input);
        }
        setInput('');
    };

    return (
        <div style={{ maxWidth: 800, margin: '0 auto', padding: 24 }}>
            <h1>Knowledge Base Chat</h1>

            <div style={{ minHeight: 400, border: '1px solid #333', borderRadius: 8, padding: 16, marginBottom: 16 }}>
                {messages.map(msg => (
                    <div key={msg.id} style={{
                        padding: 8,
                        margin: '4px 0',
                        borderRadius: 6,
                        background: msg.role === 'user' ? '#1e3a5f' : msg.role === 'tool' ? '#2d1b69' : '#1a1a2e',
                        color: msg.role === 'error' ? '#ef4444' : '#e2e8f0',
                    }}>
                        <strong>{msg.role === 'user' ? 'You' : msg.role === 'tool' ? 'Tool' : 'AI'}:</strong>{' '}
                        {msg.role === 'assistant' ? (
                            <ReactMarkdown
                                remarkPlugins={[remarkGfm]}
                                rehypePlugins={[rehypeHighlight]}
                            >
                                {msg.content}
                            </ReactMarkdown>
                        ) : (
                            msg.content
                        )}
                    </div>
                ))}
                {isLoading && <div style={{ color: '#7c3aed' }}>Thinking...</div>}
            </div>

            <div style={{ display: 'flex', gap: 8 }}>
                <input
                    value={input}
                    onChange={e => setInput(e.target.value)}
                    onKeyDown={e => e.key === 'Enter' && handleSend()}
                    placeholder="Ask about your knowledge base..."
                    style={{ flex: 1, padding: 12, borderRadius: 6, background: '#1a1a2e', color: '#e2e8f0', border: '1px solid #333' }}
                />
                <button
                    onClick={handleSend}
                    disabled={isLoading}
                    style={{ padding: '12px 24px', borderRadius: 6, background: '#7c3aed', color: '#fff' }}
                >
                    Send
                </button>
            </div>

            {cost && <div style={{ color: '#666', fontSize: 12, marginTop: 8 }}>Session cost: ${cost.toFixed(4)}</div>}
        </div>
    );
}
```

## Resume After Page Reload

If the user refreshes or navigates away, resume using the saved `session_id`:

```javascript
// Save session_id to localStorage on complete
ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    if (data.type === 'complete' && data.session_id) {
        localStorage.setItem('chatSessionId', data.session_id);
    }
};

// On page load, check for existing session
const savedSessionId = localStorage.getItem('chatSessionId');
if (savedSessionId) {
    // Show "Continue conversation?" button
    // On click: send resume message
    ws.send(JSON.stringify({
        type: 'resume',
        session_id: savedSessionId,
        message: 'Continue from where we left off.',
        model: 'claude-sonnet-4-6',
    }));
}
```

## CORS Configuration

The backend must allow WebSocket connections from your frontend:

```python
# backend/main.py
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

## Production Patterns from Real Usage

### TodoWrite State Replacement (NOT Append)

`todo_update` always carries the FULL todo list. Replace state wholesale — never append:

```jsx
const [todos, setTodos] = useState([]);

case 'todo_update':
    setTodos(msg.todos || []);  // Replace, don't append
    // If you also keep a separate log/timeline, replace the prior todo entry:
    setLogs(prev => {
        const filtered = prev.filter(e => e.kind !== 'todo_update');
        return [...filtered, { id: 'todo-progress', kind: 'todo_update', todos: msg.todos, ts: Date.now() }];
    });
    break;
```

### TodoProgress UI Component

```jsx
function TodoProgress({ todos }) {
    const done = todos.filter(t => t.status === 'completed').length;
    const total = todos.length;
    const pct = total ? Math.round((done / total) * 100) : 0;

    return (
        <div style={{ background: '#1a1a2e', padding: 16, borderRadius: 8, border: '1px solid #333' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
                <strong style={{ color: '#e2e8f0' }}>Progress</strong>
                <span style={{ color: '#7c3aed' }}>{done}/{total} ({pct}%)</span>
            </div>
            <div style={{ height: 6, background: '#0f0f1e', borderRadius: 3, overflow: 'hidden' }}>
                <div style={{
                    width: `${pct}%`,
                    height: '100%',
                    background: 'linear-gradient(90deg, #7c3aed, #22c55e)',
                    transition: 'width 0.3s',
                }} />
            </div>
            <ul style={{ listStyle: 'none', padding: 0, margin: '12px 0 0' }}>
                {todos.map((t, i) => (
                    <li key={i} style={{
                        padding: '4px 0',
                        color: t.status === 'completed' ? '#22c55e' : t.status === 'in_progress' ? '#7c3aed' : '#666',
                    }}>
                        {t.status === 'completed' ? '✓ ' : t.status === 'in_progress' ? '⏵ ' : '○ '}
                        {t.status === 'in_progress' && t.activeForm ? t.activeForm : t.content}
                    </li>
                ))}
            </ul>
        </div>
    );
}
```

### Streaming Text Accumulation

`stream_text` arrives token-by-token. Accumulate in state:

```jsx
const [streamText, setStreamText] = useState('');

case 'stream_text':
    setStreamText(prev => prev + (msg.text || ''));
    break;

// On 'complete', commit streamText into the message log and clear it:
case 'complete':
    if (streamText) {
        addMessage('assistant', streamText);
        setStreamText('');
    }
    setIsLoading(false);
    setSessionId(msg.session_id);
    break;
```

### Permission UI with AskUserQuestion

The agent can either request tool approval OR ask a question. Handle both:

```jsx
function PermissionPrompt({ request, onRespond }) {
    if (request.kind === 'question') {
        // AskUserQuestion: agent asks the user, expects answers
        const [answers, setAnswers] = useState({});
        return (
            <div style={{ padding: 16, background: '#2d1b69', borderRadius: 8 }}>
                <strong style={{ color: '#c4b5fd' }}>Agent has questions:</strong>
                {(request.questions || []).map((q, i) => (
                    <div key={i} style={{ marginTop: 12 }}>
                        <div style={{ color: '#a78bfa', marginBottom: 4 }}>{q.question || q}</div>
                        <input
                            value={answers[i] || ''}
                            onChange={e => setAnswers({ ...answers, [i]: e.target.value })}
                            style={{ width: '100%', padding: 8, background: '#1a1a2e', color: '#fff' }}
                        />
                    </div>
                ))}
                <button onClick={() => onRespond(request.request_id, true, { answers })} style={{ marginTop: 12 }}>
                    Submit
                </button>
            </div>
        );
    }
    // Standard tool approval
    return (
        <div style={{ padding: 16, background: '#2d1b69', borderRadius: 8 }}>
            <div style={{ color: '#c4b5fd' }}>Permission: <strong>{request.tool}</strong></div>
            <div style={{ color: '#a78bfa', fontSize: 13, margin: '8px 0' }}>{request.description}</div>
            <button onClick={() => onRespond(request.request_id, true)}>Allow</button>
            <button onClick={() => onRespond(request.request_id, false)}>Deny</button>
        </div>
    );
}

// Permission response can include optional answers/message:
function respondToPermission(requestId, allow, { message, answers } = {}) {
    ws.send(JSON.stringify({
        type: 'permission_response',
        request_id: requestId,
        allow: !!allow,
        ...(message ? { message } : {}),
        ...(answers ? { answers } : {}),
    }));
}
```

### Resume on WebSocket Close (Auto-Reconnect)

If the WS is closed (page reload, network blip), reconnect with `type: "resume"`:

```jsx
function sendFollowUp(message) {
    const ws = wsRef.current;

    if (ws && ws.readyState === WebSocket.OPEN) {
        // Same WS still alive — use follow_up
        ws.send(JSON.stringify({ type: 'follow_up', message }));
        return;
    }

    // WS closed — open new one and resume
    const newWs = new WebSocket(wsUrl);
    newWs.onopen = () => {
        newWs.send(JSON.stringify({
            type: 'resume',
            session_id: sessionId,
            message,
            model: model,
            autonomous: autonomous,  // Preserve autonomous mode across resume
        }));
    };
    newWs.onmessage = handleMessage;  // SAME handler as initial connect
    wsRef.current = newWs;
}
```

**Critical**: The resume `onmessage` handler MUST handle ALL message types — same as initial connect. Don't strip it down.

### Markdown Rendering (REQUIRED for Chat UIs)

Claude responses are markdown by default — code blocks, lists, headings, tables. Always render with a markdown library, never as plain text.

**React:**

```bash
npm install react-markdown remark-gfm rehype-highlight highlight.js
```

```jsx
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import rehypeHighlight from 'rehype-highlight';
import 'highlight.js/styles/github-dark.css';

function AssistantMessage({ content }) {
    return (
        <div className="markdown-body">
            <ReactMarkdown
                remarkPlugins={[remarkGfm]}          // GFM: tables, strikethrough, task lists
                rehypePlugins={[rehypeHighlight]}    // Syntax highlighting for code blocks
            >
                {content}
            </ReactMarkdown>
        </div>
    );
}
```

**Vanilla JS:**

```html
<script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/dompurify/dist/purify.min.js"></script>
<script>
function renderMarkdown(text) {
    return DOMPurify.sanitize(marked.parse(text));  // ALWAYS sanitize
}

// Usage:
messageEl.innerHTML = renderMarkdown(aiText);
</script>
```

**CRITICAL**: Always sanitize markdown output with DOMPurify (vanilla) or `rehype-sanitize` (React). Without it, malicious or hallucinated `<script>` tags in AI output become XSS vulnerabilities.

### Streaming Markdown

When using `stream_text` for token-by-token streaming, re-render markdown on each chunk. Most markdown libraries handle partial input gracefully — they'll render incomplete code blocks as plain text until the closing fence arrives:

```jsx
const [streamText, setStreamText] = useState('');

case 'stream_text':
    setStreamText(prev => prev + (msg.text || ''));
    break;

// In render — passes partial markdown to ReactMarkdown on every state update:
{streamText && <ReactMarkdown remarkPlugins={[remarkGfm]}>{streamText}</ReactMarkdown>}
```

## Frontend Frameworks

This pattern works with any frontend:
- **React** (Vite or CRA): Use the `useChat` hook above
- **Vue**: Same WebSocket logic in a composable (`useChat.ts`)
- **Svelte**: Same logic in a store
- **Vanilla HTML**: Use the `LLMClient` class above
- **Next.js**: Use client components with the `useChat` hook

The backend is framework-agnostic — it's just a WebSocket endpoint.
