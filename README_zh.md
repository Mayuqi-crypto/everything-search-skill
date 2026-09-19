# Everything Search AI 智能体搜索技能 (Skill)

<p align="center">
  <strong>⚡ 基于 Everything 的毫秒级本地文件索引与检索技能，专为 AI 编程智能体设计。</strong><br>
  <span>创新双模架构：HTTP REST API（专治沙箱 / 容器 IPC 隔离）+ CLI Win32 IPC（原生桌面极致直通）。</span>
</p>

<p align="center">
  <a href="README_zh.md">🇨🇳 简体中文</a> |
  <a href="README.md">🇬🇧 English</a> |
  <a href="https://linux.do"><img src="https://img.shields.io/badge/社区-LINUX.DO-orange?style=flat&logo=linux" alt="LINUX DO"></a>
</p>

---

## 💡 核心痛点：为什么沙箱里的 Agent 调用 `es.exe` 会报 IPC 错误？

当 AI 编程智能体运行在 **受限沙箱（Sandbox）**、**Docker 容器**、**WSL2** 或 **Windows 后台服务（Session 0）** 中时，执行 `es.exe` 常常会遇到以下报错：

```text
Error 8: Everything IPC window not found. Please make sure Everything is running.
```

### 原因剖析：
- `es.exe` 依赖 Windows 窗口消息（Win32 `WM_COPYDATA` IPC）与 Everything 宿主桌面的 GUI 窗口通信。
- Windows 系统的 **UIPI 权限隔离（User Interface Privilege Isolation）** 与 **会话隔离（Session Isolation）** 严禁任何来自沙箱、低完整性级别容器或不同桌面会话的进程向宿主发送窗口消息，导致 IPC 通道被系统级阻断。

---

## 🛡️ 解决方案：智能双模降级架构 (Dual-Mode)

针对上述痛点，本技能设计了**网络 HTTP 与本地 CLI 智能双模架构**：

```text
                        ┌───────────────────────────────┐
                        │ AI Agent (Python / PowerShell)│
                        └──────────────┬────────────────┘
                                       │
                    ┌──────────────────┴──────────────────┐
                    ▼                                     ▼
        【模式一：HTTP REST API】                【模式二：Win32 CLI】
     (适用：沙箱、Docker、WSL、远程等)            (适用：Windows 原生桌面会话)
                    │                                     │
           GET http://host:8080/                   es.exe IPC 调用
                    │                                     │
                    └──────────────────┬──────────────────┘
                                       ▼
                         Voidtools Everything 索引内核
                           (毫秒级 <15ms 返回结果)
```

1. **HTTP REST API 模式（沙箱与容器优先）**：
   - Everything 自带轻量、高并发的 HTTP REST 服务。
   - 基于标准 TCP 网络请求，**彻底绕过 Windows Win32 UIPI 与桌面会话隔离限制**。
   - 跨平台兼容：**Linux、macOS、WSL、Docker 容器内部均可直接访问宿主机器上的 Everything 索引**。
   - Python 封装采用**原生纯标准库**编写，零外部第三方包依赖（无需 `requests`）。
2. **CLI IPC 模式（无感自动降级）**：
   - 若宿主机未开启 HTTP 端口，且 Agent 运行在 Windows 本地原生桌面会话，自动无缝回退调用 `es.exe`。

---

## ✨ 特性亮点

- ⚡ **毫秒级极速检索**：全盘（C/D/E等所有磁盘）秒级响应，告别卡顿的递归扫描。
- 🐳 **沙箱与容器即插即用**：完美打通 Docker、WSL2、DevContainer，不再受 IPC 窗口报错困扰。
- 🎯 **全局或范围限定**：支持全盘扫描，也支持通过 `-path` 严格限定在当前工作区内。
- 🛡️ **智能上下文保护**：内置默认数量限制（`-n 20`），彻底防止文件树打爆大模型上下文 Token。
- 📊 **双语言结构化输出**：PowerShell 与 Python 脚本均原生支持 `--json` 输出。
- 🔌 **多平台即插即用**：开箱即用支持 **Cursor**、**Codex**、**PI-Desktop** 及各类自主开发 Agent。

---

## 🚀 快速上手

### 1. 在宿主机开启 Everything HTTP 服务（只需配置一次）
在宿主 Windows 的 Everything 界面中：
1. 打开 Everything -> **工具 (Tools)** -> **选项 (Options)**。
2. 在左侧列表点击 **HTTP 服务器 (HTTP Server)**。
3. 勾选 **启用 HTTP 服务器 (Enable HTTP Server)**，端口填写 `8080`，点击确定。

