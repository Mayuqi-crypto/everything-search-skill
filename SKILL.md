---
name: everything-search
description: Search files and folders instantly across Windows drives or within specific project paths using Everything (es.exe). Use whenever the user or task needs to search for files, locate documents/code/assets, find recently modified files, search by extension/size/date, or when standard Glob/Grep searches are slow or unindexed.
---

# Everything Search

Fast, index-powered local file search using Voidtools Everything and its command-line interface (`es.exe`).
Provides millisecond-latency searches across all NTFS drives or restricted to specific directory trees.

## When to Use This Skill

Use this skill whenever you need to:
- Locate files or directories anywhere on local drives or within a project folder
- Find files by name pattern, extension (e.g. `ext:md;json`), size, or modification date
- Quickly locate missing configs, dependencies, project roots, or downloaded files
- Replace slow recursive directory walking or deep file searches with instant index lookups

---

## Quick Start (Direct CLI)

`es.exe` is pre-installed in the user's PATH (`~/.local/bin/es.exe`) and linked to the active Everything service.

```powershell
# Basic search with result count limit (ALWAYS set -n to preserve context tokens)
es.exe -n 20 "filename_or_pattern"

# Search within a specific folder or project
es.exe -path "C:\path\to\project" -n 20 "main.py"

# Files only (/a-d) or Folders only (/ad)
es.exe /a-d -n 15 "ext:tsx component"
es.exe /ad -n 10 "node_modules"

# Sort by date modified (newest first)
es.exe -sort-date-modified-descending -n 10 "ext:log"
```

> **CRITICAL RULE**: Always include `-n <count>` (e.g. `-n 20` or `-n 50`) when running `es.exe`. Unbounded queries like `es.exe *.txt` can dump hundreds of thousands of paths and exhaust context windows.

---

## Helper Scripts (Structured / JSON Output)

The skill includes pre-built helper scripts with automatic binary discovery, path scoping, and JSON formatting:

### PowerShell Helper
```powershell
# Plain text results
& "~/.agents/skills/everything-search/scripts/everything_search.ps1" -Query "package.json" -Limit 10

# Search within folder with date modified desc
& "~/.agents/skills/everything-search/scripts/everything_search.ps1" -Query "*.log" -Path "C:\MyProject" -Sort dm -Limit 5

# JSON output for structured parsing
& "~/.agents/skills/everything-search/scripts/everything_search.ps1" -Query "ext:png" -Type file -AsJson
```

### Python Helper
```powershell
# Text list
python "~/.agents/skills/everything-search/scripts/everything_search.py" "config.json" -n 10

# JSON output
python "~/.agents/skills/everything-search/scripts/everything_search.py" "ext:py model" -p "C:\MyProject" -n 5 --json
```

---

## Everything Search Syntax Cheatsheet

Combine terms with spaces for logical AND.

| Goal | Syntax Example | Notes |
|---|---|---|
| Extension | `ext:md;txt;doc` | Semicolon separates multiple extensions |
| File size | `size:>100MB` or `size:1MB..50MB` | Supports `B`, `KB`, `MB`, `GB` |
| Date modified | `dm:today`, `dm:yesterday`, `dm:last7days` | Or specific year/date: `dm:2025` |
| Exact folder path | `path:"C:\Projects\web"` | Scopes search to paths containing string |
| Exact filename | `exact:Dockerfile` | Exact match without wildcards |
| Wildcards | `*setup*.py` | `*` matches zero or more chars, `?` matches one |
| OR condition | `*.jpg | *.png` | Space pipe space |
| NOT condition | `*.ts !*.test.ts` | Exclude test files |
| Regex search | `es.exe -r "src\\components\\.*\.tsx$"` | Use `-r` flag for regex |
| Case sensitive | `es.exe -i "README.md"` | Match exact casing |

---

## Common Workflows

### 1. Locate a project or config file across drives
```powershell
es.exe -n 10 "exact:settings.json"
```

### 2. Find recently updated log files
```powershell
es.exe -sort-date-modified-descending -n 10 "ext:log dm:today"
```

### 3. Find large files consuming disk space
```powershell
es.exe -sort-size-descending -n 15 "size:>500MB /a-d"
```

### 4. Locate all tests in a project
```powershell
es.exe -path "C:\path\to\repo" -n 30 "*.test.ts;*.spec.ts"
```

---

## Troubleshooting

1. **"Everything.exe is not running"**:
   - Everything requires its lightweight background service/process to maintain its index.
   - Start it via PowerShell: `Start-Process "C:\Program Files\Everything\Everything.exe" -WindowStyle Minimized`
2. **`es.exe` not found**:
   - Ensure `C:\Users\Saber\.local\bin\es.exe` exists or reference the skill's fallback binary `~/.agents/skills/everything-search/bin/es.exe`.
3. **Escaping special characters in PowerShell**:
   - In PowerShell, quote expressions containing `|`, `;`, or `>`:
     `es.exe -n 10 "ext:js;ts" "size:>10MB"`
