# AGENTS.md - WorkBuddy Dual-Instance Fix

> 通用 Agent 技能描述文件，兼容 Claude Code、Cursor、GitHub Copilot、OpenAI Codex、豆包工作等主流 AI Agent。

## 技能名称

WorkBuddy Dual-Instance Fix

## 描述

解决腾讯 WorkBuddy（国内版）与 WorkBuddy AI（国际版）无法同时运行、国内版白屏的问题。提供环境诊断、获取官方最新安装包、独立目录部署、双开验证的完整修复流程。

## 触发条件

当用户提到以下任一情况时，使用本技能：

- WorkBuddy 国内版和国际版不能同时打开
- 安装国际版后国内版打不开或变成国际版界面
- 国内版 WorkBuddy 启动后白屏、空白界面
- 两个快捷方式指向同一个程序
- WorkBuddy 安装目录被清空
- 需要同时使用国内版和国际版 WorkBuddy

## 核心命令

所有脚本位于 `scripts/` 目录，使用 PowerShell 5.1+ 运行。

### 1. 诊断环境

```powershell
.\scripts\diagnose.ps1
```

输出：进程状态、安装目录完整性、版本号、渲染健康度、快捷方式目标。

### 2. 获取官方最新安装包

```powershell
.\scripts\fetch-update.ps1              # 仅查询版本和下载 URL
.\scripts\fetch-update.ps1 -Download    # 查询并下载到 Downloads 目录（自动校验 SHA256）
```

### 3. 部署安装包

```powershell
.\scripts\deploy-from-package.ps1 -PackagePath "<安装包路径>" -TargetDir "$env:LOCALAPPDATA\Programs\WorkBuddy" -ExpectedSha256 "<哈希值>"
```

### 4. 验证双开

```powershell
.\scripts\verify-dual-run.ps1              # 仅验证
.\scripts\verify-dual-run.ps1 -AutoStart   # 自动启动两个版本后验证
```

## 执行流程

1. **诊断**：运行 `diagnose.ps1`，确认问题类型（目录合并 / 版本过旧 / 白屏）
2. **获取安装包**：运行 `fetch-update.ps1 -Download`，获取国内版最新安装包
3. **部署**：运行 `deploy-from-package.ps1`，独立部署到各自目录
4. **验证**：运行 `verify-dual-run.ps1 -AutoStart`，确认双开正常

## 关键技术参数

| 参数 | 值 |
|------|-----|
| 官方更新 API | `https://copilot.tencent.com/v2/update?platform=workbuddy-win32-x64-user&version={ver}&x-user-id={uuid}` |
| 国内版安装目录 | `%LOCALAPPDATA%\Programs\WorkBuddy\` |
| 国际版安装目录 | `%LOCALAPPDATA%\Programs\WorkBuddyAI\` |
| 国内版数据目录 | `~/.workbuddy/` |
| 国际版数据目录 | `~/.workbuddy-ai/` |
| 最低兼容版本 | 国内版 ≥ 5.8.0（低于此版本会白屏） |

## 根因

- **双开失败**：国际版安装器清空国内版目录，两个版本共用 `app.asar`
- **白屏**：旧版前端无法解码 5.8.x 服务端的加密消息信封，React error #31

## 注意事项

- 仅支持 Windows
- 部署会停止 WorkBuddy 进程，但不影响数据目录（登录态保留）
- 首次运行脚本可能需要：`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`
- 详细文档见 `docs/`，证据见 `evidence/`

## 兼容性

| Agent | 接入方式 |
|-------|---------|
| 豆包工作 | 放置于 skill 目录，自动识别 `SKILL.md` |
| Claude Code | 放置于项目目录，读取 `AGENTS.md` |
| Cursor | 放置于项目目录，读取 `AGENTS.md` |
| GitHub Copilot | 读取 `AGENTS.md` |
| OpenAI Codex CLI | 作为自定义工具集，调用 `scripts/*.ps1` |
| 其他 Agent | 读取本文件或 `SKILL.md`，调用脚本 |
