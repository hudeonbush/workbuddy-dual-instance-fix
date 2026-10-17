# 04 - 验证方法与证据

## 4.1 验证清单

| 检查项 | 方法 | 预期结果 |
|--------|------|---------|
| 国内版进程 | `Get-Process WorkBuddy` | 5-9 个进程 |
| 国际版进程 | `Get-Process WorkBuddyAI` | 5-9 个进程 |
| 国内版版本 | 查看 `AppStartup.log` | `appVersion=5.8.3` |
| 国际版版本 | 查看 `AppStartup.log` | `appVersion=5.8.4` |
| 渲染正常 | 查看 `renderer.log` | 有 heartbeat 日志，无 React error |
| 数据隔离 | 检查两个数据目录 | `.workbuddy/` 和 `.workbuddy-ai/` 各自独立写入 |
| 界面显示 | 目视检查 | 两个窗口均正常显示内容 |

## 4.2 版本验证

### 国内版 5.8.3

```
# ~/.workbuddy/logs/AppStartup.log
2026-10-17T16:26:43.344+08:00 [DocumentSelectionHook] appName=WorkBuddy appVersion=5.8.3 build=db0e9b51b7fa0b383f41f5b0b83dd442c8557918 platform=win32 arch=x64 electron=37.10.3 node=22.21.1
```

### 国际版 5.8.4

```
# ~/.workbuddy-ai/logs/AppStartup.log
appName=WorkBuddyAI appVersion=5.8.4 build=73952edb...
```

## 4.3 渲染正常验证

### 正常 renderer.log（5.8.3）

```json
{"timestamp":"2026-10-17T08:28:20.234Z","level":"info","scope":"renderer","message":["[perf] [heartbeat] appState {\"conversationsLength\":0,...}"]}
{"timestamp":"2026-10-17T08:28:31.339Z","level":"info","scope":"renderer","message":["[render-diag] idle: InputContainer(11532ms) StatusChips(11532ms) ..."]}
```

特征：持续的 `[perf] [heartbeat]` 和 `[render-diag]` 日志，说明渲染循环正常运行。

### 异常 renderer.log（5.3.14 白屏）

```
Error: Minified React error #31; visit https://reactjs.org/docs/error-decoder.html?invariant=31
  &args[]=object%20with%20keys%20%7B%24wbEncrypted%2C%20envelope%7D
    at Mg (react-dom-*.js:2665:9)
```

特征：React error #31，提到 `{$wbEncrypted, envelope}` 对象。

## 4.4 进程验证

```powershell
# 预期输出示例
Get-Process -Name "WorkBuddy","WorkBuddyAI" | Group-Object Name | Select-Object Name, Count

# Name        Count
# ----        -----
# WorkBuddy       6
# WorkBuddyAI     9
```

两个进程组同时存在 = 双开成功。

## 4.5 数据隔离验证

```powershell
# 两个数据目录应各自有最新写入的日志
Get-ChildItem "$env:USERPROFILE\.workbuddy\logs" | Sort-Object LastWriteTime -Descending | Select-Object -First 3
Get-ChildItem "$env:USERPROFILE\.workbuddy-ai\logs" | Sort-Object LastWriteTime -Descending | Select-Object -First 3
```

两个目录的日志时间戳都应接近当前时间，说明各自独立运行和写入。

## 4.6 安装包校验

```powershell
# SHA256 应与 API 返回一致
Get-FileHash "WorkBuddy-win32-x64-user-5.8.3.41334564-db0e9b51.exe" -Algorithm SHA256

# 预期：824de10f3196c501004f540eb84ee881292fef2f5df9fb3fc48af9ea5366c03c
# 文件大小：441,094,104 字节
```

## 4.7 最终验证结果

| 项目 | 结果 |
|------|------|
| 国内版 5.8.3 部署 | ✅ 7258 个文件，SHA256 校验通过 |
| 国内版启动 | ✅ 6 个进程，appVersion=5.8.3 |
| 国内版渲染 | ✅ renderer 正常心跳，无 React 崩溃 |
| 国际版 5.8.4 运行 | ✅ 9 个进程 |
| 双开同时运行 | ✅ 两个版本进程共存 |
| 数据目录隔离 | ✅ `.workbuddy/` 和 `.workbuddy-ai/` 各自写入 |
| 界面显示 | ✅ 用户确认正常使用 |
