<#
.SYNOPSIS
    从腾讯官方更新 API 获取 WorkBuddy 国内版最新安装包信息
.DESCRIPTION
    调用 copilot.tencent.com/v2/update API，返回最新版本号、下载 URL 和 SHA256
.PARAMETER CurrentVersion
    当前版本号，默认 5.3.14（用于查询更新）
.PARAMETER UserId
    用户 ID（UUID 格式），可从 ~/.workbuddy 配置或日志中获取
.PARAMETER Platform
    更新平台参数，默认 workbuddy-win32-x64-user（唯一可下载格式）
.PARAMETER Download
    是否同时下载安装包到 Downloads 目录
.EXAMPLE
    .\fetch-update.ps1
.EXAMPLE
    .\fetch-update.ps1 -Download
.EXAMPLE
    .\fetch-update.ps1 -CurrentVersion 5.8.2 -UserId "12345678-1234-1234-1234-123456789012"
#>

param(
    [string]$CurrentVersion = "5.3.14",
    [string]$UserId = "947590d9-45cd-4d8c-953e-5ed626bf1a11",
    [string]$Platform = "workbuddy-win32-x64-user",
    [switch]$Download
)

$ErrorActionPreference = "Stop"

Write-Output "===== WorkBuddy 更新查询 ====="
Write-Output "平台: $Platform"
Write-Output "当前版本: $CurrentVersion"
Write-Output ""

# 构建 API URL
$apiUrl = "https://copilot.tencent.com/v2/update?platform=$Platform&version=$CurrentVersion&x-user-id=$UserId"

try {
    $response = Invoke-RestMethod -Uri $apiUrl -Method Get -TimeoutSec 30
} catch {
    Write-Error "API 请求失败: $($_.Exception.Message)"
    exit 1
}

Write-Output "最新版本: $($response.version)"
Write-Output "产品版本: $($response.productVersion)"
Write-Output "下载 URL: $($response.url)"
Write-Output "SHA256:   $($response.sha256hash)"
Write-Output "时间戳:   $($response.timestamp) ($([DateTimeOffset]::FromUnixTimeSeconds($response.timestamp).LocalDateTime))"
Write-Output "支持快速更新: $($response.supportsFastUpdate)"
Write-Output ""

# 验证 URL 可访问
Write-Output "----- 验证下载 URL -----"
try {
    $head = Invoke-WebRequest -Uri $response.url -Method Head -TimeoutSec 20 -UseBasicParsing
    Write-Output "HTTP 状态: $($head.StatusCode)"
    Write-Output "文件大小: $($head.Headers['Content-Length']) 字节 ($([math]::Round($head.Headers['Content-Length']/1MB, 2)) MB)"
} catch {
    Write-Output "URL 验证失败: $($_.Exception.Message)"
    Write-Output "提示: 如果是 404，尝试更换 platform 参数为 workbuddy-win32-x64-user"
}

# 下载
if ($Download) {
    Write-Output ""
    Write-Output "----- 下载安装包 -----"
    $fileName = Split-Path $response.url -Leaf
    $outPath = Join-Path $env:USERPROFILE "Downloads\$fileName"

    if (Test-Path $outPath) {
        $existing = Get-Item $outPath
        Write-Output "文件已存在: $outPath ($($existing.Length) 字节)"
        $hash = (Get-FileHash $outPath -Algorithm SHA256).Hash
        Write-Output "现有 SHA256: $hash"
        Write-Output "期望 SHA256: $($response.sha256hash)"
        if ($hash -eq $response.sha256hash) {
            Write-Output "✅ 已存在且校验通过，跳过下载"
            exit 0
        } else {
            Write-Output "⚠️ 哈希不匹配，重新下载"
        }
    }

    Write-Output "下载到: $outPath"
    & curl.exe -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/138.0.0.0 Safari/537.36" `
        -o $outPath -s -S -w "HTTP=%{http_code} SIZE=%{size_download} TIME=%{time_total}s" `
        --max-time 600 $response.url

    Write-Output ""
    if (Test-Path $outPath) {
        $file = Get-Item $outPath
        Write-Output "下载完成: $($file.Length) 字节"
        $hash = (Get-FileHash $outPath -Algorithm SHA256).Hash
        Write-Output "SHA256: $hash"
        if ($hash -eq $response.sha256hash) {
            Write-Output "✅ 校验通过"
        } else {
            Write-Error "❌ 校验失败! 期望: $($response.sha256hash)"
            exit 1
        }
    }
}

Write-Output ""
Write-Output "===== 完成 ====="
Write-Output "下一步: 使用 deploy-from-package.ps1 部署安装包"
