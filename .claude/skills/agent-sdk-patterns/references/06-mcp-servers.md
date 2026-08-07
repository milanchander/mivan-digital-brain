# 06 — MCP Server Configuration

## What Are MCP Servers?

MCP (Model Context Protocol) servers give the AI agent access to external tools — filesystems, databases, APIs, browsers, and more. They run as child processes managed by the SDK.

```
Your App
    │
    ▼
Claude Agent SDK
    │
    ├── Filesystem MCP  → Read files from specific directories (knowledge bases, repos)
    ├── Database MCP    → Query PostgreSQL, SQLite, etc.
    ├── GitHub MCP      → Repos, PRs, issues
    ├── Jira MCP        → Fetch issues, search, create tickets
    ├── Playwright MCP  → Browser automation (when you need it)
    └── Custom MCP      → Any MCP-compatible server
```

## MCP Server Types

### stdio (Most Common)

Runs a local process, communicates via stdin/stdout:

```python
mcp_servers = {
    "knowledge": {
        "type": "stdio",
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/docs"],
    },
}
```

### SSE (Server-Sent Events)

Connects to a remote HTTP server:

```python
mcp_servers = {
    "remote-api": {
        "type": "sse",
        "url": "http://localhost:3001/sse",
    },
}
```

## Common MCP Server Configurations

### Playwright (Browser Automation)

```python
def build_playwright_mcp(cdp_endpoint: str = None) -> dict:
    """Build Playwright MCP config.

    Args:
        cdp_endpoint: Optional Chrome DevTools Protocol URL for connecting
                      to an existing browser instance.
    """
    args = ["@playwright/mcp@latest", "--viewport-size", "1920x1080", "--image-responses", "omit"]
    if cdp_endpoint:
        args.extend(["--cdp-endpoint", cdp_endpoint])
    return {
        "type": "stdio",
        "command": "npx",
        "args": args,
    }
```

Playwright MCP provides tools like:
- `mcp__playwright__browser_navigate` — Navigate to URL
- `mcp__playwright__browser_click` — Click elements
- `mcp__playwright__browser_type` — Type text
- `mcp__playwright__browser_snapshot` — Get page accessibility tree
- `mcp__playwright__browser_take_screenshot` — Capture screenshot
- `mcp__playwright__browser_evaluate` — Run JavaScript
- `mcp__playwright__browser_fill_form` — Fill form fields

### Filesystem (Read Files from Specific Directories)

```python
mcp_servers = {
    "knowledge": {
        "type": "stdio",
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/docs"],
    },
}
```

This is useful for the "digital brain" use case — letting the AI read from a curated directory of markdown files, QBR materials, meeting notes, etc.

### PostgreSQL Database

```python
mcp_servers = {
    "database": {
        "type": "stdio",
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-postgres", "postgresql://user:pass@localhost:5432/mydb"],
    },
}
```

### Jira (Atlassian)

```python
mcp_servers = {
    "mcp-atlassian": {
        "type": "stdio",
        "command": "npx",
        "args": ["-y", "mcp-atlassian", "--jira-url", "https://your-org.atlassian.net"],
        "env": {
            "JIRA_API_TOKEN": "your-token",
            "JIRA_USERNAME": "your-email@company.com",
        },
    },
}
```

### GitHub

```python
mcp_servers = {
    "github": {
        "type": "stdio",
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-github"],
        "env": {
            "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_xxx",
        },
    },
}
```

## Building the MCP Server Dict

Production pattern: merge static MCPs with user-configured ones:

```python
import json
from typing import Any


def build_mcp_servers(
    extra_configs: list[dict] | None = None,
) -> dict[str, Any]:
    """Build complete MCP server configuration.

    Args:
        extra_configs: User-configured MCP server configs from DB or config file.

    Returns:
        Dict of server_name -> config for ClaudeAgentOptions.mcp_servers.
    """
    servers: dict[str, Any] = {}

    # Add user-configured MCP servers
    if extra_configs:
        for cfg in extra_configs:
            if not cfg.get("enabled", True):
                continue
            server_config = cfg.get("config", {})
            if isinstance(server_config, str):
                server_config = json.loads(server_config)

            # Unwrap nested config: {"server-name": {command, args}} -> {command, args}
            if "command" not in server_config and "url" not in server_config:
                inner = [v for v in server_config.values() if isinstance(v, dict)]
                if len(inner) == 1 and ("command" in inner[0] or "url" in inner[0]):
                    server_config = inner[0]

            servers[cfg["name"]] = server_config

    return servers
```

