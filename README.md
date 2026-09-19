# Everything Search Skill for AI Agents

<p align="center">
  <strong>⚡ Ultra-fast, index-powered local file search skill for AI coding agents.</strong><br>
  <span>Dual-mode architecture: HTTP REST API (for Sandboxed / Containerized Agents) + CLI Win32 IPC (Native Desktop).</span>
</p>

<p align="center">
  <a href="README_zh.md">🇨🇳 简体中文</a> |
  <a href="README.md">🇬🇧 English</a> |
  <a href="https://linux.do"><img src="https://img.shields.io/badge/Community-LINUX.DO-orange?style=flat&logo=linux" alt="LINUX DO"></a>
</p>

---

## 💡 The Problem: Why Sandboxed Agents Fail with `es.exe`

AI coding agents running in isolated sandboxes, Docker containers, WSL2, or non-interactive background services frequently encounter this error when executing `es.exe`:

```text
Error 8: Everything IPC window not found. Please make sure Everything is running.
```

### Why does this happen?
- `es.exe` relies on Windows Desktop messaging (`WM_COPYDATA` Win32 IPC) to communicate with Everything's GUI window.
- Windows security mechanisms (**User Interface Privilege Isolation / UIPI** and **Session 0 Isolation**) explicitly prohibit processes in sandboxes, containers, or background sessions from sending window messages across desktop session boundaries.

---

## 🛡️ The Solution: Dual-Mode Architecture

This skill implements an **intelligent dual-mode fallback architecture**:

```text
                        ┌───────────────────────────────┐
                        │ AI Agent (Python / PowerShell)│
                        └──────────────┬────────────────┘
                                       │
                    ┌──────────────────┴──────────────────┐
                    ▼                                     ▼
        [Mode 1: HTTP REST API]                 [Mode 2: Win32 CLI]
    (Sandboxes, Docker, WSL, Remote)            (Native User Desktop)
                    │                                     │
           GET http://host:8080/                   es.exe IPC Call
                    │                                     │
                    └──────────────────┬──────────────────┘
                                       ▼
                         Voidtools Everything Engine
                           (Instant <15ms Results)
```

1. **HTTP REST Mode (Primary for Sandboxes & Containers)**:
   - Everything includes a built-in, lightweight HTTP REST API.
   - TCP network requests bypass Win32 UIPI/session isolation completely.
   - Compatible with **Linux, macOS, WSL, Docker containers, and Windows Sandbox**.
   - Implemented using **pure Python standard libraries** (zero third-party dependencies).
2. **CLI IPC Mode (Automatic Fallback)**:
   - If the HTTP port is not exposed and the agent runs in a native Windows desktop session, it automatically falls back to `es.exe`.

---

## ✨ Features

- ⚡ **Sub-15ms Latency**: Query millions of indexed files across all NTFS drives in milliseconds.
- 🐳 **Sandbox & Container Ready**: Works effortlessly inside Docker, WSL2, and isolated agent runners via host HTTP endpoint.
- 🎯 **Scoped or Whole-Disk**: Restrict boundaries to current workspace via `-path` or search all connected drives.
- 🛡️ **Context-Safe Pagination**: Built-in limits (`-n 20`) prevent output dumps from overflowing LLM context tokens.
- 📊 **Structured JSON Output**: Built-in support for `--json` across both Python and PowerShell helpers.
- 🔌 **Universal Agent Support**: Ready for **Cursor**, **Codex**, **PI-Desktop**, and custom agents.

---

## 🚀 Quick Start

### 1. Enable Everything HTTP Server (One-Time Setup on Host)
In Everything on your host Windows machine:
1. Open Everything -> **Tools** (工具) -> **Options** (选项).
2. Select **HTTP Server** (HTTP 服务器) on the left.
3. Check **Enable HTTP Server** (启用 HTTP 服务器), set Port to `8080`, and click OK.

*Alternatively, run the automated setup script:*
```powershell
.\scripts\enable_http.ps1 -Port 8080
```

---

### 2. One-Click Installation

