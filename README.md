# WorkBuddy 双持修复指南

> 解决腾讯 WorkBuddy（国内版）与 WorkBuddy AI（国际版）无法同时运行、国内版白屏的问题。

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

## 项目结构

```
workbuddy-dual-instance-fix/
├── README.md                 # 本文件
├── LICENSE                   # MIT 许可证
├── docs/
│   ├── 01-background.md      # 问题背景与现象
│   ├── 02-root-cause.md      # 根因深度分析
│   ├── 03-fix-guide.md       # 修复步骤详解
│   ├── 04-verification.md    # 验证方法与证据
│   └── 05-faq.md             # 常见问题
├── scripts/
│   ├── diagnose.ps1          # 诊断脚本
│   ├── fetch-update.ps1      # 获取官方最新安装包
│   ├── deploy-from-package.ps1  # 从安装包部署
│   ├── verify-dual-run.ps1   # 双开验证
│   └── README.md             # 脚本说明
├── backup/                   # 注册表备份样本（脱敏）
└── evidence/                 # 验证证据（日志片段）
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

## 免责声明

本项目仅用于技术研究与问题修复参考。WorkBuddy 是腾讯公司的产品，本项目不包含任何官方安装包或受版权保护的二进制文件，所有安装包需通过官方渠道获取。