## Building the Allowed Tools List

When you add MCP servers, you must also add their tools to `allowed_tools`:

```python
def build_allowed_tools(
    base_tools: list[str] | None = None,
    mcp_servers: dict | None = None,
) -> list[str]:
    """Build allowed tools list with MCP wildcards.

    Args:
        base_tools: Base set of allowed tools.
        mcp_servers: Dict of MCP servers — adds mcp__name__* wildcards.

    Returns:
        List of tool names for ClaudeAgentOptions.allowed_tools.
    """
    tools = list(base_tools or [
        "Read", "Grep", "Glob", "Skill", "Agent", "ToolSearch",
    ])

    if mcp_servers:
        for name in mcp_servers:
            tools.append(f"mcp__{name}__*")  # Wildcard: all tools from this server

    return tools
```

**Usage:**

```python
mcp_servers = build_mcp_servers(user_configs)
allowed_tools = build_allowed_tools(mcp_servers=mcp_servers)

options = ClaudeAgentOptions(
    mcp_servers=mcp_servers,
    allowed_tools=allowed_tools,
    ...
)
```

## MCP Naming Convention

Tools from MCP servers follow the pattern `mcp__<server-name>__<tool-name>`:

```
mcp__playwright__browser_navigate
mcp__playwright__browser_click
mcp__mcp-atlassian__jira_get_issue
mcp__database__execute_sql
mcp__filesystem__read_file
```

Use wildcards in `allowed_tools` to allow all tools from a server:

```python
allowed_tools = [
    "mcp__playwright__*",       # All Playwright tools
    "mcp__mcp-atlassian__*",    # All Jira tools
    "mcp__database__*",         # All database tools
]
```

Or list specific tools for fine-grained control:

```python
allowed_tools = [
    "mcp__playwright__browser_navigate",
    "mcp__playwright__browser_snapshot",
    "mcp__playwright__browser_click",
    # Omit destructive tools like browser_close
]
```

## Environment Variables for MCP Servers

Pass secrets via the `env` field — they're set only for that MCP process:

```python
mcp_servers = {
    "github": {
        "type": "stdio",
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-github"],
        "env": {
            "GITHUB_PERSONAL_ACCESS_TOKEN": os.getenv("GITHUB_TOKEN"),
        },
    },
}
```

This keeps secrets out of your main process environment and scoped only to the MCP server that needs them.

## Custom Use Case: Knowledge Base Chatbot

The filesystem MCP lets an AI agent search and read from a curated directory of documents — perfect for building a "digital brain" chatbot over markdown docs, meeting notes, client materials, technical references:

```python
KNOWLEDGE_DIR = "/path/to/my-digital-brain"

mcp_servers = {
    "knowledge": {
        "type": "stdio",
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-filesystem", KNOWLEDGE_DIR],
    },
}

options = ClaudeAgentOptions(
    model="claude-sonnet-4-6",
    setting_sources=["user", "project", "local"],
    permission_mode="bypassPermissions",
    system_prompt={
        "type": "preset",
        "preset": "claude_code",
        "append": (
            f"You are a knowledge assistant. The user's knowledge base is at '{KNOWLEDGE_DIR}'. "
            "Use the filesystem MCP tools to search and read files. "
            "Always cite which file(s) you found answers in."
        ),
    },
    mcp_servers=mcp_servers,
    allowed_tools=[
        "Read", "Grep", "Glob", "Skill", "ToolSearch",
        "mcp__knowledge__*",  # All filesystem tools for the knowledge directory
    ],
    max_turns=30,
)
```

The AI can then `read_file`, `list_directory`, `search_files` within your knowledge base without needing any custom code.