Clone and install into your agent environments:

```powershell
git clone https://github.com/Mayuqi-crypto/everything-search-skill.git
cd everything-search-skill
.\scripts\install.ps1
```

The installer will:
1. Place `es.exe` into `~/.local/bin/` and configure your User `PATH`.
2. Deploy the skill into `~/.agents/skills/`, `~/.cursor/skills/`, and `~/.codex/skills/`.

---

## 🐳 Sandboxed & Container Usage (Docker / WSL2)

### From Docker Container
Pass the host gateway to your container:
```bash
docker run -e EVERYTHING_HTTP_URL=http://host.docker.internal:8080 \
           --add-host host.docker.internal:host-gateway \
           my-agent-image
```

Inside container:
```bash
python scripts/everything_search.py "package.json" -n 10 --json
```

### From WSL2
Point `EVERYTHING_HTTP_URL` to Windows host:
```bash
export EVERYTHING_HTTP_URL="http://$(ip route show | awk '/default/ {print $3}'):8080"
python3 scripts/everything_search.py "ext:py model" -n 10
```

---

## 🛠️ Usage & Examples

### 1. Dual-Mode Python Helper (`scripts/everything_search.py`)

```bash
# Auto mode: Attempts HTTP first; falls back to CLI
python scripts/everything_search.py "package.json" -n 20

# Structured JSON output
python scripts/everything_search.py "ext:tsx component" -n 10 --json

# Restrict search to project folder
python scripts/everything_search.py "main.py" -p "C:\Workspace\repo" -n 5

# Force HTTP REST mode
python scripts/everything_search.py "exact:Dockerfile" --mode http
```

### 2. Direct CLI Usage (`es.exe` in Native Sessions)

```powershell
# Always use -n to limit results!
es.exe -n 20 "package.json"

# Scope search to workspace folder
es.exe -path "C:\my-repo" -n 20 "index.ts"

# Files only (/a-d) or Folders only (/ad)
es.exe /a-d -n 15 "ext:tsx component"
es.exe /ad -n 10 "node_modules"

# Sort by modification date (newest first)
es.exe -sort-date-modified-descending -n 10 "ext:log dm:today"
```

---

## 🔍 Everything Search Syntax Cheatsheet

| Target | Syntax | Description |
|---|---|---|
| Multiple Extensions | `ext:md;txt;json` | Semicolon-delimited file extensions |
| File Size | `size:>100MB` or `size:1MB..50MB` | Supports `B`, `KB`, `MB`, `GB` |
| Date Modified | `dm:today`, `dm:last7days`, `dm:2025` | Relative or exact date filter |
| Path Filter | `path:"C:\Workspace"` | Scope matches to specific parent path |
| Exact Match | `exact:Dockerfile` | Exact match without wildcard expansion |
| Logical AND | `model user ext:py` | Space represents AND |
| Logical OR | `*.jpg | *.png` | Pipe with spaces represents OR |
| Logical NOT | `*.ts !*.test.ts` | Exclude matches with `!` |
| Regex | `es.exe -r "src\\api\\.*\.go$"` | Regular expression matching |

---

## 📁 Repository Layout

```text
everything-search-skill/
├── SKILL.md                          # Standard Agent Skill specification
├── README.md                         # English Documentation
├── README_zh.md                      # Chinese Documentation
├── LICENSE                           # MIT License
├── bin/
│   └── es.exe                        # Voidtools official CLI tool
└── scripts/
    ├── install.ps1                   # One-click installation & PATH setup
    ├── enable_http.ps1               # One-click HTTP Server configuration
    ├── everything_search.ps1         # Dual-mode PowerShell wrapper
    └── everything_search.py          # Dual-mode Python wrapper (Zero-dependency)
```

---

## 🌐 Community & Discussion

Proudly shared and discussed on [LINUX DO (https://linux.do)](https://linux.do) — Welcome to join the discussion and share your feedback!

---

## 📄 License

This repository is licensed under the [MIT License](LICENSE).
Voidtools Everything and `es.exe` are copyright © Voidtools.
