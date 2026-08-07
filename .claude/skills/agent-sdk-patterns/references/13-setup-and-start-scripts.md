# 13 — Setup & Start Scripts

## Generate These for the User

When helping someone build an LLM app with the Claude Agent SDK, **always generate `setup.sh` and `start.sh`** tailored to their OS and environment. Detect the platform and adapt.

## setup.sh — One-Time Installation

### macOS

```bash
#!/bin/bash
set -e
echo "=== LLM App Setup (macOS) ==="

# 1. Check prerequisites
command -v python3 >/dev/null 2>&1 || { echo "Python 3 required. Install: brew install python3"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "Node.js required. Install: brew install node"; exit 1; }
command -v claude >/dev/null 2>&1 || { echo "Claude Code required. Install: npm install -g @anthropic-ai/claude-code"; exit 1; }

PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "Python: $PYTHON_VERSION"
echo "Node: $(node -v)"

# 2. Create virtual environment
if [ ! -d "backend/venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv backend/venv
fi
source backend/venv/bin/activate

# 3. Install Python dependencies
echo "Installing Python dependencies..."
pip install --upgrade pip
pip install "claude-agent-sdk>=0.1.48" fastapi "uvicorn[standard]" pydantic

# Install optional deps based on what the app needs
if [ -f "backend/requirements.txt" ]; then
    pip install -r backend/requirements.txt
fi

# 4. Install Node dependencies (for MCP servers)
echo "Installing MCP server dependencies..."
npm install -g @anthropic-ai/claude-code 2>/dev/null || true

# Pre-cache common MCP servers (optional, speeds up first run)
npx @playwright/mcp@latest --help >/dev/null 2>&1 || true
npx -y @modelcontextprotocol/server-filesystem --help >/dev/null 2>&1 || true

# 5. Install Playwright browser (if using browser automation)
if pip show playwright >/dev/null 2>&1; then
    echo "Installing Playwright Chromium..."
    playwright install chromium
fi

# 6. Install frontend dependencies (if frontend exists)
if [ -f "frontend/package.json" ]; then
    echo "Installing frontend dependencies..."
    cd frontend && npm install && cd ..
fi

# 7. Create .claude project settings (if not exists)
mkdir -p .claude
if [ ! -f ".claude/settings.json" ]; then
    echo '{}' > .claude/settings.json
    echo "Created .claude/settings.json"
fi

# 8. Create backend .env (if not exists)
if [ ! -f "backend/.env" ]; then
    cat > backend/.env << 'ENVEOF'
# LLM App Configuration
APP_HOST=0.0.0.0
APP_PORT=8000
APP_MODEL=claude-sonnet-4-6
APP_MAX_TURNS=100
APP_MAX_COST_USD=50.0
APP_PERMISSION_MODE=bypassPermissions
LOG_LEVEL=INFO
ENVEOF
    echo "Created backend/.env with defaults"
fi

# 9. Verify Claude Code authentication
echo ""
echo "Verifying Claude Code authentication..."
if [ -f "$HOME/.claude/settings.json" ]; then
    echo "Claude Code settings found at ~/.claude/settings.json"
else
    echo "WARNING: ~/.claude/settings.json not found."
    echo "Run 'claude' in terminal to complete Claude Code setup first."
fi

echo ""
echo "=== Setup Complete ==="
echo "Run ./start.sh to launch the app"
```

### Linux (Ubuntu/Debian/SageMaker)

