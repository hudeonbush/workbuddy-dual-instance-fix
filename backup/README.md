# 注册表备份说明

## 用途

修复前备份 WorkBuddy 和 WorkBuddy AI 的注册表项，用于：
- 修复失败时回滚
- 对比修复前后的注册项变化
- 分析安装器修改了哪些注册表路径

## 备份方法

```powershell
# 备份国内版注册表
reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\{BFD312E9-1019-4F57-9F44-F86246833B50}" "backup\WorkBuddy_CN.reg" /y

# 备份国际版注册表
reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\{C02C88CB-5DAE-4330-AEC1-572CFD048A59}" "backup\WorkBuddy_AI.reg" /y

# 也可以备份整个 WorkBuddy 相关项
reg export "HKCU\Software\WorkBuddy" "backup\WorkBuddy_Software.reg" /y
```

## 关键注册表项

| 版本 | AppId | 注册表路径 |
|------|-------|-----------|
| 国内版 | `{BFD312E9-1019-4F57-9F44-F86246833B50}` | `HKCU\...\Uninstall\{BFD312E9-...}` |
| 国际版 | `{C02C88CB-5DAE-4330-AEC1-572CFD048A59}` | `HKCU\...\Uninstall\{C02C88CB-...}` |

## 注意

- 本目录不包含真实的注册表备份文件（含用户路径等信息）
- 请在自己的系统上执行上述命令生成备份
- 恢复注册表前请确保相关进程已停止
