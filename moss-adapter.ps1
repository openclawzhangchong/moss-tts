# moss-adapter.ps1 — MOSS-TTS-Nano 适配器
#
# 实现 TTS 统一接口，对接本地 MOSS-TTS 服务 (http://127.0.0.1:18083)
# 支持预设音色和语音克隆（参考音频）

$adapterType = "moss"
$BASE_URL = "http://127.0.0.1:18083"

function Test-TTSConnection {
    try {
        $resp = Invoke-RestMethod -Uri "$BASE_URL/api/warmup-status" -Method Get -TimeoutSec 5
        return $resp.ready -eq $true
    } catch {
        return $false
    }
}

function Get-TTSVoices {
    $demoPath = "D:\MOSS-TTS-Nano-jxshn-com\MOSS-TTS-Nano-jxshn-com\assets\demo.jsonl"
    $voices = @()

    if (-not (Test-Path $demoPath)) { return $voices }

    $lines = Get-Content $demoPath -Encoding UTF8
    $idx = 1
    foreach ($line in $lines) {
        try {
            $d = $line | ConvertFrom-Json
            $lang = "other"
            if ($d.name -match '[一-龥]') { $lang = "zh" }
            elseif ($d.name -match '[A-Za-z]') { $lang = "en" }

            $voices += @{
                Id          = "demo-$idx"
                Name        = $d.name
                Description = "预设音色 #$idx"
                Gender      = if ($d.gender) { $d.gender } else { "unknown" }
                Language    = $lang
            }
            $idx++
        } catch { }
    }
    return $voices
}

function Invoke-TTS {
    param(
        [Parameter(Mandatory)] [string]$Text,
        [string]$Voice = "demo-1",
        [string]$OutputFile = "",
        [hashtable]$ExtraParams = @{}
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        Write-Error "文本不能为空"
        return $null
    }

    $maxFrames = if ($ExtraParams.ContainsKey('MaxNewFrames')) { $ExtraParams['MaxNewFrames'] } else { 375 }
    $cpuThreads = if ($ExtraParams.ContainsKey('CpuThreads')) { $ExtraParams['CpuThreads'] } else { 0 }
    $temperature = if ($ExtraParams.ContainsKey('Temperature')) { $ExtraParams['Temperature'] } else { 0.8 }

    $curlArgs = @("-s", "-X", "POST", "${BASE_URL}/api/generate")
    $curlArgs += @("-F", "text=${Text}")
    $curlArgs += @("-F", "max_new_frames=${maxFrames}")
    $curlArgs += @("-F", "cpu_threads=${cpuThreads}")
    $curlArgs += @("-F", "audio_temperature=${temperature}")

    $refAudio = if ($ExtraParams.ContainsKey('RefAudio')) { $ExtraParams['RefAudio'] } else { "" }
    $hasRefAudio = (-not [string]::IsNullOrWhiteSpace($refAudio)) -and (Test-Path $refAudio)
    if ($hasRefAudio) {
        $curlArgs += @("-F", "prompt_audio=@${refAudio}")
    } else {
        $curlArgs += @("-F", "demo_id=${Voice}")
    }

    if ([string]::IsNullOrWhiteSpace($OutputFile)) {
        $OutputFile = Get-DefaultTTSOutputPath -TextSnippet $Text
    }

    $tmpJson = [System.IO.Path]::GetTempFileName() + ".json"

    try {
        $curlArgs += @("-o", $tmpJson, "-w", "%{http_code}")
        $httpCode = & "curl.exe" $curlArgs 2>&1

        if ($LASTEXITCODE -ne 0 -or $httpCode -ne 200) {
            Write-Error "MOSS-TTS 合成失败 (HTTP $httpCode)"
            return $null
        }

        $rawJson = Get-Content $tmpJson -Raw -Encoding UTF8
        $response = $rawJson | ConvertFrom-Json

        if ([string]::IsNullOrWhiteSpace($response.audio_base64)) {
            Write-Error "返回数据中没有音频"
            return $null
        }

        $wavBytes = [System.Convert]::FromBase64String($response.audio_base64)
        $parentDir = Split-Path $OutputFile -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        [System.IO.File]::WriteAllBytes($OutputFile, $wavBytes)

        return $OutputFile
    } catch {
        Write-Error "MOSS-TTS 调用异常: $_"
        return $null
    } finally {
        if (Test-Path $tmpJson) { Remove-Item $tmpJson -Force -ErrorAction SilentlyContinue }
    }
}