# MOSS-TTS 语音合成技能
这是我封装的能够克隆任何人声音的工具，搭配agent使用，openclaw最合适，只要3秒别人的语言就能克隆。
统一 TTS 语音合成接口，支持多后端切换和流水线编排。

## 架构

```
skills/moss-tts/
├── SKILL.md                  ← 本文档
├── tts.ps1                   ← 统一 CLI 入口
├── lib/
│   └── TTSAdapter.psm1       ← 核心模块（接口定义 + 适配器加载器）
├── adapters/
│   ├── moss-adapter.ps1      ← MOSS-TTS-Nano 适配器 ✅ 可用
│   ├── edge-adapter.ps1      ← Edge-TTS 适配器 🔧 预留
│   └── http-adapter.ps1      ← 通用 HTTP API 适配器 🔧 预留模板
└── pipelines/
    └── morning-brief.ps1     ← 早间播报流水线
```

## 适配器接口

所有 TTS 后端统一实现三个函数，新增后端只需在 `adapters/` 下创建新文件：

| 函数 | 说明 |
|------|------|
| `Test-TTSConnection` | 测试服务是否可用 → $true/$false |
| `Get-TTSVoices` | 获取音色列表 → @( @{Id, Name, Description}, ... ) |
| `Invoke-TTS` | 合成语音 → 输出文件路径 / $null |

## 快速开始

### 前提条件

MOSS-TTS 服务已启动：
```
D:\MOSS-TTS-Nano-jxshn-com\MOSS-TTS-Nano-jxshn-com\启动.bat
```
服务地址：`http://127.0.0.1:18083`

### 基本用法

```powershell
# 检查服务状态
.\skills\moss-tts\tts.ps1 -Status

# 列出可用适配器
.\skills\moss-tts\tts.ps1 -ListAdapters

# 列出预设音色
.\skills\moss-tts\tts.ps1 -ListVoices -Adapter moss

# 合成语音（默认 moss 适配器，demo-1 音色）
.\skills\moss-tts\tts.ps1 -Text "你好，欢迎收听今天的播报。"

# 指定音色
.\skills\moss-tts\tts.ps1 -Text "这是一段测试。" -Voice demo-5

# 语音克隆（上传参考音频）
.\skills\moss-tts\tts.ps1 -Text "克隆我的声音。" -RefAudio "D:\voice_samples\my_voice.wav"

# 从文件读取长文本
.\skills\moss-tts\tts.ps1 -TextFile "script.txt"

# 精细控制
.\skills\moss-tts\tts.ps1 -Text "稳定生成。" -MaxNewFrames 250 -Temperature 0.7 -CpuThreads 6

# 自定义输出路径
.\skills\moss-tts\tts.ps1 -Text "保存到指定位置。" -OutputFile "D:\output\podcast.wav"
```

### 早间播报流水线

```powershell
# 执行完整流水线（采集 → 整理 → 合成）
.\skills\moss-tts\tts.ps1 -MorningBrief

# 预览文稿（不合成）
.\skills\moss-tts\tts.ps1 -MorningBrief -DryRun

# 指定音色
.\skills\moss-tts\tts.ps1 -MorningBrief -Voice demo-5
```

### 切换后端

```powershell
# 使用 Edge-TTS（需安装 node-edge-tts）
.\skills\moss-tts\tts.ps1 -Adapter edge -Text "Hello world" -Voice en-US-AriaNeural

# 使用自定义 HTTP API（需配置环境变量）
.\skills\moss-tts\tts.ps1 -Adapter http -Text "测试"
```

## 扩展：添加新 TTS 后端

1. 在 `adapters/` 下创建 `<name>-adapter.ps1`
2. 在文件开头设置 `$adapterType = "<name>"`
3. 实现三个函数：
   - `Test-<Name>Connection`
   - `Get-<Name>Voices`
   - `Invoke-<Name>TTS`
4. 在文件末尾导出别名：
   ```powershell
   function Test-TTSConnection { Test-<Name>Connection }
   function Get-TTSVoices      { Get-<Name>Voices }
   function Invoke-TTS         { param($Text,$Voice,$OutputFile,$ExtraParams) Invoke-<Name>TTS @PSBoundParameters }
   ```

## 输出

- 默认保存到 `output/tts/`（单次合成）或 `output/podcast/`（早间播报）
- WAV 格式，48kHz 采样率
- 文件名自动包含时间戳和文本片段

## 预设音色列表（MOSS-TTS）

| ID | 名称 | 说明 |
|----|------|------|
| demo-1 | 🇨🇳 欢迎关注模思智能 | 中文女声 |
| demo-2 | 🇨🇳 深夜温柔晚安 | 中文温柔女声 |
| demo-3 | 🇨🇳 台湾腔 | 中文台湾腔 |
| demo-4 | 🇨🇳 京味胡同闲聊 | 中文北京腔 |
| demo-5 | 🇨🇳 中国人的时间观念与文化逻辑 | 中文叙述 |
| demo-6 | 🇨🇳 杨幂 - 与自己同行 | 中文明星音色 |
| demo-7~12 | 🇺🇸 英文 | 多种英文音色 |
| demo-13~29 | 🇯🇵🇰🇷🇪🇸🇫🇷🇩🇪 等 | 多语言音色 |

## 后续可扩展

- [ ] 音频拼接（多段 TTS + 背景音乐）
- [ ] 播客双人对话模式
- [ ] 自动定时触发（cron 集成）
- [ ] 推送到手机（Telegram / 微信）
