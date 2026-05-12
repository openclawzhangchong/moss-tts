<#
.SYNOPSIS
  MOSS-TTS 技能 — 统一 TTS 命令行入口
#>

param(
  [string]$Text = "",
  [string]$TextFile = "",
  [string]$Adapter = "moss",
  [string]$Voice = "",
  [string]$RefAudio = "",
  [string]$OutputFile = "",
  [int]$MaxNewFrames = 375,
  [int]$CpuThreads = 0,
  [float]$Temperature = 0.8,
  [switch]$ListAdapters,
  [switch]$ListVoices,
  [switch]$Status,
  [switch]$MorningBrief,
  [switch]$DryRun
)

$ErrorActionPreference = "Continue"
$SCRIPT_DIR = Split-Path $PSCommandPath -Parent
$LIB_DIR    = Join-Path $SCRIPT_DIR "lib"
$ADAPTER_DIR = Join-Path $SCRIPT_DIR "adapters"
$PIPELINE_DIR = Join-Path $SCRIPT_DIR "pipelines"

# ---- 加载核心模块 ----
$modulePath = Join-Path $LIB_DIR "TTSAdapter.psm1"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force -ErrorAction Stop
} else {
    Write-Host "[ERR] 找不到核心模块: $modulePath" -ForegroundColor Red
    exit 1
}

# ---- 加载适配器（脚本级 dot-source） ----
$adapterPath = Join-Path $ADAPTER_DIR "${Adapter}-adapter.ps1"
if (-not (Test-Path $adapterPath)) {
    Write-Host "[ERR] 适配器 '$Adapter' 不存在" -ForegroundColor Red
    Write-Host "  可用: moss, edge, http" -ForegroundColor Yellow
    exit 1
}
. $adapterPath

# ---- 列出适配器 ----
if ($ListAdapters) {
    $adapters = Get-TTSAdapters
    Write-Host "可用 TTS 适配器:" -ForegroundColor Cyan
    foreach ($name in $adapters.Keys | Sort-Object) {
        $info = $adapters[$name]
        $icon = if ($info.Loaded) { "[OK]" } else { "[--]" }
        $color = if ($info.Loaded) { "Green" } else { "Gray" }
        Write-Host "  $icon $name (type=$($info.Type))" -ForegroundColor $color
    }
    exit 0
}

# ---- 检查状态 ----
if ($Status) {
    $ok = Test-TTSConnection
    if ($ok) {
        Write-Host "[OK] $Adapter 服务正常" -ForegroundColor Green
    } else {
        Write-Host "[ERR] $Adapter 服务不可用" -ForegroundColor Red
    }
    exit 0
}

# ---- 列出音色 ----
if ($ListVoices) {
    $voices = Get-TTSVoices
    Write-Host "$Adapter 可用音色:" -ForegroundColor Cyan
    foreach ($v in $voices) {
        Write-Host "  $($v.Id)  ->  $($v.Name)" -ForegroundColor Yellow
    }
    exit 0
}

# ---- 早间播报 ----
if ($MorningBrief) {
    $briefArgs = @{}
    if ($Adapter) { $briefArgs['AdapterName'] = $Adapter }
    if ($Voice)   { $briefArgs['Voice'] = $Voice }
    if ($DryRun)  { $briefArgs['DryRun'] = $true }

    & (Join-Path $PIPELINE_DIR "morning-brief.ps1") @briefArgs
    exit $LASTEXITCODE
}

# ---- 单次合成 ----
if (-not (Test-TTSConnection)) {
    Write-Host "[ERR] $Adapter 服务不可用" -ForegroundColor Red
    exit 1
}

$inputText = ""
if (-not [string]::IsNullOrWhiteSpace($TextFile)) {
    if (Test-Path $TextFile) {
        $inputText = Get-Content $TextFile -Raw -Encoding UTF8
        Write-Host "-> 从文件读取: $TextFile ($($inputText.Length) 字符)" -ForegroundColor Yellow
    } else {
        Write-Host "[ERR] 文件不存在: $TextFile" -ForegroundColor Red
        exit 1
    }
} elseif (-not [string]::IsNullOrWhiteSpace($Text)) {
    $inputText = $Text
} else {
    Write-Host "[ERR] 请提供文本（-Text 或 -TextFile）" -ForegroundColor Red
    Write-Host "  示例: .\skills\moss-tts\tts.ps1 -Text '你好'" -ForegroundColor Gray
    exit 1
}

if ([string]::IsNullOrWhiteSpace($Voice)) {
    $Voice = if ($Adapter -eq "edge") { "zh-CN-XiaoxiaoNeural" } else { "demo-1" }
}

$extra = @{
    MaxNewFrames = $MaxNewFrames
    CpuThreads   = $CpuThreads
    Temperature  = $Temperature
}
if (-not [string]::IsNullOrWhiteSpace($RefAudio)) {
    $extra['RefAudio'] = $RefAudio
}

Write-Host "-> 合成中... (适配器=$Adapter, 音色=$Voice)" -ForegroundColor Yellow
$startTime = Get-Date
$result = Invoke-TTS -Text $inputText -Voice $Voice -OutputFile $OutputFile -ExtraParams $extra
$elapsed = (Get-Date) - $startTime

if ($result -and (Test-Path $result)) {
    $fileSize = [math]::Round((Get-Item $result).Length / 1KB, 1)
    $elapsedStr = $elapsed.TotalSeconds.ToString("0.0")
    Write-Host "[OK] 合成完成 (${elapsedStr}s)" -ForegroundColor Green
    Write-Host "  文件: $result" -ForegroundColor White
    Write-Host "  大小: $fileSize KB" -ForegroundColor White
} else {
    Write-Host "[ERR] 合成失败" -ForegroundColor Red
    exit 1
}