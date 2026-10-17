<#
.SYNOPSIS
    验证 WorkBuddy 国内版与国际版双开状态
.DESCRIPTION
    检查两个版本的进程、版本号、渲染健康度和数据目录隔离
.PARAMETER WaitSeconds
    启动后等待秒数，默认 30
.PARAMETER AutoStart
    自动启动两个版本（如果未运行）
.EXAMPLE
    .\verify-dual-run.ps1
.EXAMPLE
    .\verify-dual-run.ps1 -AutoStart -WaitSeconds 45
#>

param(
    [int]$WaitSeconds = 30,
    [switch]$AutoStart
)

$ErrorActionPreference = "SilentlyContinue"
$pass = 0
$fail = 0
$warn = 0

function Check($name, $condition, $detail = "") {
    if ($condition) {
        Write-Output "  ✅ $name"
        $script:pass++
    } else {
        Write-Output "  ❌ $name $detail"
        $script:fail++
    }
}

function Warn($name, $detail = "") {
    Write-Output "  ⚠️  $name $detail"
    $script:warn++
}

Write-Output "===== WorkBuddy 双开验证 ====="
Write-Output "时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output ""

# 自动启动
if ($AutoStart) {
    Write-Output "----- 自动启动 -----"
    $wbExe = "$env:LOCALAPPDATA\Programs\WorkBuddy\WorkBuddy.exe"
    $waiExe = "$env:LOCALAPPDATA\Programs\WorkBuddyAI\WorkBuddyAI.exe"
    if (Test-Path $wbExe) { Start-Process $wbExe; Write-Output "  启动国内版" }
    if (Test-Path $waiExe) { Start-Process $waiExe; Write-Output "  启动国际版" }
    Write-Output "  等待 $WaitSeconds 秒..."
    Start-Sleep -Seconds $WaitSeconds
    Write-Output ""
}

# 1. 进程
Write-Output "----- 1. 进程检查 -----"
$wb = Get-Process -Name "WorkBuddy" -ErrorAction SilentlyContinue
$wai = Get-Process -Name "WorkBuddyAI" -ErrorAction SilentlyContinue
$wbCount = ($wb | Measure-Object).Count
$waiCount = ($wai | Measure-Object).Count

Check "国内版进程存在 (>=1)", ($wbCount -ge 1), "实际: $wbCount"
Check "国际版进程存在 (>=1)", ($waiCount -ge 1), "实际: $waiCount"
Check "国内版进程数合理 (3-15)", ($wbCount -ge 3 -and $wbCount -le 15), "实际: $wbCount"
Check "国际版进程数合理 (3-15)", ($waiCount -ge 3 -and $waiCount -le 15), "实际: $waiCount"
Write-Output "  国内版: $wbCount 进程, 国际版: $waiCount 进程"
Write-Output ""

# 2. 版本
Write-Output "----- 2. 版本检查 -----"
$wbLog = "$env:USERPROFILE\.workbuddy\logs\AppStartup.log"
$waiLog = "$env:USERPROFILE\.workbuddy-ai\logs\AppStartup.log"

$wbVer = ""
$waiVer = ""
if (Test-Path $wbLog) {
    $last = Get-Content $wbLog -Tail 5 | Where-Object { $_ -match 'appVersion=([\d.]+)' } | Select-Object -Last 1
    if ($last -match 'appVersion=([\d.]+)') { $wbVer = $Matches[1] }
}
if (Test-Path $waiLog) {
    $last = Get-Content $waiLog -Tail 5 | Where-Object { $_ -match 'appVersion=([\d.]+)' } | Select-Object -Last 1
    if ($last -match 'appVersion=([\d.]+)') { $waiVer = $Matches[1] }
}

Check "国内版版本已记录", ($wbVer -ne ""), "AppStartup.log 无版本信息"
Check "国际版版本已记录", ($waiVer -ne ""), "AppStartup.log 无版本信息"
if ($wbVer) { Write-Output "  国内版: $wbVer" }
if ($waiVer) { Write-Output "  国际版: $waiVer" }
if ($wbVer -and [version]$wbVer -lt [version]"5.8.0") {
    Warn "国内版版本过低 ($wbVer)，可能导致白屏，建议升级到 5.8.x"
}
Write-Output ""

# 3. 渲染健康
Write-Output "----- 3. 渲染健康检查 -----"
foreach ($pair in @(@("国内版", "$env:USERPROFILE\.workbuddy\logs\renderer.log"),
                    @("国际版", "$env:USERPROFILE\.workbuddy-ai\logs\renderer.log"))) {
    $name = $pair[0]
    $rlog = $pair[1]
    if (Test-Path $rlog) {
        $tail = Get-Content $rlog -Tail 30
        $hasCrash = $tail | Select-String -Pattern "React error #31|Minified React error"
        $hasHeartbeat = $tail | Select-String -Pattern "heartbeat|render-diag"
        Check "$name 无 React 崩溃", (-not $hasCrash)
        if (-not $hasHeartbeat) { Warn "$name 未检测到渲染心跳" }
    } else {
        Warn "$name renderer.log 不存在"
    }
}
Write-Output ""

# 4. 数据目录隔离
Write-Output "----- 4. 数据目录隔离 -----"
$wbData = "$env:USERPROFILE\.workbuddy"
$waiData = "$env:USERPROFILE\.workbuddy-ai"
Check "国内版数据目录存在", (Test-Path $wbData)
Check "国际版数据目录存在", (Test-Path $waiData)
Check "数据目录不同", ($wbData -ne $waiData)

# 检查最新日志时间
foreach ($pair in @(@("国内版", "$wbData\logs"), @("国际版", "$waiData\logs"))) {
    $name = $pair[0]
    $logDir = $pair[1]
    if (Test-Path $logDir) {
        $latest = Get-ChildItem $logDir -Recurse -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        $age = (Get-Date) - $latest.LastWriteTime
        Check "$name 日志近期写入", ($age.TotalMinutes -lt 10), "最新: $($latest.LastWriteTime) ($([math]::Round($age.TotalMinutes,1)) 分钟前)"
    }
}
Write-Output ""

# 5. 安装目录
Write-Output "----- 5. 安装目录检查 -----"
$wbDir = "$env:LOCALAPPDATA\Programs\WorkBuddy"
$waiDir = "$env:LOCALAPPDATA\Programs\WorkBuddyAI"
Check "国内版安装目录存在", (Test-Path $wbDir)
Check "国际版安装目录存在", (Test-Path $waiDir)
Check "国内版 app.asar 存在", (Test-Path "$wbDir\resources\app.asar")
Check "国际版 app.asar 存在", (Test-Path "$waiDir\resources\app.asar")
Write-Output ""

# 总结
Write-Output "===== 验证总结 ====="
Write-Output "通过: $pass, 失败: $fail, 警告: $warn"
if ($fail -eq 0) {
    Write-Output "✅ 双开验证全部通过"
} else {
    Write-Output "❌ 有 $fail 项未通过，请检查上方详情"
}
