# Everything Search Skill for AI Agents

<p align="center">
  <strong>⚡ Ultra-fast, index-powered local file search skill for AI coding agents.</strong><br>
  <span>Compatible with Cursor, Codex, PI-Desktop, Claude Desktop, and CLI agent environments.</span>
</p>

<p align="center">
  <a href="README_zh.md">🇨🇳 简体中文</a> |
  <a href="README.md">🇬🇧 English</a>
</p>

---

## 💡 Why Everything for AI Agents?

Traditional file discovery mechanisms used by AI agents (`Get-ChildItem -Recurse`, `find`, or unbounded globbing) suffer from severe limitations on Windows:
- **Painfully Slow**: Recursively walking directories with thousands of dependencies (like `node_modules`, `.venv`, or build artifacts) can take tens of seconds or even minutes.
- **High Resource Usage**: High CPU and disk I/O load while searching.
- **Context Exhaustion**: Unfiltered tools often accidentally return massive file trees, flooding the LLM's context window and wasting thousands of tokens.

**The Solution:**
[Voidtools Everything](https://www.voidtools.com/) indexes NTFS USN Journals in memory. Queries typically execute in **less than 15 milliseconds** with virtually zero CPU footprint. This skill enables agents to leverage this instant index directly and safely.

---

## ✨ Features

- ⚡ **Sub-15ms Latency**: Real-time indexed file retrieval across all local drives (C:, D:, E:, etc.).
- 🎯 **Scoped or Whole-Disk**: Search across entire drives or restrict boundaries to the current project/workspace using `-path`.
- 🛡️ **Context Safe**: Built-in default limit guards (`-n 20`) prevent output dumps from exceeding LLM context windows.
- 📊 **Dual Script Wrappers**: Includes both PowerShell (`everything_search.ps1`) and Python (`everything_search.py`) helpers with structured `--json` output.
- 🔌 **Universal Compatibility**: Works out of the box with **Cursor**, **Codex**, **PI-Desktop**, and any custom agent tooling.
- 📦 **Zero-Config Portable**: Self-contained `es.exe` included with one-click installer.

---

## 🚀 Quick Start

### Prerequisites
1. Windows 10/11
2. [Voidtools Everything](https://www.voidtools.com/) installed and running in the background.

### One-Click Installation

Clone and run the automated installer:

```powershell
git clone https://github.com/Mayuqi-crypto/everything-search-skill.git
cd everything-search-skill
.\scripts\install.ps1
```

The installer will:
1. Copy `es.exe` to `~/.local/bin/es.exe` and add it to your User `PATH`.
2. Automatically deploy the skill into:
   - `~/.agents/skills/everything-search/` (PI-Desktop / Agent environment)
   - `~/.cursor/skills/everything-search/` (Cursor IDE)
   - `~/.codex/skills/everything-search/` (Codex)

---

## 🛠️ Usage & Examples

### 1. Direct CLI Usage (`es.exe`)

`es.exe` runs directly from any PowerShell or CMD prompt:

```powershell
# Basic search with result count limit (CRITICAL: always use -n)
es.exe -n 20 "package.json"

# Search inside a specific project or workspace folder
es.exe -path "C:\path\to\repo" -n 20 "main.py"

# Files only (/a-d) or Folders only (/ad)
es.exe /a-d -n 15 "ext:tsx component"
es.exe /ad -n 10 "node_modules"

# Sort by modification date (newest first)
es.exe -sort-date-modified-descending -n 10 "ext:log"

# Search by file size
es.exe -sort-size-descending -n 10 "size:>100MB"
```

> **Warning**: Always include `-n <count>` (e.g. `-n 20`). Unbounded queries such as `es.exe *.txt` can match hundreds of thousands of files and exhaust the LLM's context.

---

### 2. Helper Scripts (Structured Output)

#### PowerShell Helper (`scripts/everything_search.ps1`)

```powershell
# Plain text search
& "scripts/everything_search.ps1" -Query "settings.json" -Limit 10

# Search inside a specific folder with date sorting
& "scripts/everything_search.ps1" -Query "*.log" -Path "C:\MyProject" -Sort dm -Limit 5

# JSON output for automated agent consumption
& "scripts/everything_search.ps1" -Query "ext:png" -Type file -AsJson
```

#### Python Helper (`scripts/everything_search.py`)

```powershell
# Plain text output
python "scripts/everything_search.py" "config.json" -n 10

# Scoped search with JSON output
python "scripts/everything_search.py" "ext:py model" -p "C:\MyProject" -n 5 --json
```

**Sample JSON Output:**
```json
[
  {
    "filename": "C:\\MyProject\\src\\models\\user_model.py",
    "size": "4096",
    "date_modified": "2026/02/10 14:22"
  }
]
```

---

## 🔍 Search Syntax Cheatsheet

| Target | Everything Syntax | Description |
|---|---|---|
| **Multiple Extensions** | `ext:md;txt;json` | Semicolon-delimited file extensions |
| **Size Filter** | `size:>500MB` or `size:1MB..50MB` | Supports `B`, `KB`, `MB`, `GB` |
| **Date Modified** | `dm:today`, `dm:yesterday`, `dm:last7days` | Supports natural dates or years: `dm:2025` |
| **Path Constraint** | `path:"C:\Workspace"` | Matches files residing inside matching path |
| **Exact Filename** | `exact:Dockerfile` | Exact match without wildcard expansion |
| **Wildcards** | `*service*.ts` | `*` matches 0+ chars, `?` matches 1 char |
| **Logical AND** | `model user ext:py` | Space represents logical AND |
| **Logical OR** | `*.jpg | *.png` | Pipe with spaces represents OR |
| **Logical NOT** | `*.ts !*.test.ts` | Exclude matches with `!` |
| **Regular Expression** | `es.exe -r "src\\api\\.*\.go$"` | Use `-r` flag for regex search |
| **Case Sensitive** | `es.exe -i "README.md"` | Exact casing match |

---

## 📁 Repository Layout

```text
everything-search-skill/
├── SKILL.md                          # Standard Agent Skill specification file
├── README.md                         # English Documentation
├── README_zh.md                      # Chinese Documentation
├── LICENSE                           # MIT License
├── bin/
│   └── es.exe                        # Voidtools official command-line tool
└── scripts/
    ├── install.ps1                   # One-click installation & PATH setup script
    ├── everything_search.ps1         # PowerShell wrapper (CLI & JSON)
    └── everything_search.py          # Python wrapper (CLI & JSON)
```

---

## ❓ FAQ & Troubleshooting

### 1. `es.exe` error or returns nothing?
Ensure the Everything GUI or service is running in the background. If not, start it:
```powershell
Start-Process "C:\Program Files\Everything\Everything.exe" -WindowStyle Minimized
```

### 2. PowerShell parser errors with `|`, `>`, or `;`?
PowerShell reserves characters like `|` (pipeline), `>` (redirection), and `;` (statement separator). **Always quote queries in PowerShell:**
```powershell
# Right:
es.exe -n 10 "ext:png;jpg" "size:>10MB"

# Wrong:
es.exe -n 10 ext:png;jpg size:>10MB
```

---

## 📄 License

This repository is licensed under the [MIT License](LICENSE).
Voidtools Everything and `es.exe` are copyright © Voidtools.
