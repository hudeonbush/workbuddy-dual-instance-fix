<#
.SYNOPSIS
    诊断 WorkBuddy 双持环境状态
.DESCRIPTION
    检查两个版本的安装目录、进程、注册表、数据目录和日志，输出诊断报告
.EXAMPLE
    .\diagnose.ps1
#>

$ErrorActionPreference = "SilentlyContinue"
$report = @()

function Add-Report($msg) {
    $script:report += $msg
    Write-Output $msg
}

Add-Report "===== WorkBuddy 双持环境诊断 ====="
Add-Report "时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Add-Report ""

# 1. 进程
Add-Report "----- 1. 进程状态 -----"
$wb = Get-Process -Name "WorkBuddy" -ErrorAction SilentlyContinue
$wai = Get-Process -Name "WorkBuddyAI" -ErrorAction SilentlyContinue
Add-Report "国内版 WorkBuddy 进程数: $(($wb | Measure-Object).Count)"
Add-Report "国际版 WorkBuddyAI 进程数: $(($wai | Measure-Object).Count)"
if ($wb) { $wb | Select-Object -First 3 Id, StartTime | Format-Table -AutoSize | Out-String | ForEach-Object { Add-Report $_ } }
Add-Report ""

# 2. 安装目录
Add-Report "----- 2. 安装目录 -----"
$dirs = @{
    "国内版" = "$env:LOCALAPPDATA\Programs\WorkBuddy"
    "国际版" = "$env:LOCALAPPDATA\Programs\WorkBuddyAI"
}
foreach ($k in $dirs.Keys) {
    $d = $dirs[$k]
    if (Test-Path $d) {
        $cnt = (Get-ChildItem $d -Recurse -File -Force | Measure-Object).Count
        $asar = Get-Item "$d\resources\app.asar" -ErrorAction SilentlyContinue
        $exe = Get-Item "$d\WorkBuddy.exe" -ErrorAction SilentlyContinue
        $exeAI = Get-Item "$d\WorkBuddyAI.exe" -ErrorAction SilentlyContinue
        Add-Report "[$k] $d"
        Add-Report "  文件数: $cnt"
        Add-Report "  app.asar: $(if ($asar) { "$($asar.Length) 字节" } else { '缺失!' })"
        Add-Report "  WorkBuddy.exe: $(if ($exe) { '存在' } else { '缺失' })"
        Add-Report "  WorkBuddyAI.exe: $(if ($exeAI) { '存在' } else { '缺失' })"
    } else {
        Add-Report "[$k] $d → 目录不存在!"
    }
}
Add-Report ""

# 3. 数据目录
Add-Report "----- 3. 数据目录 -----"
$dataDirs = @{
    "国内版" = "$env:USERPROFILE\.workbuddy"
    "国际版" = "$env:USERPROFILE\.workbuddy-ai"
}
foreach ($k in $dataDirs.Keys) {
    $d = $dataDirs[$k]
    if (Test-Path $d) {
        $latest = Get-ChildItem "$d\logs" -Recurse -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        Add-Report "[$k] $d → 存在, 最新日志: $($latest.Name) ($($latest.LastWriteTime))"
    } else {
        Add-Report "[$k] $d → 不存在"
    }
}
Add-Report ""

# 4. 版本信息（从 AppStartup.log）
Add-Report "----- 4. 版本信息 -----"
foreach ($k in $dataDirs.Keys) {
    $log = "$($dataDirs[$k])\logs\AppStartup.log"
    if (Test-Path $log) {
        $last = Get-Content $log -Tail 1 -ErrorAction SilentlyContinue
        if ($last -match 'appVersion=([\d.]+)') {
            Add-Report "[$k] appVersion=$($Matches[1])"
        }
    }
}
Add-Report ""

# 5. 渲染健康检查
Add-Report "----- 5. 渲染健康检查 -----"
foreach ($k in $dataDirs.Keys) {
    $rlog = "$($dataDirs[$k])\logs\renderer.log"
    if (Test-Path $rlog) {
        $tail = Get-Content $rlog -Tail 20 -ErrorAction SilentlyContinue
        $hasCrash = $tail | Select-String -Pattern "React error #31|Minified React error"
        $hasHeartbeat = $tail | Select-String -Pattern "heartbeat|render-diag"
        Add-Report "[$k] React崩溃: $(if ($hasCrash) { '⚠️ 发现!' } else { '无' })"
        Add-Report "[$k] 渲染心跳: $(if ($hasHeartbeat) { '正常' } else { '未检测到' })"
    }
}
Add-Report ""

# 6. 快捷方式
Add-Report "----- 6. 桌面快捷方式 -----"
Get-ChildItem "$env:USERPROFILE\Desktop\*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
    $sh = New-Object -ComObject WScript.Shell
    $lnk = $sh.CreateShortcut($_.FullName)
    if ($lnk.TargetPath -match "WorkBuddy") {
        Add-Report "  $($_.Name) -> $($lnk.TargetPath)"
    }
}
Add-Report ""

Add-Report "===== 诊断完成 ====="
