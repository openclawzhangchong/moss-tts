# edge-adapter.ps1 — Edge-TTS 适配器（预留）
#
# 实现 TTS 统一接口，对接 node-edge-tts 在线 TTS
# 使用方式: npm install -g node-edge-tts
#
# TODO: 安装 node-edge-tts 后启用此适配器

$adapterType = "edge"

function Test-TTSConnection {
    try {
        $null = & "npx" "--yes" "node-edge-tts" "--help" 2>&1
        return $true
    } catch {
        return $false
    }
}

function Get-TTSVoices {
    return @(
        @{ Id = "zh-CN-XiaoxiaoNeural"; Name = "晓晓 (女)"; Description = "中文普通话, 女声" },
        @{ Id = "zh-CN-YunxiNeural";    Name = "云希 (男)"; Description = "中文普通话, 男声" },
        @{ Id = "zh-CN-YunyangNeural";  Name = "云扬 (男)"; Description = "中文新闻, 男声" },
        @{ Id = "en-US-AriaNeural";     Name = "Aria (女)"; Description = "美式英语, 女声" },
        @{ Id = "en-US-GuyNeural";      Name = "Guy (男)";  Description = "美式英语, 男声" },
        @{ Id = "ja-JP-NanamiNeural";   Name = "七海 (女)"; Description = "日语, 女声" }
    )
}

function Invoke-TTS {
    param(
        [Parameter(Mandatory)] [string]$Text,
        [string]$Voice = "zh-CN-XiaoxiaoNeural",
        [string]$OutputFile = "",
        [hashtable]$ExtraParams = @{}
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        Write-Error "文本不能为空"
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($OutputFile)) {
        $OutputFile = Get-DefaultTTSOutputPath -TextSnippet $Text
    }

    $parentDir = Split-Path $OutputFile -Parent
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    try {
        $speed = if ($ExtraParams.ContainsKey('Speed')) { $ExtraParams['Speed'] } else { "+0%" }
        $pitch = if ($ExtraParams.ContainsKey('Pitch')) { $ExtraParams['Pitch'] } else { "+0Hz" }

        $result = & "npx" "--yes" "node-edge-tts" `
            "--voice" $Voice `
            "--text" $Text `
            "--speed" $speed `
            "--pitch" $pitch `
            "--output" $OutputFile 2>&1

        if ($LASTEXITCODE -eq 0 -and (Test-Path $OutputFile)) {
            return $OutputFile
        } else {
            Write-Error "Edge-TTS 合成失败: $result"
            return $null
        }
    } catch {
        Write-Error "Edge-TTS 调用异常: $_"
        return $null
    }
}