# http-adapter.ps1 — 通用 HTTP API TTS 适配器（预留模板）
#
# 实现 TTS 统一接口，对接任何有 REST API 的 TTS 服务。
# 配置方式：设置环境变量或传入 ExtraParams
#
# 示例配置:
#   TTS_HTTP_URL=https://api.example.com/tts
#   TTS_HTTP_API_KEY=sk-xxx

$adapterType = "http"

function Test-TTSConnection {
    $url = $env:TTS_HTTP_URL
    if (-not $url) { return $false }
    try {
        $null = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 5
        return $true
    } catch {
        return $false
    }
}

function Get-TTSVoices {
    return @(
        @{ Id = "default"; Name = "默认音色"; Description = "需要根据实际 API 配置" }
    )
}

function Invoke-TTS {
    param(
        [Parameter(Mandatory)] [string]$Text,
        [string]$Voice = "",
        [string]$OutputFile = "",
        [hashtable]$ExtraParams = @{}
    )
    Write-Warning "HTTP TTS 适配器尚未配置，请设置 TTS_HTTP_URL 环境变量"
    return $null
}