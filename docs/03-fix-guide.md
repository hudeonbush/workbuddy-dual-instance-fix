# 03 - 修复步骤详解

## 3.1 总体策略

| 步骤 | 目标 | 方法 |
|------|------|------|
| 1 | 恢复两个版本的独立安装目录 | 从官方安装包 `tar` 解包，分别部署 |
| 2 | 升级国内版到最新版 | 通过官方更新 API 获取 5.8.3 安装包 |
| 3 | 修复快捷方式 | 指向各自独立目录的主程序 |
| 4 | 验证双开 | 同时启动两个版本，确认进程和数据隔离 |

## 3.2 前置准备

### 3.2.1 获取安装包

**方法 A：通过官方更新 API（推荐，获取最新版）**

```powershell
# 查询国内版最新版
$api = "https://copilot.tencent.com/v2/update?platform=workbuddy-win32-x64-user&version=5.3.14&x-user-id=<your-user-id>"
$resp = Invoke-RestMethod -Uri $api
$resp.url          # 下载 URL
$resp.sha256hash   # SHA256 校验值
$resp.version      # 版本号
```

**关键参数说明**：
- `platform=workbuddy-win32-x64-user` → 返回可下载的 user 格式包
- `platform=workbuddy-win32-x64-archive` → 返回 URL 但下载 404（不可用）
- `platform=workbuddy-win32-x64` → 400 错误（不可用）
- `x-user-id`：可从 `~/.workbuddy/` 下的配置文件或日志中获取，也可用任意 UUID 格式字符串

**下载**：
```powershell
curl.exe -L -o "WorkBuddy-win32-x64-user-5.8.3.41334564-db0e9b51.exe" $resp.url
```

**方法 B：使用已下载的安装包**

如果已有安装包（如 `Downloads` 目录中的旧版），可直接使用。注意：
- 5.3.14 等旧版会导致白屏，必须用 5.8.x
- 安装包文件名格式：`WorkBuddy-win32-x64-user-{version}-{build}.exe`

### 3.2.2 校验安装包

```powershell
Get-FileHash "WorkBuddy-win32-x64-user-5.8.3.41334564-db0e9b51.exe" -Algorithm SHA256
# 应与 API 返回的 sha256hash 一致
```

## 3.3 步骤一：部署国内版 5.8.3

### 3.3.1 停止所有 WorkBuddy 进程

```powershell
Get-Process -Name "WorkBuddy" -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process -Name "WorkBuddyAI" -ErrorAction SilentlyContinue | Stop-Process -Force
```

### 3.3.2 从安装包提取文件

WorkBuddy 安装包是 NSIS 自解压格式，Windows 自带的 `tar` 可以直接解压：

```powershell
$pkg = "C:\path\to\WorkBuddy-win32-x64-user-5.8.3.41334564-db0e9b51.exe"
$tmp = "$env:TEMP\wb-deploy"
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
New-Item -ItemType Directory -Path $tmp | Out-Null

tar -xf $pkg -C $tmp
# 5.8.3 约 7258 个文件，app.asar 约 96MB
```

### 3.3.3 部署到安装目录

```powershell
$target = "$env:LOCALAPPDATA\Programs\WorkBuddy"

# /MIR = 镜像模式（删除目标中多余文件，复制新文件）
# 退出码 0-7 均为成功，3 = 复制了文件且有额外文件差异
robocopy $tmp $target /MIR /NFL /NDL /NJH /NJS /NP
```

**为什么不用官方安装器？**

官方 NSIS 安装器在静默安装时，会因旧注册项路径残留把文件装进错误目录（如 `WorkBuddyAI` 目录），并破坏另一版本的 `resources`。`tar` 解包 + `robocopy` 是最可控的方式。

### 3.3.4 验证部署

```powershell
# 文件数应与解压目录一致
(Get-ChildItem $target -Recurse -File | Measure-Object).Count

# app.asar 应存在且大小合理
Get-Item "$target\resources\app.asar"
```

## 3.4 步骤二：恢复/部署国际版

如果国际版也被破坏，用同样的方法部署国际版安装包到 `Programs\WorkBuddyAI\`：

```powershell
$pkgAI = "C:\path\to\WorkBuddy-win32-x64-user-5.8.4.41366630-73952edb.exe"
$tmpAI = "$env:TEMP\wbai-deploy"
tar -xf $pkgAI -C $tmpAI
robocopy $tmpAI "$env:LOCALAPPDATA\Programs\WorkBuddyAI" /MIR /NFL /NDL /NJH /NJS /NP
```

## 3.5 步骤三：修复快捷方式

检查桌面和开始菜单的快捷方式，确保指向正确：

| 快捷方式 | 目标路径 |
|---------|---------|
| WorkBuddy（国内版） | `%LOCALAPPDATA%\Programs\WorkBuddy\WorkBuddy.exe` |
| WorkBuddy AI（国际版） | `%LOCALAPPDATA%\Programs\WorkBuddyAI\WorkBuddyAI.exe` |

```powershell
# 查看桌面快捷方式目标
Get-ChildItem "$env:USERPROFILE\Desktop\*.lnk" | ForEach-Object {
    $sh = New-Object -ComObject WScript.Shell
    $lnk = $sh.CreateShortcut($_.FullName)
    "$($_.Name) -> $($lnk.TargetPath)"
}
```

如指向错误，手动修改或重新创建快捷方式。

## 3.6 步骤四：启动验证

```powershell
# 启动国内版
Start-Process "$env:LOCALAPPDATA\Programs\WorkBuddy\WorkBuddy.exe"

# 启动国际版
Start-Process "$env:LOCALAPPDATA\Programs\WorkBuddyAI\WorkBuddyAI.exe"

# 等待 30 秒后检查
Start-Sleep -Seconds 30
Get-Process -Name "WorkBuddy","WorkBuddyAI" | Select-Object Name, Id
```

预期结果：
- `WorkBuddy` 进程 5-9 个
- `WorkBuddyAI` 进程 5-9 个
- 两个窗口均正常显示界面
