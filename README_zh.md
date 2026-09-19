# Everything Search AI 智能体搜索技能 (Skill)

<p align="center">
  <strong>⚡ 基于 Everything 的毫秒级本地文件索引与检索技能，专为 AI 编程智能体设计。</strong><br>
  <span>全面兼容 Cursor、Codex、PI-Desktop、Claude Desktop 以及自定义 Agent 环境。</span>
</p>

<p align="center">
  <a href="README_zh.md">🇨🇳 简体中文</a> |
  <a href="README.md">🇬🇧 English</a> |
  <a href="https://linux.do"><img src="https://img.shields.io/badge/社区-LINUX.DO-orange?style=flat&logo=linux" alt="LINUX DO"></a>
</p>

---

## 💡 为什么 AI Agent 需要 Everything？

AI 编程助手在 Windows 下常用的传统文件查找手段（如递归扫描 `Get-ChildItem -Recurse`、逐层 `find` 或模糊 Glob 遍历）存在诸多痛点：
- **速度极慢**：遇到包含海量依赖（如 `node_modules`、`.venv`、构建产物等）的项目时，递归遍历动辄几十秒甚至数分钟。
- **资源占用高**：磁盘 I/O 和 CPU 占用瞬间飙升，容易卡顿。
- **Token 爆炸**：由于没有索引过滤，容易一次性返回成千上万条冗余文件路径，不仅耗费巨量 Token，甚至直接挤爆 Agent 的上下文窗口。

