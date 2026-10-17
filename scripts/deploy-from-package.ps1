<#
.SYNOPSIS
    从 WorkBuddy 安装包部署到指定目录
.DESCRIPTION
    使用 tar 解包 NSIS 安装包，然后用 robocopy /MIR 镜像部署到目标目录。
    不使用官方安装器，避免路径残留导致的目录合并问题。
.PARAMETER PackagePath
    安装包路径（.exe 文件）
.PARAMETER TargetDir
    目标安装目录，默认 %LOCALAPPDATA%\Programs\WorkBuddy
.PARAMETER ExpectedSha256
    期望的 SHA256 哈希（可选，提供则校验）
.PARAMETER SkipStop
    不停止现有进程（默认会停止）
.EXAMPLE
    .\deploy-from-package.ps1 -PackagePath "C:\Users\me\Downloads\WorkBuddy-win32-x64-user-5.8.3.41334564-db0e9b51.exe"
.EXAMPLE
    .\deploy-from-package.ps1 -PackagePath ".\wb.exe" -TargetDir "$env:LOCALAPPDATA\Programs\WorkBuddyAI" -ExpectedSha256 "824de..."
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$PackagePath,

    [string]$TargetDir = "$env:LOCALAPPDATA\Programs\WorkBuddy",

    [string]$ExpectedSha256 = "",

    [switch]$SkipStop
)

$ErrorActionPreference = "Stop"

Write-Output "===== WorkBuddy 部署 ====="
Write-Output "安装包: $PackagePath"
Write-Output "目标目录: $TargetDir"
Write-Output ""

# 1. 验证安装包
if (-not (Test-Path $PackagePath)) {
    Write-Error "安装包不存在: $PackagePath"
    exit 1
}

$pkg = Get-Item $PackagePath
Write-Output "安装包大小: $($pkg.Length) 字节 ($([math]::Round($pkg.Length/1MB, 2)) MB)"

if ($ExpectedSha256) {
    Write-Output "校验 SHA256..."
    $actual = (Get-FileHash $PackagePath -Algorithm SHA256).Hash
    Write-Output "实际: $actual"
    Write-Output "期望: $ExpectedSha256"
    if ($actual -ne $ExpectedSha256) {
        Write-Error "❌ SHA256 不匹配，终止部署"
        exit 1
    }
    Write-Output "✅ 校验通过"
}
Write-Output ""

# 2. 停止进程
if (-not $SkipStop) {
    Write-Output "----- 停止现有进程 -----"
    $procs = Get-Process -Name "WorkBuddy","WorkBuddyAI" -ErrorAction SilentlyContinue
    if ($procs) {
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Write-Output "已停止 $($procs.Count) 个进程"
    } else {
        Write-Output "无运行中的进程"
    }
    Write-Output ""
}

# 3. 解压到临时目录
Write-Output "----- 解压安装包 -----"
$tmpDir = Join-Path $env:TEMP "wb-deploy-$(Get-Random)"
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
Write-Output "临时目录: $tmpDir"

$tarOutput = & tar -xf $PackagePath -C $tmpDir 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "tar 解压失败 (退出码 $LASTEXITCODE): $tarOutput"
    exit 1
}

$fileCount = (Get-ChildItem $tmpDir -Recurse -File -Force | Measure-Object).Count
Write-Output "解压文件数: $fileCount"

# 检查关键文件
$asar = Get-Item "$tmpDir\resources\app.asar" -ErrorAction SilentlyContinue
if (-not $asar) {
    Write-Error "❌ 解压后未找到 resources\app.asar，安装包可能损坏"
    exit 1
}
Write-Output "app.asar: $($asar.Length) 字节 ($([math]::Round($asar.Length/1MB, 2)) MB)"
Write-Output ""

# 4. 部署到目标目录
Write-Output "----- 部署到目标目录 -----"
if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    Write-Output "创建目标目录"
}

# robocopy /MIR: 镜像模式，删除目标中多余文件，复制新文件
# 退出码 0-7 均为成功
$robocopyOutput = & robocopy $tmpDir $TargetDir /MIR /NFL /NDL /NJH /NJS /NP 2>&1
$rc = $LASTEXITCODE
Write-Output "robocopy 退出码: $rc ($(if ($rc -le 7) { '成功' } else { '失败' }))"

if ($rc -gt 7) {
    Write-Error "❌ robocopy 失败: $robocopyOutput"
    exit 1
}

$deployedCount = (Get-ChildItem $TargetDir -Recurse -File -Force | Measure-Object).Count
Write-Output "部署后文件数: $deployedCount"
Write-Output ""

# 5. 验证部署
Write-Output "----- 验证部署 -----"
$deployedAsar = Get-Item "$TargetDir\resources\app.asar" -ErrorAction SilentlyContinue
if ($deployedAsar -and $deployedAsar.Length -eq $asar.Length) {
    Write-Output "✅ app.asar 大小一致: $($deployedAsar.Length) 字节"
} else {
    Write-Error "❌ app.asar 验证失败"
    exit 1
}

$exe = Get-Item "$TargetDir\WorkBuddy.exe" -ErrorAction SilentlyContinue
if ($exe) {
    Write-Output "✅ WorkBuddy.exe 存在"
} else {
    $exeAI = Get-Item "$TargetDir\WorkBuddyAI.exe" -ErrorAction SilentlyContinue
    if ($exeAI) {
        Write-Output "✅ WorkBuddyAI.exe 存在（国际版目录）"
    } else {
        Write-Output "⚠️ 未找到主程序 exe"
    }
}
Write-Output ""

# 6. 清理临时目录
Write-Output "----- 清理 -----"
Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Output "已清理临时目录"
Write-Output ""

Write-Output "===== 部署完成 ====="
Write-Output "目标目录: $TargetDir"
Write-Output "文件数: $deployedCount"
Write-Output "下一步: 启动 WorkBuddy 验证界面"
