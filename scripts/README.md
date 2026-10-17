# 脚本说明

## 脚本列表

| 脚本 | 用途 | 风险 |
|------|------|------|
| `diagnose.ps1` | 诊断当前环境状态（只读） | 无 |
| `fetch-update.ps1` | 查询官方更新 API，获取最新安装包 URL 和 SHA256 | 无（可选下载） |
| `deploy-from-package.ps1` | 从安装包部署到指定目录 | 会停止进程、覆盖安装目录 |
| `verify-dual-run.ps1` | 验证双开状态（只读，可选自动启动） | 无（可选启动） |

## 使用顺序

```powershell
# 1. 诊断当前状态
.\diagnose.ps1

# 2. 获取国内版最新安装包信息
.\fetch-update.ps1

# 3. 下载安装包（或用 -Download 参数直接下载）
.\fetch-update.ps1 -Download

# 4. 部署国内版
.\deploy-from-package.ps1 -PackagePath "$env:USERPROFILE\Downloads\WorkBuddy-win32-x64-user-5.8.3.41334564-db0e9b51.exe" -ExpectedSha256 "824de10f3196c501004f540eb84ee881292fef2f5df9fb3fc48af9ea5366c03c"

# 5. 部署国际版（如需要）
.\deploy-from-package.ps1 -PackagePath "<国际版安装包路径>" -TargetDir "$env:LOCALAPPDATA\Programs\WorkBuddyAI"

# 6. 验证双开
.\verify-dual-run.ps1 -AutoStart
```

## 注意事项

1. **PowerShell 执行策略**：如果脚本无法运行，先执行 `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`
2. **部署前备份**：建议先备份 `%LOCALAPPDATA%\Programs\WorkBuddy` 和 `%LOCALAPPDATA%\Programs\WorkBuddyAI`
3. **数据目录不受影响**：部署只替换程序文件，`~/.workbuddy/` 和 `~/.workbuddy-ai/` 数据目录不会被修改
4. **SHA256 校验**：部署时建议提供 `-ExpectedSha256` 参数，确保安装包完整
