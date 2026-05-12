# TTSAdapter.psm1 — 统一 TTS 适配器加载器
#
# 提供适配器发现和通用工具函数。
# 具体 TTS 函数由各 adapter 文件定义。

# ==================== 适配器加载器 ====================

<#
.SYNOPSIS
  加载所有可用的 TTS 适配器
.DESCRIPTION
  扫描 adapters/ 目录，加载所有 .ps1 文件
  返回: @{ AdapterName = @{ Loaded=$true; Type="moss"/"edge"/... }; ... }
#>
function Get-TTSAdapters {
    $scriptDir = Split-Path $PSCommandPath -Parent
    $adapterDir = Join-Path $scriptDir "..\adapters"
    $result = @{}

    if (-not (Test-Path $adapterDir)) { return $result }

    foreach ($adapterFile in Get-ChildItem $adapterDir -Filter "*.ps1") {
        $adapterName = $adapterFile.BaseName
        try {
            . $adapterFile.FullName
            $result[$adapterName] = @{
                Loaded = $true
                Type   = if (Test-Path "variable:adapterType") { $adapterType } else { $adapterName }
            }
        } catch {
            $result[$adapterName] = @{ Loaded = $false; Error = "$_" }
        }
    }

    return $result
}

# ==================== 通用工具函数 ====================

<#
.SYNOPSIS
  获取默认输出路径（output/tts/ 下带时间戳的文件名）
#>
function Get-DefaultTTSOutputPath {
    param([string]$TextSnippet = "tts")

    $outDir = Join-Path (Split-Path $PSCommandPath -Parent) "..\..\output\tts"
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    if (-not [string]::IsNullOrWhiteSpace($TextSnippet)) {
        $snipLen = [Math]::Min(30, $TextSnippet.Length)
        $TextSnippet = $TextSnippet.Substring(0, $snipLen)
        $TextSnippet = $TextSnippet -replace '[\\/:*?"<>|]', ''
    }
    return Join-Path $outDir "${timestamp}_${TextSnippet}.wav"
}

Export-ModuleMember -Function Get-TTSAdapters, Get-DefaultTTSOutputPath