```bash
#!/bin/bash
set -e
echo "=== LLM App Setup (Linux) ==="

# 1. Check prerequisites
command -v python3 >/dev/null 2>&1 || { echo "Python 3 required. Install: sudo apt install python3 python3-venv python3-pip"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "Node.js required. Install: curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt install -y nodejs"; exit 1; }

# 2. Install system dependencies (if needed)
if command -v apt-get >/dev/null 2>&1; then
    echo "Checking system dependencies..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq python3-venv python3-pip curl 2>/dev/null || true
fi

# 3. Create virtual environment
if [ ! -d "backend/venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv backend/venv
fi
source backend/venv/bin/activate

# 4. Install Python dependencies
echo "Installing Python dependencies..."
pip install --upgrade pip
pip install "claude-agent-sdk>=0.1.48" fastapi "uvicorn[standard]" pydantic

if [ -f "backend/requirements.txt" ]; then
    pip install -r backend/requirements.txt
fi

# 5. Install Playwright browser + system deps (Linux needs extra libs)
if pip show playwright >/dev/null 2>&1; then
    echo "Installing Playwright Chromium with system dependencies..."
    playwright install --with-deps chromium
fi

# 6. Frontend
if [ -f "frontend/package.json" ]; then
    echo "Installing frontend dependencies..."
    cd frontend && npm install && cd ..
fi

# 7. Project settings
mkdir -p .claude
[ ! -f ".claude/settings.json" ] && echo '{}' > .claude/settings.json

# 8. Backend .env
if [ ! -f "backend/.env" ]; then
    cat > backend/.env << 'ENVEOF'
APP_HOST=0.0.0.0
APP_PORT=8000
APP_MODEL=claude-sonnet-4-6
APP_MAX_TURNS=100
APP_MAX_COST_USD=50.0
APP_PERMISSION_MODE=bypassPermissions
LOG_LEVEL=INFO
ENVEOF
fi

echo ""
echo "=== Setup Complete ==="
echo "Run ./start.sh to launch the app"
```

### Windows (PowerShell)

```powershell
# setup.ps1
Write-Host "=== LLM App Setup (Windows) ===" -ForegroundColor Cyan

# Check prerequisites
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "Python 3 required. Install from python.org" -ForegroundColor Red; exit 1
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "Node.js required. Install from nodejs.org" -ForegroundColor Red; exit 1
}

# Create venv
if (-not (Test-Path "backend\venv")) {
    python -m venv backend\venv
}
& backend\venv\Scripts\Activate.ps1

# Install dependencies
pip install --upgrade pip
pip install "claude-agent-sdk>=0.1.48" fastapi "uvicorn[standard]" pydantic

if (Test-Path "backend\requirements.txt") {
    pip install -r backend\requirements.txt
}

# Frontend
if (Test-Path "frontend\package.json") {
    Set-Location frontend; npm install; Set-Location ..
}

# Project settings
New-Item -ItemType Directory -Force -Path .claude | Out-Null
if (-not (Test-Path ".claude\settings.json")) {
    '{}' | Out-File -FilePath ".claude\settings.json" -Encoding utf8
}

Write-Host "`n=== Setup Complete ===" -ForegroundColor Green
Write-Host "Run .\start.ps1 to launch the app"
```

## start.sh — Launch the App

### macOS / Linux

```bash
#!/bin/bash
set -e

# Configuration
BACKEND_PORT=${APP_PORT:-8000}
FRONTEND_PORT=${FRONTEND_PORT:-3000}
BACKEND_DIR="backend"
FRONTEND_DIR="frontend"

echo "=== Starting LLM App ==="

# 1. Kill stale processes on our ports
for port in $BACKEND_PORT $FRONTEND_PORT; do
    pid=$(lsof -ti :$port 2>/dev/null || true)
    if [ -n "$pid" ]; then
        echo "Killing stale process on port $port (PID: $pid)"
        kill -9 $pid 2>/dev/null || true
        sleep 1
    fi
done

# 2. Activate virtual environment
if [ -f "$BACKEND_DIR/venv/bin/activate" ]; then
    source "$BACKEND_DIR/venv/bin/activate"
else
    echo "No venv found. Run ./setup.sh first."
    exit 1
fi

# 3. Verify Claude Code auth
if [ ! -f "$HOME/.claude/settings.json" ]; then
    echo "WARNING: Claude Code not configured. Run 'claude' first."
fi

# 4. Start backend
echo "Starting backend on port $BACKEND_PORT..."
cd "$BACKEND_DIR"
python main.py &
BACKEND_PID=$!
cd ..

# 5. Wait for backend to be ready
echo -n "Waiting for backend"
for i in $(seq 1 30); do
    if (echo > /dev/tcp/localhost/$BACKEND_PORT) 2>/dev/null; then
        echo " ready!"
        break
    fi
    echo -n "."
    sleep 1
done