## Custom Use Case: Database-Aware Data Generation

Connect an AI agent directly to your database for schema-aware operations:

```python
import os

mcp_servers = {
    "database": {
        "type": "stdio",
        "command": "npx",
        "args": [
            "-y",
            "@modelcontextprotocol/server-postgres",
            os.getenv("DATABASE_URL", "postgresql://user:pass@localhost:5432/mydb"),
        ],
    },
}

options = ClaudeAgentOptions(
    ...
    mcp_servers=mcp_servers,
    allowed_tools=["Read", "Grep", "Glob", "mcp__database__*"],
)
```

The agent can query tables, inspect schema, and generate data that matches real column types and constraints.

## Custom Use Case: Security Scanner with Cloned Repo Access

Give a security-scanning agent read access to a cloned repository:

```python
clone_dir = "/tmp/repos/my-project"

mcp_servers = {
    "filesystem": {
        "type": "stdio",
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-filesystem", clone_dir],
    },
}

options = ClaudeAgentOptions(
    ...
    cwd=clone_dir,  # Set working directory to the cloned repo
    mcp_servers=mcp_servers,
    allowed_tools=["Read", "Grep", "Glob", "mcp__filesystem__*"],
)
```

## Custom Use Case: Multi-MCP Orchestration

Combine multiple MCPs for rich AI workflows — e.g., read Jira story, browse the app, query the DB:

```python
mcp_servers = {
    "playwright": {
        "type": "stdio",
        "command": "npx",
        "args": ["@playwright/mcp@latest", "--viewport-size", "1920x1080"],
    },
    "mcp-atlassian": {
        "type": "stdio",
        "command": "npx",
        "args": ["-y", "mcp-atlassian", "--jira-url", "https://myorg.atlassian.net"],
        "env": {
            "JIRA_API_TOKEN": os.getenv("JIRA_TOKEN"),
            "JIRA_USERNAME": os.getenv("JIRA_EMAIL"),
        },
    },
    "database": {
        "type": "stdio",
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-postgres", os.getenv("DATABASE_URL")],
    },
}

allowed_tools = [
    "mcp__playwright__browser_navigate",
    "mcp__playwright__browser_snapshot",
    "mcp__playwright__browser_click",
    "mcp__playwright__browser_take_screenshot",
    "mcp__mcp-atlassian__*",
    "mcp__database__*",
    "Read", "Grep", "Glob", "Skill", "Agent", "ToolSearch",
]
```

## MCP Config Unwrapping Pattern

MCP configs stored in databases often get nested: `{"server-name": {"command": ...}}`. Always unwrap before passing to the SDK:

```python
def unwrap_mcp_config(server_config: dict) -> dict:
    """Unwrap nested MCP config: {"name": {config}} -> {config}"""
    if isinstance(server_config, str):
        server_config = json.loads(server_config)
    if "command" not in server_config and "url" not in server_config:
        inner = [v for v in server_config.values() if isinstance(v, dict)]
        if len(inner) == 1 and ("command" in inner[0] or "url" in inner[0]):
            return inner[0]
    return server_config
```

## Discovering Available MCP Servers

Browse the MCP server registry at:
- Official: `@modelcontextprotocol/server-*` packages on npm
- Community: Search npm for "mcp-server" or check https://github.com/modelcontextprotocol

Common ones:
| Package | Purpose |
|---------|---------|
| `@playwright/mcp` | Browser automation |
| `@modelcontextprotocol/server-filesystem` | File system access (knowledge bases, repos) |
| `@modelcontextprotocol/server-postgres` | PostgreSQL queries |
| `@modelcontextprotocol/server-github` | GitHub API (PRs, issues, repos) |
| `mcp-atlassian` | Jira/Confluence |
| `@modelcontextprotocol/server-memory` | Persistent memory |
| `@modelcontextprotocol/server-sequential-thinking` | Step-by-step reasoning |
| `@modelcontextprotocol/server-sqlite` | SQLite database access |
| `@modelcontextprotocol/server-brave-search` | Web search via Brave |
