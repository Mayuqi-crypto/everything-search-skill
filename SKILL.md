---
name: everything-search
description: Search files and folders instantly across Windows drives or within specific project paths using Everything (HTTP REST API or es.exe CLI). Supports sandboxed agents (Docker, WSL, DevContainers) and native desktop environments with automatic dual-mode fallback.
---

# Everything Search (Dual-Mode: HTTP REST API & CLI)

Ultra-fast, index-powered local file search using Voidtools Everything.
Supports both **HTTP REST API mode** (essential for sandboxed/containerized agents like Docker, WSL, DevContainers) and **native CLI mode** (`es.exe` Win32 IPC) with automatic fallback.

---

## Why Dual-Mode? (Solving Sandboxed Agent IPC Issues)

When an AI agent runs inside a **sandbox**, **Docker container**, **WSL2**, or a **Session 0 background service**, calling `es.exe` directly often fails with:
`Error 8: Everything IPC window not found. Please make sure Everything is running.`

**Root Cause**: Windows enforces User Interface Privilege Isolation (UIPI) and Session Isolation. Sandboxed processes and non-interactive sessions cannot send Win32 `WM_COPYDATA` window messages to the host desktop session.

**The Solution**:
Everything provides a high-performance built-in **HTTP REST API**. Network calls (TCP) bypass Win32 UIPI/session isolation entirely:
- **Sandboxed Agent / Container** ➡️ HTTP Request (`http://host.docker.internal:8080`) ➡️ Host Everything Index (Instant Results!)
- **Native Desktop Session** ➡️ Automatic fallback to `es.exe` CLI if HTTP is disabled.

---

## When to Use This Skill

Use this skill whenever you need to:
- Locate files or directories instantly across local drives or inside a project directory
- Search files in sandboxed environments (Docker, WSL, restricted agents) without IPC errors
- Filter by name pattern, extension (`ext:ts;tsx`), size (`size:>100MB`), or date modified (`dm:today`)
- Output structured JSON for automated pipelines without token-costly directory walks

---

## Quick Start: Python Dual-Mode Helper (Recommended)

The skill includes `scripts/everything_search.py`, which uses **only Python standard libraries** (zero external dependencies like `requests`).

```bash
# Auto mode: Attempts HTTP on port 8080 first; falls back to es.exe CLI automatically
python scripts/everything_search.py "package.json" -n 20

# Structured JSON output
python scripts/everything_search.py "ext:py model" -n 10 --json

# Restrict search to a specific directory
python scripts/everything_search.py "main.go" -p "C:\MyProject" -n 5

# Explicitly force HTTP REST mode
python scripts/everything_search.py "exact:Dockerfile" --mode http

# Specify custom host/port (e.g. from Docker container to host)
python scripts/everything_search.py "*.json" --url "http://host.docker.internal:8080" -n 10
```

---

## Sandboxed & Container Environment Configuration

### 1. Enable HTTP Server on Windows Host (One-time Setup)
In Everything on the host machine:
1. Open Everything -> **Tools** (工具) -> **Options** (选项).
2. Click **HTTP Server** (HTTP 服务器) in the left menu.
3. Check **Enable HTTP Server** (启用 HTTP 服务器), set Port to `8080`, and click OK.
*(Optional: run `scripts/enable_http.ps1` to configure automatically).*

### 2. Connect from Docker Container
Run your Docker container with host access:
```bash
docker run -e EVERYTHING_HTTP_URL=http://host.docker.internal:8080 --add-host host.docker.internal:host-gateway ...
```
Inside the container:
```python
python scripts/everything_search.py "ext:rs" -n 10 --json
```

### 3. Connect from WSL2
Inside WSL, resolve the Windows host IP:
```bash
export EVERYTHING_HTTP_URL="http://$(ip route show | awk '/default/ {print $3}'):8080"
python3 scripts/everything_search.py "ext:md" -n 10
```

---

## Direct CLI Usage (`es.exe` for Native Desktop Sessions)

When running directly in a native Windows user desktop session:

```powershell
# Basic search (ALWAYS specify -n to prevent flooding LLM context)
es.exe -n 20 "settings.json"

# Search inside project folder
es.exe -path "C:\my-repo" -n 20 "index.ts"

# Files only (/a-d) or Folders only (/ad)
es.exe /a-d -n 15 "ext:tsx component"
es.exe /ad -n 10 "node_modules"

# Sort by date modified (newest first)
es.exe -sort-date-modified-descending -n 10 "ext:log dm:today"
```

---

## Everything Search Syntax Cheatsheet

| Filter | Syntax | Example |
|---|---|---|
| Multiple extensions | `ext:<ext1;ext2>` | `ext:md;txt;json` |
| File size | `size:>100MB` or `size:1MB..10MB` | `size:>500MB /a-d` |
| Date modified | `dm:<time>` | `dm:today`, `dm:last7days`, `dm:2025` |
| Exact match | `exact:<name>` | `exact:Dockerfile` |
| Logical AND | `space` | `auth controller ext:go` |
| Logical OR | `|` (with spaces) | `*.jpg | *.png` |
| Logical NOT | `!` | `*.ts !*.test.ts` |
| Regex search | `-r` flag | `es.exe -r "src\\api\\.*\.go$"` |

---

## Environment Variables

| Variable | Default | Purpose |
|---|---|---|
| `EVERYTHING_HTTP_URL` | `http://127.0.0.1:8080` | URL of Everything HTTP service |
| `EVERYTHING_HTTP_USER` | `""` | Optional Basic Auth username |
| `EVERYTHING_HTTP_PASS` | `""` | Optional Basic Auth password |
