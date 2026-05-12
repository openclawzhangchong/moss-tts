# morning-brief.ps1 — 早间新闻播报流水线（路线 A）
#
# 流程: 采集新闻 -> AI 整理摘要 -> TTS 合成 -> 保存音频
#
# 使用方式:
#   powershell -File skills/moss-tts/pipelines/morning-brief.ps1
#
# 依赖:
#   - MOSS-TTS 服务运行中 (http://127.0.0.1:18083)
#   - 已登录 Edge 浏览器（用于 OpenCLI 采集新闻）

param(
  [string]$AdapterName = "moss",
  [string]$Voice = "demo-1",
  [string]$OutputDir = "",
  [switch]$DryRun
)

$ErrorActionPreference = "Continue"

$SCRIPT_DIR = Split-Path $PSCommandPath -Parent
$SKILL_DIR  = Split-Path $SCRIPT_DIR -Parent
$WORKSPACE  = Split-Path $SKILL_DIR -Parent
$LIB_DIR    = Join-Path $SKILL_DIR "lib"
$ADAPTER_DIR = Join-Path $SKILL_DIR "adapters"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  MOSS-TTS 早间播报流水线" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$modulePath = Join-Path $LIB_DIR "TTSAdapter.psm1"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force -ErrorAction Stop
    Write-Host "[OK] 核心模块已加载" -ForegroundColor Green
} else {
    Write-Host "[ERR] 找不到核心模块: $modulePath" -ForegroundColor Red
    exit 1
}

$adapterPath = Join-Path $ADAPTER_DIR "${AdapterName}-adapter.ps1"
if (-not (Test-Path $adapterPath)) {
    Write-Host "[ERR] 找不到适配器: $adapterPath" -ForegroundColor Red
    Write-Host "  可用适配器:"
    Get-ChildItem $ADAPTER_DIR -Filter "*.ps1" | ForEach-Object {
        Write-Host "    - $($_.BaseName)" -ForegroundColor Yellow
    }
    exit 1
}

. $adapterPath
Write-Host "[OK] 适配器已加载: $AdapterName" -ForegroundColor Green

if (-not (Test-TTSConnection)) {
    Write-Host "[ERR] TTS 服务不可用" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] TTS 服务连接正常" -ForegroundColor Green

# ============ Step 1: 采集新闻 ============

Write-Host "`n[1/4] 采集今日热点新闻..." -ForegroundColor Yellow

$newsItems = @()

try {
    $hpResult = & "opencli" "hupu" "hot" "--limit" "5" 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -and $hpResult) {
        $short = ($hpResult -replace "`n", " | " -replace "`r", "")
        $len = [Math]::Min(500, $short.Length)
        $newsItems += "[虎扑] " + $short.Substring(0, $len)
        Write-Host "  [OK] 虎扑热点" -ForegroundColor Green
    }
} catch { Write-Host "  [--] 虎扑跳过" -ForegroundColor Gray }

try {
    $zhResult = & "opencli" "zhihu" "hot" "--limit" "5" 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -and $zhResult) {
        $short = ($zhResult -replace "`n", " | " -replace "`r", "")
        $len = [Math]::Min(500, $short.Length)
        $newsItems += "[知乎] " + $short.Substring(0, $len)
        Write-Host "  [OK] 知乎热搜" -ForegroundColor Green
    }
} catch { Write-Host "  [--] 知乎跳过" -ForegroundColor Gray }

try {
    $bdResult = & "opencli" "baidu" "hot" "--limit" "5" 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -and $bdResult) {
        $short = ($bdResult -replace "`n", " | " -replace "`r", "")
        $len = [Math]::Min(500, $short.Length)
        $newsItems += "[百度] " + $short.Substring(0, $len)
        Write-Host "  [OK] 百度热搜" -ForegroundColor Green
    }
} catch { Write-Host "  [--] 百度跳过" -ForegroundColor Gray }

if ($newsItems.Count -eq 0) {
    Write-Host "  [!] 未采集到新闻，使用占位文本" -ForegroundColor Yellow
    $newsItems = @("早上好！今天天气不错，适合听一段播报。")
}

# ============ Step 2: 整理摘要 ============

Write-Host "`n[2/4] 整理播报文稿..." -ForegroundColor Yellow

$today = Get-Date -Format "yyyy年MM月dd日 dddd"
$briefText = @"
早上好！今天是 $today，欢迎收听今天的早间新闻播报。

$($newsItems -join "`n`n")

以上就是今天的早间播报内容，祝您有愉快的一天！
"@

$charCount = $briefText.Length
Write-Host "  [OK] 文稿已生成 ($charCount 字)" -ForegroundColor Green

if ($DryRun) {
    Write-Host "`n========== 文稿预览 ==========" -ForegroundColor Cyan
    Write-Host $briefText
    Write-Host "==============================`n" -ForegroundColor Cyan
    Write-Host "[DryRun] 模式，不执行合成" -ForegroundColor Yellow
    exit 0
}

# ============ Step 3: TTS 合成 ============

Write-Host "`n[3/4] 语音合成中..." -ForegroundColor Yellow

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $WORKSPACE "output\podcast"
}
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

$dateStr = Get-Date -Format "yyyyMMdd"
$outputFile = Join-Path $OutputDir "早间播报_${dateStr}.wav"

Write-Host "  音色: $Voice" -ForegroundColor Gray
Write-Host "  输出: $outputFile" -ForegroundColor Gray

$result = Invoke-TTS -Text $briefText -Voice $Voice -OutputFile $outputFile

# ============ Step 4: 完成 ============

if ($result -and (Test-Path $result)) {
    $fileSize = [math]::Round((Get-Item $result).Length / 1KB, 1)
    $duration = [math]::Round($charCount / 4 / 60, 1)
    Write-Host "`n[4/4] 播报完成！" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  文件: $result" -ForegroundColor White
    Write-Host "  大小: $fileSize KB" -ForegroundColor White
    Write-Host "  时长: 约 $duration 分钟" -ForegroundColor White
    Write-Host "  音色: $Voice" -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Cyan
} else {
    Write-Host "`n[ERR] 合成失败" -ForegroundColor Red
    exit 1
}