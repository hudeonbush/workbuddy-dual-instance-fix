# WorkBuddy Dual-Instance Fix

> 解决腾讯 WorkBuddy（国内版）与 WorkBuddy AI（国际版）无法同时运行、国内版白屏的问题。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows-blue.svg)](https://www.microsoft.com/windows)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://learn.microsoft.com/powershell/)

---

## 问题现象

1. **双开失败**：安装 WorkBuddy AI（国际版）后，国内版 WorkBuddy 无法独立运行，两个快捷方式指向同一份程序
2. **国内版白屏**：国内版启动后界面空白，主进程正常但渲染进程崩溃

## 根因摘要

| 问题 | 根因 | 证据 |
|------|------|------|
| 双开失败 | 国际版安装器清空国内版目录、收编主程序，导致两个版本共用 `app.asar` | 国内版安装目录被清空，`WorkBuddy.exe` 出现在 `WorkBuddyAI` 目录 |
| 国内版白屏 | 回退到 5.3.14 旧版后，前端无法解码 5.8.x 服务端返回的加密消息信封，React 渲染崩溃 | Crash-Log: `Minified React error #31; object with keys {$wbEncrypted, envelope}` |

## 解决方案

1. **双开修复**：从官方安装包用 `tar` 提取文件，分别部署到独立目录，修复快捷方式
2. **白屏修复**：通过官方更新 API 获取国内版最新安装包（5.8.3），校验 SHA256 后部署

## 快速开始

```powershell
# 1. 诊断当前状态
.\scripts\diagnose.ps1

# 2. 获取国内版最新安装包 URL 和 SHA256
.\scripts\fetch-update.ps1

# 3. 从安装包部署到指定目录
.\scripts\deploy-from-package.ps1 -PackagePath "C:\path\to\WorkBuddy-*.exe" -TargetDir "$env:LOCALAPPDATA\Programs\WorkBuddy"

# 4. 验证双开
.\scripts\verify-dual-run.ps1
```

## 多 Agent 兼容

本项目同时提供多种技能入口格式，可被主流 AI Agent 直接加载使用：

| 入口文件 | 兼容 Agent | 说明 |
|---------|-----------|------|
| `SKILL.md` | 豆包工作 | 豆包工作原生 Skill 格式，含 frontmatter 触发条件 |
| `AGENTS.md` | Claude Code、Cursor、GitHub Copilot、OpenAI Codex | 通用 Agent 技能描述格式 |
| `skill.json` | 任意支持结构化清单的 Agent | 机器可读的技能元数据和脚本清单 |
| `scripts/*.ps1` | 任何能调用 PowerShell 的 Agent/终端 | 4 个可独立运行的自动化脚本 |

### 各 Agent 接入方式

**豆包工作**：将项目目录放入 skill 根目录，系统自动识别 `SKILL.md`。

**Claude Code / Cursor / Copilot**：将项目克隆到任意目录，Agent 会自动读取 `AGENTS.md` 获取技能描述和命令。

**OpenAI Codex CLI / 其他 Agent**：读取 `skill.json` 获取脚本清单，直接调用 `scripts/*.ps1`。

**手动使用**：按下方"快速开始"逐步运行脚本。

## 项目结构

```
workbuddy-dual-instance-fix/
├── SKILL.md                  # 豆包工作 Skill 入口
├── AGENTS.md                 # 通用 Agent 技能描述（Claude/Cursor/Copilot/Codex）
├── skill.json                # 结构化技能元数据（机器可读）
├── README.md                 # 本文件（项目总览）
├── LICENSE                   # MIT 许可证
├── .gitignore
├── assets/
│   └── wechat-qr.png         # 微信二维码
├── docs/
│   ├── 01-background.md      # 问题背景与现象
│   ├── 02-root-cause.md      # 根因深度分析
│   ├── 03-fix-guide.md       # 修复步骤详解
│   ├── 04-verification.md    # 验证方法与证据
│   ├── 05-faq.md             # 常见问题
│   └── 06-git-usage.md       # Git 使用教程
├── scripts/
│   ├── diagnose.ps1              # 环境诊断（进程/目录/注册表/日志）
│   ├── fetch-update.ps1          # 调用官方更新 API 获取安装包
│   ├── deploy-from-package.ps1   # 从安装包部署（tar + robocopy）
│   ├── verify-dual-run.ps1       # 双开验证（自动评分）
│   └── README.md                 # 脚本使用说明
├── backup/
│   └── README.md             # 注册表备份方法
└── evidence/
    ├── README.md
    ├── react-crash-5.3.14.log      # 白屏根因证据（React error #31）
    ├── renderer-healthy-5.8.3.log  # 修复后正常渲染心跳
    ├── update-api-response.json    # 官方更新 API 响应示例
    ├── dual-run-verification.txt   # 双开验证结果
    └── appstartup-5.8.3.log        # 版本确认日志
```

## 关键技术发现

### 官方更新 API

```
GET https://copilot.tencent.com/v2/update?platform=workbuddy-win32-x64-user&version={当前版本}&x-user-id={用户ID}
```

- `platform=workbuddy-win32-x64-user` → 返回可下载的 user 格式包
- `platform=workbuddy-win32-x64-archive` → 返回 URL 但下载 404
- `platform=workbuddy-win32-x64` → 400 错误

返回字段：`version`, `url`, `productVersion`, `sha256hash`, `timestamp`, `supportsFastUpdate`

下载域名：`https://download.codebuddy.cn/workbuddy/saas/win32-x64-user/`

### 环境变量

| 变量 | 作用 | 用户可覆盖 |
|------|------|-----------|
| `WORKBUDDY_CONFIG_DIR` | 数据/配置目录 | ✅ |
| `WORKBUDDY_DATA_FOLDER_NAME` | 内部目录名（启动时被覆写） | ❌ |
| `WORKBUDDY_INSTANCE_NUMBER` | 多实例号，数据目录变 `~/.workbuddy-{N}` | ✅ |

### 版本标识隔离

| 维度 | 国内版 WorkBuddy | 国际版 WorkBuddy AI |
|------|-----------------|-------------------|
| AppId | `{BFD312E9-1019-4F57-9F44-F86246833B50}` | `{C02C88CB-5DAE-4330-AEC1-572CFD048A59}` |
| Mutex | `workbuddy` | `workbuddy-ai` |
| UserModelId | `WorkBuddy.WorkBuddy` | `WorkBuddy.WorkBuddyAI` |
| 数据目录 | `~/.workbuddy/` | `~/.workbuddy-ai/` |
| 安装目录 | `Programs\WorkBuddy\` | `Programs\WorkBuddyAI\` |

## 已验证环境

- Windows 11
- 国内版 WorkBuddy 5.8.3.41334564（build db0e9b51）
- 国际版 WorkBuddy AI 5.8.4.41366630
- 双开同时运行，数据目录隔离

## 反馈与讨论

遇到问题或有新发现？欢迎通过以下渠道反馈：

- **提交 Issue**：[GitHub Issues](https://github.com/hudeonbush/workbuddy-dual-instance-fix/issues) — 报告 bug、请求新功能
- **参与讨论**：[GitHub Discussions](https://github.com/hudeonbush/workbuddy-dual-instance-fix/discussions) — 分享你的修复经验、提问交流
- **查看文档**：[docs/](docs/) — 完整的根因分析和修复步骤
- **微信交流**：扫码添加作者微信，备注「WorkBuddy」

  <img src="assets/wechat-qr.png" width="200" alt="微信二维码">

提交 Issue 时请附上 `scripts\diagnose.ps1` 的输出，方便快速定位问题。

## 相关链接

- [WorkBuddy 官方网站](https://copilot.tencent.com/) — 国内版下载
- [CodeBuddy 官方网站](https://codebuddy.cn/) — 国际版下载
- [Electron 多实例文档](https://www.electronjs.org/docs/latest/api/app#apprequestsingleinstancelock) — Mutex 机制说明

## 许可证

本项目基于 [MIT License](LICENSE) 开源，可自由使用、修改和分发。

## 免责声明

本项目仅用于技术研究与问题修复参考。WorkBuddy 是腾讯公司的产品，本项目不包含任何官方安装包或受版权保护的二进制文件，所有安装包需通过官方渠道获取。
