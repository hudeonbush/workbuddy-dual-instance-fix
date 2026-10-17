---
name: workbuddy-dual-instance-fix
description: 用户遇到 WorkBuddy（国内版）与 WorkBuddy AI（国际版）无法同时运行、国内版白屏、安装后界面空白、快捷方式指向错误版本等问题时使用。提供环境诊断、获取官方最新安装包、独立目录部署、双开验证的完整修复流程。
---

# WorkBuddy 双持修复 Skill

## 概述

解决腾讯 WorkBuddy 国内版与国际版（WorkBuddy AI）无法同时运行的问题。核心方案：绕过官方安装器的目录合并 bug，通过 `tar` 解包 + `robocopy` 独立部署两个版本，并通过官方更新 API 获取国内版最新安装包解决白屏问题。

## 使用场景

当用户提到以下任一情况时使用本 Skill：

- WorkBuddy 国内版和国际版不能同时打开
- 安装国际版后国内版打不开或变成国际版界面
- 国内版 WorkBuddy 启动后白屏、空白界面
- 两个快捷方式指向同一个程序
- WorkBuddy 安装目录被清空
- 需要同时使用国内版和国际版 WorkBuddy

不适用：WorkBuddy 账号登录问题、网络代理配置、功能使用咨询。

## 核心流程

无论用户具体描述如何，按以下步骤执行：

### 第一步：诊断当前状态

运行 `scripts/diagnose.ps1`，收集：
- 两个版本的进程状态
- 安装目录完整性（文件数、app.asar 是否存在）
- 数据目录隔离情况
- 版本号（从 AppStartup.log 读取）
- 渲染健康度（renderer.log 有无 React error #31）
- 快捷方式目标路径

**判断标准**：
- 国内版安装目录文件数 < 1000 → 安装目录被清空，需要重新部署
- 国内版版本 < 5.8.0 → 版本过旧，会导致白屏
- renderer.log 含 `React error #31` + `$wbEncrypted` → 确认版本-服务端不兼容
- 两个快捷方式指向同一目录 → 安装器合并 bug

### 第二步：获取国内版最新安装包

运行 `scripts/fetch-update.ps1`，调用官方更新 API：

```
GET https://copilot.tencent.com/v2/update?platform=workbuddy-win32-x64-user&version={当前版本}&x-user-id={用户ID}
```

**关键注意**：
- `platform` 必须用 `workbuddy-win32-x64-user`，其他格式（archive/无后缀）均不可用
- 返回的 `sha256hash` 用于下载后校验
- 下载域名：`https://download.codebuddy.cn/workbuddy/saas/win32-x64-user/`

用 `-Download` 参数直接下载到 Downloads 目录，脚本会自动校验 SHA256。

### 第三步：独立部署

运行 `scripts/deploy-from-package.ps1`：

```powershell
.\scripts\deploy-from-package.ps1 -PackagePath "<安装包路径>" -TargetDir "$env:LOCALAPPDATA\Programs\WorkBuddy" -ExpectedSha256 "<API返回的哈希>"
```

**部署原理**：
1. 停止所有 WorkBuddy 进程
2. `tar -xf` 解包 NSIS 安装包（Windows 自带 tar 可直接解压）
3. `robocopy /MIR` 镜像部署到目标目录
4. 验证 app.asar 大小一致

**为什么不用官方安装器**：官方 NSIS 安装器会因旧注册项路径残留把文件装进错误目录，并破坏另一版本的 resources。tar + robocopy 完全可控。

国际版如也被破坏，用同样方法部署到 `Programs\WorkBuddyAI\`。

### 第四步：验证双开

运行 `scripts/verify-dual-run.ps1 -AutoStart`，自动启动两个版本并检查：
- 两个版本进程同时存在（各 3-15 个）
- 版本号正确（国内版 ≥ 5.8.0）
- 无 React 崩溃
- 数据目录各自独立写入

## 根因摘要

| 问题 | 根因 | 证据 |
|------|------|------|
| 双开失败 | 国际版安装器清空国内版目录、收编主程序，两个版本共用 `app.asar` | 国内版目录被清空，`WorkBuddy.exe` 出现在 `WorkBuddyAI` 目录 |
| 国内版白屏 | 旧版（5.3.14）前端无法解码 5.8.x 服务端的加密消息信封 `{$wbEncrypted, envelope}`，React 渲染崩溃 | `Minified React error #31; object with keys {$wbEncrypted, envelope}` |

两个版本在 Windows 层面本应完全独立（不同 AppId、Mutex、UserModelId、数据目录），安装器合并是 bug。

## 关键技术发现

### 版本标识隔离

| 维度 | 国内版 | 国际版 |
|------|--------|--------|
| AppId | `{BFD312E9-1019-4F57-9F44-F86246833B50}` | `{C02C88CB-5DAE-4330-AEC1-572CFD048A59}` |
| Mutex | `workbuddy` | `workbuddy-ai` |
| 数据目录 | `~/.workbuddy/` | `~/.workbuddy-ai/` |
| 安装目录 | `Programs\WorkBuddy\` | `Programs\WorkBuddyAI\` |

### 环境变量

| 变量 | 作用 | 用户可覆盖 |
|------|------|-----------|
| `WORKBUDDY_CONFIG_DIR` | 指定数据目录路径 | ✅ |
| `WORKBUDDY_DATA_FOLDER_NAME` | 内部目录名，启动时被覆写 | ❌ |

## 脚本清单

| 脚本 | 用途 | 风险级别 |
|------|------|---------|
| `scripts/diagnose.ps1` | 环境诊断（只读） | L0 无风险 |
| `scripts/fetch-update.ps1` | 查询/下载官方安装包 | L0 无风险（可选下载） |
| `scripts/deploy-from-package.ps1` | 部署安装包到指定目录 | L2 会停止进程、覆盖安装目录 |
| `scripts/verify-dual-run.ps1` | 验证双开状态 | L0 无风险（可选启动） |

## 注意事项

1. **部署前备份**：建议先备份 `%LOCALAPPDATA%\Programs\WorkBuddy` 和 `WorkBuddyAI` 目录
2. **数据目录不受影响**：部署只替换程序文件，`~/.workbuddy/` 和 `~/.workbuddy-ai/` 不会被修改，登录态保留
3. **PowerShell 执行策略**：如脚本无法运行，先执行 `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`
4. **未来更新风险**：官方自动更新可能再次触发目录合并，建议关注本项目更新
5. **仅支持 Windows**：脚本和路径基于 Windows，macOS 不适用

## 参考文档

- `docs/01-background.md` — 问题背景与现象
- `docs/02-root-cause.md` — 根因深度分析
- `docs/03-fix-guide.md` — 修复步骤详解
- `docs/04-verification.md` — 验证方法与证据
- `docs/05-faq.md` — 常见问题
- `evidence/` — 修复过程中的日志证据
