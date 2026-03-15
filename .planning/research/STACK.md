# Stack Research

**Domain:** Local voice-to-text macOS menubar app (Apple Silicon, Spanish)
**Researched:** 2026-03-15
**Confidence:** MEDIUM-HIGH — Core STT and app framework choices are well-verified; LLM cleanup model selection has some uncertainty around Spanish-specific quality

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Swift / SwiftUI | Swift 5.10+, macOS 14+ | App shell, menubar UI, audio capture, paste simulation | Native macOS APIs for NSStatusItem, AVFoundation, CGEvent. Lowest memory overhead at idle. Required for Input Monitoring + Accessibility permissions flow. Used by AudioWhisper, Whispera, and every production-grade macOS dictation app. |
| WhisperKit | 0.15+ | Speech-to-text transcription engine | Swift-native package, runs Whisper models on Apple Neural Engine via CoreML. No Python dependency for STT. Supports large-v3-turbo on-device. Used by MacWhisper 8. macOS 14+ required. ~2% WER on multilingual streaming benchmarks. |
| mlx-lm | 0.31.0 (March 2026) | LLM runtime for text cleanup post-processing | Best throughput on Apple Silicon: ~230 tok/s on M4-class hardware vs llama.cpp ~150 tok/s. Purpose-built for Metal. Supports Qwen2.5 and thousands of HuggingFace models natively. Python-based; called as subprocess from Swift host. |
| Qwen2.5-3B-Instruct (4-bit) | via mlx-community | Post-processing model: add punctuation, capitalization, remove fillers | 3B at 4-bit fits in ~2GB RAM, achieves ~80-120 tok/s on M1/M2, >200 tok/s on M3/M4. For a 30-60 second transcription (~100-300 words), cleanup completes in <1 second. Qwen2.5 supports Spanish natively (trained on 29+ languages). |
| AVFoundation | macOS system | Microphone audio capture | First-party Apple framework. AVAudioEngine provides real-time buffer access with configurable sample rate. Zero extra dependencies. Standard approach for all macOS recording apps. |
| HotKey | 0.2.1 | Global hotkey registration | Thin Swift wrapper over Carbon EventHotKey APIs (the only non-deprecated way to register system-wide shortcuts on macOS). Used in production by AudioWhisper. Handles Ctrl+Space registration without Input Monitoring permission (Carbon hotkeys are exempt). |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| KeyboardShortcuts (sindresorhus) | latest | User-configurable hotkey UI | Use instead of HotKey if you want a preferences pane with a visual key-recorder widget and SwiftUI integration. Heavier but more polished for user-facing settings. |
| mlx-audio (Blaizzy) | latest | Alternative STT via parakeet-mlx | Use if WhisperKit Spanish quality is unsatisfactory; parakeet-tdt-0.6b-v3 achieves 3.45% WER on Spanish FLEURS. Requires Python runtime bundled with app. |
| parakeet-mlx (senstella) | latest | NVIDIA Parakeet v3 on Apple Silicon | Fallback STT option. 0.4995s transcription vs WhisperKit's 0.1935s (FluidAudio CoreML) but Parakeet v3 has automatic punctuation built-in — may eliminate need for LLM cleanup. |
| ffmpeg | 7.x | Audio format conversion | Required by parakeet-mlx and some mlx-audio workflows. Not needed if using WhisperKit directly (handles raw PCM). Only add if using Python STT path. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Xcode 15+ | Swift development, signing, entitlements | Required for macOS accessibility entitlements. Entitlements needed: `com.apple.security.automation.apple-events`, Input Monitoring if using CGEvent global capture. |
| uv | Python environment management | `uv add mlx-lm mlx-whisper parakeet-mlx` — faster than pip. Use for bundling the Python ML subprocess. |
| py2app | Bundle Python + mlx-lm into .app | Packages the Python cleanup subprocess alongside the Swift app. Alternative: ship a venv inside the .app bundle. |
| Swift Package Manager | Dependency management for Swift | Native to Xcode. Add WhisperKit, HotKey via Package.swift. |

---

## Architecture Pattern

This app uses a **hybrid Swift + Python subprocess** architecture, which is the production-proven pattern used by AudioWhisper:

```
Swift Host (NSStatusItem + SwiftUI)
├── AVFoundation → captures mic → writes WAV to temp file
├── WhisperKit (Swift Package) → transcribes WAV → raw Spanish text
├── Process (Foundation) → spawns mlx-lm Python subprocess
│   └── mlx-lm + Qwen2.5-3B-4bit → cleans text → stdout
└── CGEvent / CGKeyboardKey → simulates Cmd+V to paste
```

The Swift host owns the UI, audio capture, and system integration. The Python subprocess handles the ML workloads that don't have Swift-native equivalents with production quality. Communication is via temp files and stdout pipes.

---

## Installation

