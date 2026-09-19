# Everything Search Skill for AI Agents

> ⚡ **Ultra-fast, index-powered local file search skill for AI coding agents (Cursor, Codex, PI-Desktop, Claude Desktop, etc.) powered by Voidtools Everything.**

[English](#features) | [中文说明](#特性亮点)

---

## 特性亮点 / Features

- 🚀 **毫秒级极速检索 (Millisecond Latency)**：基于 Voidtools Everything 的 NTFS/USN 实时索引，告别深度递归遍历和卡顿的目录遍历。
- 🎯 **全局或范围限定 (Scoped or Full-Drive)**：支持全盘扫描，也支持使用 `-path` 精确限定在当前代码仓库或特定子目录。
- 🛡️ **智能上下文保护 (Context Safe)**：默认强制返回结果限制（`-n`），避免一次性吐出几十万行路径打爆 Agent 的 Token 上下文。
- 📊 **结构化输出支持 (JSON / CSV)**：附带专用的 PowerShell 与 Python 脚本包装器，可输出结构化 JSON 供脚本和 Agent 精确解析。
- 🧩 **多环境开箱即用 (Universal Support)**：适配 Cursor、Codex、PI-Desktop、Claude 等多种 Agent Skill 规范。

---

## 快速上手 / Quick Start

### 1. 前置要求 (Prerequisites)
- Windows 系统已安装并运行 [Everything](https://www.voidtools.com/)。

### 2. 一键安装 (Installation)

#### 方式 A：通过 PowerShell 一键配置
打开 PowerShell 运行：
```powershell
git clone https://github.com/Mayuqi-crypto/everything-search-skill.git
cd everything-search-skill
.\scripts\install.ps1
```
该脚本会自动：
1. 将 `es.exe` 安装至 `~/.local/bin/` 并写入用户 PATH。
2. 将 Skill 自动同步至 `~/.agents/skills/`、`~/.cursor/skills/` 与 `~/.codex/skills/`。

---

## 常用命令与语法 / Usage Examples

### 1. 基础命令行调用 (Direct CLI)
```powershell
# 限制 20 条结果搜索
es.exe -n 20 "package.json"

# 限定在特定项目目录内搜索
es.exe -path "C:\workspace\my-project" -n 20 "main.py"

# 仅搜文件 (/a-d) 或 仅搜文件夹 (/ad)
es.exe /a-d -n 15 "ext:tsx component"
es.exe /ad -n 10 "node_modules"

# 按最后修改时间倒序排列（找出最近改动的文件）
es.exe -sort-date-modified-descending -n 10 "ext:log"
```

### 2. 高级过滤语法 (Syntax Cheatsheet)
| 语法 | 说明 | 示例 |
|---|---|---|
| `ext:<exts>` | 按文件后缀过滤，分号隔开 | `ext:md;txt;json` |
| `size:<range>` | 按大小过滤（支持 KB/MB/GB） | `size:>100MB` 或 `size:1MB..10MB` |
| `dm:<time>` | 按修改时间过滤 | `dm:today`、`dm:last7days`、`dm:2025` |
| `exact:<name>` | 精确文件名匹配 | `exact:Dockerfile` |
| `!` | 非（排除） | `*.ts !*.test.ts` |
| `|` | 或 | `*.jpg | *.png` |
| `-r` | 正则表达式搜索 | `es.exe -r "src\\components\\.*\.tsx$"` |

### 3. 辅助脚本（结构化 JSON 输出）
```powershell
# 使用 PowerShell 脚本获取 JSON 数据
& "scripts/everything_search.ps1" -Query "ext:png" -Type file -AsJson

# 使用 Python 脚本获取 JSON 数据
python "scripts/everything_search.py" "config.json" -p "C:\my-app" -n 10 --json
```

---

## 仓库结构 / Project Layout

```text
everything-search-skill/
├── SKILL.md                          # Agent Skill 核心规范与使用指示
├── README.md                         # 项目说明文档
├── LICENSE                           # MIT 开源协议
├── bin/
│   └── es.exe                        # Voidtools 官方轻量 CLI 工具
└── scripts/
    ├── install.ps1                   # 一键安装脚本
    ├── everything_search.ps1         # PowerShell 包装脚本
    └── everything_search.py          # Python 包装脚本
```

---

## 许可证 / License

本项目基于 [MIT License](LICENSE) 开源发布。`es.exe` 由 Voidtools 拥有版权。