# 6. Start frontend (if exists)
if [ -f "$FRONTEND_DIR/package.json" ]; then
    echo "Starting frontend on port $FRONTEND_PORT..."
    cd "$FRONTEND_DIR"
    npm run dev &
    FRONTEND_PID=$!
    cd ..
    echo ""
    echo "Frontend: http://localhost:$FRONTEND_PORT"
fi

echo "Backend:  http://localhost:$BACKEND_PORT"
echo "Health:   http://localhost:$BACKEND_PORT/api/health"
echo ""
echo "Press Ctrl+C to stop"

# 7. Cleanup on exit
cleanup() {
    echo ""
    echo "Stopping..."
    [ -n "$BACKEND_PID" ] && kill $BACKEND_PID 2>/dev/null
    [ -n "$FRONTEND_PID" ] && kill $FRONTEND_PID 2>/dev/null
    # Kill any remaining processes on our ports
    for port in $BACKEND_PORT $FRONTEND_PORT; do
        lsof -ti :$port 2>/dev/null | xargs kill -9 2>/dev/null || true
    done
    echo "Stopped."
}
trap cleanup EXIT INT TERM

wait
```

### Windows (PowerShell)

```powershell
# start.ps1
$BackendPort = if ($env:APP_PORT) { $env:APP_PORT } else { "8000" }
$FrontendPort = if ($env:FRONTEND_PORT) { $env:FRONTEND_PORT } else { "3000" }

Write-Host "=== Starting LLM App ===" -ForegroundColor Cyan

# Kill stale processes
foreach ($port in @($BackendPort, $FrontendPort)) {
    $proc = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    if ($proc) {
        Stop-Process -Id $proc.OwningProcess -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }
}

# Activate venv
& backend\venv\Scripts\Activate.ps1

# Start backend
Write-Host "Starting backend on port $BackendPort..."
$backend = Start-Process python -ArgumentList "backend\main.py" -PassThru -NoNewWindow

# Start frontend
if (Test-Path "frontend\package.json") {
    Write-Host "Starting frontend on port $FrontendPort..."
    $frontend = Start-Process npm -ArgumentList "run dev" -WorkingDirectory "frontend" -PassThru -NoNewWindow
}

Write-Host "Backend:  http://localhost:$BackendPort" -ForegroundColor Green
Write-Host "Frontend: http://localhost:$FrontendPort" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop"

# Wait
try { $backend.WaitForExit() } finally {
    $backend.Kill()
    if ($frontend) { $frontend.Kill() }
}
```

## Docker (Universal)

```dockerfile
FROM python:3.11-slim
WORKDIR /app

# System deps for Playwright
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl gnupg && rm -rf /var/lib/apt/lists/*

# Install Node.js (for MCP servers)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs

# Python deps
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install Playwright Chromium only if your app uses Playwright MCP for browser automation:
# RUN playwright install --with-deps chromium

COPY backend/ .

# NOTE: Mount ~/.claude from host for auth, OR set ANTHROPIC_API_KEY
# docker run -v ~/.claude:/root/.claude -p 8000:8000 my-llm-app
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

```yaml
# docker-compose.yml
services:
  backend:
    build: .
    ports:
      - "8000:8000"
    volumes:
      - ~/.claude:/root/.claude:ro  # Mount Claude Code auth (read-only)
    environment:
      - APP_MODEL=claude-sonnet-4-6
      - APP_MAX_TURNS=100
```

## When Generating Scripts for Users

Detect their environment and generate the appropriate version:
- **macOS**: Use `brew`, `lsof`, bash
- **Linux/SageMaker**: Use `apt-get`, `fuser`, bash, handle headless Playwright
- **Windows**: Use PowerShell, `Get-NetTCPConnection`
- **Docker**: Use `docker-compose.yml` with `~/.claude` volume mount

Always include:
1. Prerequisite checks (Python, Node, Claude Code)
2. Virtual environment creation
3. Dependency installation (Python + npm for MCP)
4. `.claude/settings.json` creation
5. Backend `.env` with sensible defaults
6. Port conflict resolution (kill stale processes)
7. Health check wait loop
8. Graceful shutdown via trap/cleanup