*或者直接运行自动化配置脚本：*
```powershell
.\scripts\enable_http.ps1 -Port 8080
```

---

### 2. 一键安装技能

克隆仓库并运行一键安装脚本：

```powershell
git clone https://github.com/Mayuqi-crypto/everything-search-skill.git
cd everything-search-skill
.\scripts\install.ps1
```

安装脚本会自动将 `es.exe` 添加至系统 PATH，并将技能部署至 `~/.agents/skills/`、`~/.cursor/skills/` 与 `~/.codex/skills/`。

---

## 🐳 沙箱与容器环境调用指南 (Docker / WSL2)

### 1. Docker 容器中调用
启动容器时挂载宿主机网关并注入环境变量：
```bash
docker run -e EVERYTHING_HTTP_URL=http://host.docker.internal:8080 \
           --add-host host.docker.internal:host-gateway \
           my-agent-image
```

在容器内部即可畅快搜索：
```bash
python scripts/everything_search.py "package.json" -n 10 --json
```

### 2. WSL2 子系统中调用
将 `EVERYTHING_HTTP_URL` 指向宿主机 Windows IP：
```bash
export EVERYTHING_HTTP_URL="http://$(ip route show | awk '/default/ {print $3}'):8080"
python3 scripts/everything_search.py "ext:py model" -n 10
```

---

## 🛠️ 使用方式与命令示例

### 1. 双模 Python 脚本（推荐跨环境使用）

```bash
# 自动模式：自动探测 HTTP 端口，失败自动降级为 CLI
python scripts/everything_search.py "package.json" -n 20

# 获取结构化 JSON 数据
python scripts/everything_search.py "ext:tsx component" -n 10 --json

# 限定在当前项目文件夹内搜索
python scripts/everything_search.py "main.py" -p "C:\Workspace\repo" -n 5

# 强制使用 HTTP REST API 模式
python scripts/everything_search.py "exact:Dockerfile" --mode http
```

### 2. 原生命令行调用 (`es.exe` 本地桌面使用)

```powershell
# 务必带上 -n 限制返回条数！
es.exe -n 20 "package.json"

# 限定在工作区目录内搜索
es.exe -path "C:\my-repo" -n 20 "index.ts"

# 仅搜文件 (/a-d) 或 仅搜文件夹 (/ad)
es.exe /a-d -n 15 "ext:tsx component"
es.exe /ad -n 10 "node_modules"

# 按最后修改时间倒序排列
es.exe -sort-date-modified-descending -n 10 "ext:log dm:today"
```

---

## 🔍 Everything 核心搜索语法速查

| 搜索目标 | 语法示例 | 说明 |
|---|---|---|
| **多扩展名** | `ext:md;txt;json` | 用分号 `;` 分隔后缀 |
| **文件大小范围** | `size:>100MB` 或 `size:1MB..50MB` | 支持 `B`, `KB`, `MB`, `GB` |
| **修改时间** | `dm:today`、`dm:last7days`、`dm:2025` | 相对时间或指定年份 |
| **限定路径** | `path:"C:\Workspace"` | 限定在该目录及子目录下 |
| **精确匹配** | `exact:Dockerfile` | 精确匹配，不使用通配符 |
| **逻辑与 (AND)** | `model user ext:py` | 空格即代表逻辑与 |
| **逻辑或 (OR)** | `*.jpg | *.png` | 竖线左右带空格代表逻辑或 |
| **逻辑非 (NOT)** | `*.ts !*.test.ts` | 叹号 `!` 代表排除 |
| **正则表达式** | `es.exe -r "src\\api\\.*\.go$"` | 正则匹配 |

---

## 📁 目录结构

```text
everything-search-skill/
├── SKILL.md                          # Agent Skill 核心规范定义
├── README.md                         # 英文说明文档
├── README_zh.md                      # 中文说明文档
├── LICENSE                           # MIT 开源协议
├── bin/
│   └── es.exe                        # Voidtools 官方轻量命令行工具
└── scripts/
    ├── install.ps1                   # 一键安装配置脚本
    ├── enable_http.ps1               # 宿主机一键开启 HTTP 服务脚本
    ├── everything_search.ps1         # 支持 HTTP 与 CLI 双模的 PowerShell 包装脚本
    └── everything_search.py          # 零依赖跨平台双模 Python 包装脚本
```

---

## 🌐 社区交流 / Community

本技能首发并分享于 [LINUX DO 社区 (https://linux.do)](https://linux.do) — 欢迎前往社区交流讨论与提出改进建议！

---

## 📄 开源许可证

本项目基于 [MIT License](LICENSE) 协议开源发布。
Voidtools Everything 与 `es.exe` 版权归 Voidtools 官方所有。