```bash
# Swift dependencies (Package.swift)
# .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.15.0")
# .package(url: "https://github.com/soffes/HotKey", from: "0.2.1")

# Python ML environment (bundled with app)
uv init ml-backend
cd ml-backend
uv add mlx-lm  # version 0.31.0
# For Parakeet fallback:
# uv add parakeet-mlx mlx-audio

# Download WhisperKit model (done at first launch via WhisperKit API)
# whisperkit-cli transcribe --download-model openai_whisper-large-v3-turbo

# Download LLM (done at first launch via mlx-lm)
# python -m mlx_lm.download --repo mlx-community/Qwen2.5-3B-Instruct-4bit
```

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| WhisperKit (Swift, CoreML/ANE) | whisper.cpp + CoreML | If you need Python-only stack or want more model format control. whisper.cpp achieves 1.23s vs WhisperKit's ~0.19s on M4 benchmark. WhisperKit is faster and integrates natively into Swift without subprocess. |
| WhisperKit (Swift, CoreML/ANE) | mlx-whisper (Python) | If you've already committed to a Python-only stack. mlx-whisper is 1.02s — slower than WhisperKit and adds Python dependency to the hot path. |
| WhisperKit (Whisper large-v3-turbo) | Parakeet-TDT-0.6b-v3 | If Spanish WER matters more than familiarity. Parakeet v3 achieves 3.45% WER on Spanish FLEURS with built-in punctuation/capitalization. However, requires Python runtime; less battle-tested on macOS. Test both and compare on your own speech. |
| mlx-lm (Python subprocess) | Ollama | If you want a simpler developer experience and don't care about max throughput. Ollama adds ~30-40 MB RAM and a persistent daemon. mlx-lm as subprocess is leaner for short-burst usage. |
| mlx-lm (Python subprocess) | llama.cpp server | If you want the absolute minimum memory footprint at the cost of 30-50% slower inference. Good fallback for M1 8GB machines. |
| Qwen2.5-3B-Instruct-4bit | Qwen2.5-1.5B-Instruct-4bit | If RAM is severely constrained (8GB M1). 1.5B still handles Spanish punctuation and filler removal but with slightly lower coherence. Achieves 30-60 tok/s on M1. |
| Swift / SwiftUI | Tauri (Rust + Web) | If the team is Rust/web developers with no Swift experience. Tauri v2 has a working global-shortcut plugin and macOS permissions plugin. However: macOS accessibility permission re-granting bugs have been reported (GitHub Issue #11085, active as of early 2025), and system integration (CGEvent for paste, AVFoundation) requires bridging to native code anyway. |
| Swift / SwiftUI | Electron | Never for this use case. 200-300 MB idle RAM, 80-120 MB bundle. Defeats the purpose of a lightweight menubar utility. |
| Swift / SwiftUI | Python + rumps | If you want a pure-Python prototype. Rumps is good for quick iterations but cannot access Input Monitoring APIs cleanly and produces non-native UX. Use for spike/prototype only. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| faster-whisper | Does NOT support Metal/MPS acceleration on Apple Silicon — falls back to CPU only. GitHub Issue #515 confirms no Apple GPU support. On M2, it runs slower than whisper.cpp Metal by 3-5x. | WhisperKit or mlx-whisper |
| Nvidia Parakeet-TDT v2 | English-only. v2 does not support Spanish. v3 adds 25 European languages including Spanish but is still immature on Apple Silicon vs Whisper-family models. | Parakeet-TDT v3 if using Parakeet at all, or WhisperKit |
| insanely-fast-whisper | Uses HuggingFace Transformers + MPS which is slower than CoreML on Apple Silicon (1.13s vs 0.19s in M4 benchmark). Large dependency tree. | WhisperKit |
| Electron | 200-300 MB idle RAM. Kills the "lightweight background process" requirement. Bundle size 80-120 MB. | Swift/SwiftUI |
| Ollama (persistent daemon) | Launches a server that stays running, consuming 30-40 MB RAM always. Overkill for short-burst text cleanup. Adds process management complexity. | mlx-lm subprocess (loads on demand, exits after use) |
| PyTorch MPS (via HuggingFace transformers) | Memory constrained on large models. Slower TTFT vs MLX. Heavy dependency. Not purpose-built for Apple Silicon. | mlx-lm |
| Raw Carbon EventHotKey APIs | Verbose, deprecated-adjacent, no Swift wrapper. Hard to make user-configurable. | HotKey or KeyboardShortcuts library |

---

## Stack Patterns by Variant

**If targeting M1 8GB (minimum spec):**
- Use Qwen2.5-1.5B-Instruct-4bit instead of 3B — fits in ~1GB vs ~2GB
- Use WhisperKit with large-v3-turbo (not large-v3 — turbo has 4 decoder layers vs 32, much faster)
- Monitor total RAM: WhisperKit ~1.5GB + Qwen 1.5B-4bit ~1GB = ~2.5GB ML memory

**If targeting M3/M4 (optimal spec):**
- Use Qwen2.5-3B-Instruct-4bit for better Spanish cleanup quality
- Consider keeping Parakeet-TDT v3 as an A/B test option (0.5s vs 0.2s transcription)
- Parakeet built-in punctuation may make LLM cleanup unnecessary — test this

**If WhisperKit Spanish quality is unsatisfactory:**
- Switch STT to parakeet-mlx with mlx-community/parakeet-tdt-0.6b-v3
- Both STT and LLM now run as Python subprocesses — simplifies architecture to pure Python ML backend
- Use mlx-audio as the unified interface: `python -m mlx_audio.stt.generate --model mlx-community/parakeet-tdt-0.6b-v3`

**If user wants zero Python dependency:**
- WhisperKit handles STT natively in Swift
- For LLM cleanup: use mlx-swift (Apple's Swift MLX bindings) with Qwen2.5 — still experimental but Apple-supported
- Alternative: skip LLM cleanup and rely on Parakeet's built-in punctuation + capitalization

---

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| WhisperKit 0.15+ | macOS 14.0+ (Sonoma), Apple Silicon M-series | Does NOT run on Intel Macs. Models require macOS 14 CoreML APIs. |
| mlx-lm 0.31.0 | macOS 14+, Python 3.9+, Apple Silicon | Intel Macs fall back to CPU, much slower. Requires Accelerate framework. |
| HotKey 0.2.1 | macOS 10.15+ | Uses Carbon EventHotKey — officially deprecated but no replacement. Works on all macOS through 15.x. |
| Swift 5.10 / SwiftUI MenuBarExtra | macOS 13+ (Ventura) | MenuBarExtra scene requires macOS 13+. NSStatusItem approach supports macOS 10.14+. Recommend targeting macOS 14+ given WhisperKit requirement. |
| parakeet-mlx (senstella) | macOS 12+, Apple Silicon, requires ffmpeg | v3 multilingual model requires model download at first run (~1.2GB). |
| Qwen2.5-3B-Instruct-4bit | mlx-lm 0.20+, ~2GB unified memory | Available as mlx-community/Qwen2.5-3B-Instruct-4bit on HuggingFace. |

---

## Sources

- [mac-whisper-speedtest benchmark (anvanvan/GitHub)](https://github.com/anvanvan/mac-whisper-speedtest) — M4 MacBook Pro benchmarks: FluidAudio 0.19s, Parakeet MLX 0.50s, mlx-whisper 1.02s, whisper.cpp 1.23s — HIGH confidence
- [WhisperKit GitHub (argmaxinc)](https://github.com/argmaxinc/WhisperKit) — Version 0.15+, macOS 14+ requirement, CoreML/ANE acceleration — HIGH confidence
- [NVIDIA Parakeet-TDT-0.6b-v3 HuggingFace model card](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) — 25-language support including Spanish, WER 3.45% on Spanish FLEURS, NVIDIA GPU only for official model — HIGH confidence
- [mlx-community/parakeet-tdt-0.6b-v3 HuggingFace](https://huggingface.co/mlx-community/parakeet-tdt-0.6b-v3) — MLX port of Parakeet v3 for Apple Silicon — MEDIUM confidence (community port, less battle-tested)
- [mlx-lm GitHub (ml-explore)](https://github.com/ml-explore/mlx-lm) — Version 0.31.0 (March 7, 2026), pip installable, 525 tok/s on M4 Max small models — HIGH confidence
- [Production-Grade Local LLM Inference on Apple Silicon (arXiv:2511.05502)](https://arxiv.org/abs/2511.05502) — MLX highest throughput, llama.cpp lightweight single-stream, Ollama lags in TTFT — HIGH confidence (peer-reviewed paper)
- [AudioWhisper GitHub (mazdak)](https://github.com/mazdak/AudioWhisper) — Reference implementation: Swift + WhisperKit + parakeet-mlx + HotKey + CGEvent paste — HIGH confidence (working production code)
- [HotKey GitHub (soffes)](https://github.com/soffes/HotKey) — v0.2.1, Carbon EventHotKey wrapper, used by AudioWhisper — HIGH confidence
- [faster-whisper Apple Silicon GPU issue #515](https://github.com/SYSTRAN/faster-whisper/discussions/1227) — Confirmed no Metal acceleration — HIGH confidence
- [KeyboardShortcuts GitHub (sindresorhus)](https://github.com/sindresorhus/KeyboardShortcuts) — SwiftUI-compatible configurable shortcut recorder, macOS 10.15+ — HIGH confidence
- [Tauri global shortcut macOS permission bug #11085](https://github.com/tauri-apps/tauri/issues/11085) — Active permission re-granting bug — MEDIUM confidence (open issue, may be fixed)

---

*Stack research for: Local voice-to-text macOS menubar app (my-superwhisper)*
*Researched: 2026-03-15*