**解决方案：**
[Voidtools Everything](https://www.voidtools.com/) 在内存中建立 NTFS USN 实时变动索引。搜索全盘数百万文件通常在 **15 毫秒内** 完成，CPU 与磁盘占用几乎为零。本技能让 AI Agent 能够安全、规范、高效地直接调用 Everything 索引。

---

## ✨ 核心特性

- ⚡ **毫秒级极速检索**：全盘（C/D/E等所有磁盘）秒级响应，无需等待。
- 🎯 **全局或范围限定**：既支持全盘快速查找，也支持通过 `-path` 严格限定在当前工作区或某个项目目录内。
- 🛡️ **智能上下文保护**：内置强制数量限制规则（默认 `-n 20`），彻底避免海量结果冲垮大模型上下文。
- 📊 **双语言脚本封装**：附带 PowerShell (`everything_search.ps1`) 与 Python (`everything_search.py`) 包装脚本，支持一键输出标准 JSON 格式。
- 🔌 **多平台即插即用**：开箱即用支持 **Cursor**、**Codex**、**PI-Desktop** 及任何支持 Agent Skill 的环境。
- 📦 **免配置便携部署**：自带官方 `es.exe` CLI 与一键自动化安装脚本。

---

## 🚀 快速上手

### 前置条件
1. Windows 10/11 系统。
2. 已安装并后台运行 [Voidtools Everything](https://www.voidtools.com/)。

### 一键安装

克隆仓库并运行一键安装脚本：

```powershell
git clone https://github.com/Mayuqi-crypto/everything-search-skill.git
cd everything-search-skill
.\scripts\install.ps1
```

安装脚本将自动完成：
1. 将 `es.exe` 复制到 `~/.local/bin/es.exe` 并确保该路径已添加至当前用户的环境变量 `PATH`。
2. 自动将技能同步并部署到：
   - `~/.agents/skills/everything-search/`（PI-Desktop / 本地 Agent 运行时）
   - `~/.cursor/skills/everything-search/`（Cursor 编辑器）
   - `~/.codex/skills/everything-search/`（Codex）

---

## 🛠️ 使用方式与命令示例

### 1. 直接命令行调用 (`es.exe`)

可在任何 PowerShell 或 CMD 窗口直接调用：

```powershell
# 基础搜索（关键规则：务必带上 -n 限制返回数量）
es.exe -n 20 "package.json"

# 限定在当前工作区或指定项目目录内搜索
es.exe -path "C:\path\to\repo" -n 20 "main.py"

# 仅搜文件 (/a-d) 或 仅搜文件夹 (/ad)
es.exe /a-d -n 15 "ext:tsx component"
es.exe /ad -n 10 "node_modules"

# 按最后修改时间倒序排列（最新修改的文件排在最前）
es.exe -sort-date-modified-descending -n 10 "ext:log"

# 按文件大小倒序排列
es.exe -sort-size-descending -n 10 "size:>100MB"
```

> **注意**：进行搜索时务必加上 `-n <数量>`（如 `-n 20`）。若直接运行无限制查询（例如 `es.exe *.txt`），可能匹配几十万条结果并打满 Agent 上下文。

---

### 2. 辅助脚本（结构化 JSON 输出）

#### PowerShell 脚本 (`scripts/everything_search.ps1`)

```powershell
# 普通纯文本结果
& "scripts/everything_search.ps1" -Query "settings.json" -Limit 10

# 在指定文件夹内搜索并按时间倒序
& "scripts/everything_search.ps1" -Query "*.log" -Path "C:\MyProject" -Sort dm -Limit 5

# 输出 JSON 格式，供 Agent 或代码直接反序列化处理
& "scripts/everything_search.ps1" -Query "ext:png" -Type file -AsJson
```

#### Python 脚本 (`scripts/everything_search.py`)

```powershell
# 纯文本输出
python "scripts/everything_search.py" "config.json" -n 10

# 指定路径并输出 JSON
python "scripts/everything_search.py" "ext:py model" -p "C:\MyProject" -n 5 --json
```

**JSON 输出样例：**
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

## 🔍 Everything 核心搜索语法速查表

| 搜索目标 | Everything 语法 | 语法说明 |
|---|---|---|
| **多扩展名** | `ext:md;txt;json` | 用分号 `;` 分隔多个后缀 |
| **文件大小范围** | `size:>500MB` 或 `size:1MB..50MB` | 支持单位 `B`, `KB`, `MB`, `GB` |
| **修改时间** | `dm:today`、`dm:yesterday`、`dm:last7days` | 支持自然时间或特定年份如 `dm:2025` |
| **限定所在路径** | `path:"C:\Workspace"` | 匹配位于该路径下的文件 |
| **精确文件名** | `exact:Dockerfile` | 精确匹配，不使用通配符 |
| **通配符** | `*service*.ts` | `*` 匹配任意字符，`?` 匹配单个字符 |
| **逻辑 与 (AND)** | `model user ext:py` | 空格即代表逻辑与 |
| **逻辑 或 (OR)** | `*.jpg | *.png` | 竖线左右带空格代表逻辑或 |
| **逻辑 非 (NOT)** | `*.ts !*.test.ts` | 叹号 `!` 代表排除 |
| **正则表达式** | `es.exe -r "src\\api\\.*\.go$"` | 使用 `-r` 参数进行正则匹配 |
| **区分大小写** | `es.exe -i "README.md"` | 精确匹配英文字母大小写 |

---

## 📁 目录结构

```text
everything-search-skill/
├── SKILL.md                          # 遵循标准的 Agent Skill 定义规范
├── README.md                         # 英文说明文档
├── README_zh.md                      # 中文说明文档
├── LICENSE                           # MIT 开源授权协议
├── bin/
│   └── es.exe                        # Voidtools 官方轻量命令行工具
└── scripts/
    ├── install.ps1                   # 一键安装配置脚本
    ├── everything_search.ps1         # PowerShell 包装脚本 (支持 JSON/路径限定)
    └── everything_search.py          # Python 包装脚本 (跨语言/结构化支持)
```

---

## ❓ 常见问题与排查

### 1. 运行 `es.exe` 报错或无返回？
Everything 需要在后台运行一个轻量级的服务/进程以提供实时索引通信。如果未启动，可通过以下命令启动：
```powershell
Start-Process "C:\Program Files\Everything\Everything.exe" -WindowStyle Minimized
```

### 2. 在 PowerShell 中遇到 `|`、`>` 或 `;` 报错？
PowerShell 中字符 `|`（管道符）、`>`（重定向符）和 `;`（语句分隔符）属于特殊保留字符。**在 PowerShell 中传参时请始终加上双引号：**
```powershell
# 正确写法：
es.exe -n 10 "ext:png;jpg" "size:>10MB"

# 错误写法：
es.exe -n 10 ext:png;jpg size:>10MB
```

---

## 🌐 社区交流 / Community

本技能首发并分享于 [LINUX DO 社区 (https://linux.do)](https://linux.do) — 欢迎前往社区交流讨论与提出改进建议！

---

## 📄 开源许可证

本项目基于 [MIT License](LICENSE) 协议发布。
Voidtools Everything 与 `es.exe` 版权归 Voidtools 官方所有。
