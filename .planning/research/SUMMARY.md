# Project Research Summary

**Project:** my-superwhisper
**Domain:** Local voice-to-text macOS menubar app (Apple Silicon, Spanish)
**Researched:** 2026-03-15
**Confidence:** HIGH

## Executive Summary

my-superwhisper is a privacy-first macOS menubar dictation app targeting Spanish speakers on Apple Silicon Macs. The well-established pattern for this class of app is a native Swift host (NSStatusItem + SwiftUI) that owns audio capture, system integration, and UI, combined with on-device ML models for speech recognition and text cleanup. The recommended stack is WhisperKit (Swift-native, CoreML/ANE) for STT and MLX Swift (MLXLLM) with Qwen2.5-3B-4bit for post-processing — both running entirely on-device, achieving sub-5-second end-to-end latency for typical 30-60 second dictations. The architecture is a strict sequential pipeline controlled by a Finite State Machine: hotkey press triggers audio capture, stop triggers transcription, raw text feeds the LLM cleaner, and clean text is injected at the cursor via clipboard simulation.

The recommended approach is a 6-phase build following dependency order: foundation (app shell, hotkey, permissions) before audio capture, audio before STT, STT before LLM cleanup, and LLM before text injection. All models must be kept warm in memory — cold-start costs are 2-3 seconds for WhisperKit and 10-31 seconds for MLX LLM, which destroys the user experience if models are loaded per recording. The Spanish-specific differentiator (LLM cleanup of "eh", "este", "o sea", "bueno" fillers with correct punctuation) is achievable with a well-constrained system prompt at temperature=0.

The critical risks are concentrated in Phase 1 (foundation): the default Ctrl+Space hotkey conflicts with macOS Input Source switching — a silent failure specifically for bilingual Spanish/English users (the primary audience). The app cannot be sandboxed because CGEventPost (required for paste simulation) is blocked in sandboxed apps, making Mac App Store distribution impossible. Accessibility and Microphone permissions must be checked on every launch, not just first launch, because macOS resets them after major OS updates. These three decisions must be made before writing any code.

## Key Findings

### Recommended Stack

The app requires a hybrid approach: pure Swift for the macOS system layer (audio capture, hotkey, paste, UI) and Swift-native ML via MLX Swift for on-device inference. WhisperKit (0.15+) runs Whisper large-v3-turbo on the Apple Neural Engine via CoreML, achieving ~0.19s transcription on M4 hardware with no Python dependency. MLX Swift (MLXLLM) runs Qwen2.5-3B-Instruct (4-bit quantized) at 80-230 tok/s depending on chip generation, completing LLM cleanup of a typical 100-300 word transcription in under 1 second when warm. This is a pure Swift stack — no Python subprocess required.

The only reason to deviate from the pure Swift path is if WhisperKit Spanish accuracy proves unsatisfactory, in which case parakeet-mlx (Python subprocess) is the fallback. The Parakeet-TDT-0.6b-v3 model achieves 3.45% WER on Spanish FLEURS and includes built-in punctuation/capitalization, potentially eliminating the need for LLM cleanup entirely — but at the cost of adding a Python runtime dependency.

**Core technologies:**
- Swift / SwiftUI (macOS 14+): App shell, menubar, audio, paste — native macOS APIs required for Accessibility entitlements and zero idle overhead
- WhisperKit 0.15+: STT engine — Swift-native, CoreML/ANE, fastest on-device Whisper implementation (~0.19s M4), no Python
- MLX Swift (MLXLLM) + Qwen2.5-3B-Instruct-4bit: LLM cleanup — pure Swift Metal inference, ~2GB RAM, handles Spanish natively
- AVFoundation: Microphone capture — first-party, zero dependencies, mandatory format conversion 44/48kHz to 16kHz
- HotKey 0.2.1: Global hotkey — thin wrapper over Carbon EventHotKey, Accessibility-permission-exempt, used by production apps

### Expected Features

The competitive landscape (SuperWhisper, Sotto, WhisperFlow, Wispr Flow) establishes a clear feature baseline. Every mature tool offers global hotkey + auto-paste as the core interaction loop, with waveform feedback during recording and LLM-based filler word removal. The key differentiators for this app are 100% local processing (Wispr Flow sends to cloud, only SuperWhisper is local) and Spanish-optimized cleanup (competitors default to English filler word lists).

**Must have (table stakes):**
- Global hotkey (default: non-conflicting, not Ctrl+Space) toggles recording from any app
- Audio capture with waveform animation — users need visual confirmation mic is active
- Local STT transcription optimized for Spanish (WhisperKit large-v3-turbo)
- Local LLM cleanup: punctuation, capitalization, Spanish filler removal ("o sea", "este", "bueno", "pues")
- Auto-paste clean text at cursor via Accessibility API
- Menubar status icon with idle / recording / processing states
- Permission prompts on first launch (Accessibility + Microphone) with clear explanation
- Cancel recording (Escape key) — prevents accidentally pasting garbage
- Configurable hotkey in settings
- Microphone selection in settings

**Should have (competitive):**
- Push-to-talk mode (hold hotkey) — many users prefer this; low complexity to add after toggle works
- Transaction history (last 10 transcriptions) — immediate recovery from accidental dismiss
- Custom vocabulary / correction dictionary — for persistent proper noun misrecognitions
- Granular processing state display (transcribing / cleaning / pasting) — reduces perceived latency
- Lightweight idle resource usage target (<100MB RAM) — users loudly complain when Wispr Flow uses ~800MB

**Defer (v2+):**
- Reformulation modes (formal email, structured notes) — small LLMs produce unreliable output for this
- Multi-language support (Spanish + English) — design architecture for it but ship Spanish-only
- Configurable LLM cleanup aggressiveness (light/full modes)

### Architecture Approach

The app uses a Finite State Machine in an `@MainActor @Observable AppCoordinator` to orchestrate a sequential pipeline of isolated Swift actors: AudioRecorder (AVAudioEngine), STTEngine (WhisperKit), and LLMCleaner (MLX Swift). System integration (hotkey, paste, permissions) lives in a dedicated `System/` layer. The menubar UI observes the coordinator state reactively via `@Observable` — no Combine or NotificationCenter needed. Both models load at app launch and stay resident in unified memory for the app's lifetime.

**Major components:**
1. AppCoordinator (FSM) — single orchestrator; owns state transitions; prevents double-trigger during processing
2. AudioRecorder (actor) — AVAudioEngine tap, mandatory 44/48kHz to 16kHz Float32 resampling, buffer accumulation
3. STTEngine (actor) — WhisperKit wrapper, model pre-loaded at startup, warm-up dummy inference on first launch
4. LLMCleaner (actor) — MLX Swift inference, Qwen2.5-3B-4bit, keep-warm, temperature=0, constrained Spanish prompt
5. TextInjector — NSPasteboard save/restore + CGEvent Cmd+V simulation with 100-200ms delay
6. HotkeyMonitor — CGEventTap (consumes event, not NSEvent monitor), dispatches to MainActor via Task
7. MenubarController — NSStatusItem with reactive state icons (idle/recording/transcribing/cleaning/done/error)

### Critical Pitfalls

1. **Ctrl+Space hotkey conflict** — macOS claims Ctrl+Space for Input Source switching; silently broken for all bilingual Spanish/English users (the primary audience). Use a different default (e.g., Ctrl+Shift+Space). Add conflict detection in settings UI.

2. **CGEventPost blocked in sandboxed apps** — Simulating Cmd+V for paste requires a non-sandboxed app. Mac App Store distribution is impossible with this architecture. Decide distribution model (Developer ID direct download) before writing any paste code.

3. **Accessibility permission lost on every Xcode rebuild** — TCC ties permission to code signature. Sign with a consistent Developer ID certificate from day one. Add `AXIsProcessTrusted()` check on every app launch (not just first launch).

4. **Whisper hallucination on silence/short recordings** — Whisper generates "Subtitles by..." or looping text when given silence or sub-1-second audio. Implement Voice Activity Detection (VAD) gate before STT. Discard recordings with no detected speech.

5. **LLM rewrites meaning instead of just cleaning** — Small LLMs interpret "clean up" liberally and alter meaning. Use maximally constrained system prompt, set temperature=0, add output length sanity check (>20% longer than input = fall back to raw STT).

6. **WhisperKit CoreML cold start** — First CoreML compilation takes 4+ minutes on a fresh install. Run a silent warm-up transcription on app launch with a "Preparing model..." indicator. Keep model resident — never reload per recording.

7. **AVAudioEngine sample rate mismatch** — Built-in mics default to 48kHz; Whisper requires 16kHz. Always query `inputNode.outputFormat(forBus: 0)` — never hardcode. Install AVAudioConverter in the tap path.

## Implications for Roadmap

Based on the combined research, the architecture's dependency chain maps directly to a build order. Each phase produces something testable before the next phase begins.

### Phase 1: Foundation (App Shell, Hotkey, Permissions, Paste)
**Rationale:** All other phases depend on these system integration points. Architecture decisions made here (no sandbox, Developer ID signing, hotkey default) are expensive to change later. The CGEventPost paste mechanism, Accessibility permission infrastructure, and hotkey capture must all be validated before any ML work begins.
**Delivers:** A working menubar app that captures a hotkey from any app, shows state in the menubar, and pastes clipboard content at the cursor. No audio or ML yet.
**Addresses features:** Global hotkey, menubar status icon, auto-paste foundation, configurable hotkey, permission prompts
**Avoids pitfalls:** Ctrl+Space conflict (choose correct default), CGEventPost sandbox decision (non-sandboxed from day one), Accessibility permission on every launch, clipboard race condition (implement 100-200ms paste delay), code signing stability

### Phase 2: Audio Capture Pipeline
**Rationale:** Audio capture with correct format conversion is a prerequisite for STT. The sample rate mismatch pitfall must be caught here via unit tests before Whisper integration — discovering it after STT is wired in makes diagnosis harder. VAD should be implemented here as a first-class component, not retrofitted later.
**Delivers:** Hotkey press starts recording; press again stops; returns a validated 16kHz Float32 buffer. Waveform animation visible during recording. VAD gate implemented.
**Uses:** AVFoundation, AVAudioConverter, silero-vad or WebRTC VAD
**Implements:** AudioRecorder actor, AudioBuffer, waveform UI component
**Avoids pitfalls:** Sample rate mismatch (query hardware format, assert conversion output), Whisper hallucination on silence (VAD gate before STT), audio device switching gaps

### Phase 3: STT Integration
**Rationale:** WhisperKit integration is the highest-complexity ML step. Isolation in its own phase allows accurate latency measurement before LLM is added. CoreML first-load warmup must be implemented here — users will test immediately after adding this phase.
**Delivers:** Full audio-to-text pipeline. Hotkey → speak → stop → raw Spanish text. Transcription latency measured and within budget (<3s for typical recording on target hardware).
**Uses:** WhisperKit 0.15+, Whisper large-v3-turbo model
**Implements:** STTEngine actor, model warm-up on startup, "Preparing model..." loading state
**Avoids pitfalls:** CoreML cold start (warm-up at launch), hallucination on silence (VAD gate already in place from Phase 2), models loaded once and kept warm

### Phase 4: LLM Cleanup Integration
**Rationale:** LLM cleanup is additive to the working STT pipeline. The LLM prompt must be benchmarked against a 20-sentence Spanish test set before wiring into the live pipeline — this is the phase where the "LLM rewrites meaning" pitfall is most likely to surface.
**Delivers:** Raw transcript is cleaned: punctuation added, capitalization corrected, Spanish fillers ("o sea", "este", "bueno", "pues") removed. Output is recognizably what the user said.
**Uses:** MLX Swift (MLXLLM), Qwen2.5-3B-Instruct-4bit, temperature=0
**Implements:** LLMCleaner actor, Prompts.swift (Spanish cleanup system prompt), output length sanity check
**Avoids pitfalls:** LLM meaning rewrite (constrained prompt + length check + benchmark before shipping), LLM cold start (keep-warm strategy at app launch)

### Phase 5: End-to-End Integration and Polish
**Rationale:** With all pipeline components working in isolation, integration focus shifts to robustness, recovery flows, and perceived quality. This phase delivers the minimum shippable product.
**Delivers:** Complete E2E flow: hotkey → record → transcribe → clean → paste at cursor. Error recovery for each failure mode. Cancel recording (Escape). Permission health check UI. Startup optimization.
**Addresses features:** Cancel recording, granular processing state display, permission status screen, error states
**Avoids pitfalls:** macOS permission resets (health check on every launch), no-speech silent failure (VAD-driven "No speech detected" notification), paste in wrong app (post-paste toast for Cmd+Z recovery)

### Phase 6: Settings, Quality, and Distribution
**Rationale:** User-facing settings, quality tuning, and distribution readiness complete the v1 scope. Notarization is required for any user to run the app — this is not optional for distribution.
**Delivers:** Configurable hotkey, microphone selection, model selection UI. Notarized and distributable .app bundle. Startup latency optimized (dummy warmup inference, cached CoreML shaders).
**Addresses features:** Configurable hotkey, microphone selection
**Avoids pitfalls:** Notarization required for distribution (Gatekeeper blocks unnotarized apps on macOS 15+), thermal throttling on MacBook Air (Metal GPU path, not CPU-only)

### Phase Ordering Rationale

- **System integration before ML:** CGEventPost, CGEventTap, and Accessibility permissions have hard architecture constraints (no sandbox) that affect every subsequent phase. These decisions cannot be reversed cheaply.
- **Audio before STT:** WhisperKit requires exactly 16kHz mono Float32. The AVAudioConverter layer must be proven correct before Whisper sees any data — sample rate errors produce garbage transcription with no obvious error signal.
- **STT before LLM:** LLM cleanup is meaningless without accurate STT input. Measuring pure STT latency in isolation informs whether the LLM cleanup budget (typically 0.5-1s warm) is achievable.
- **Both models kept warm from Phase 3+:** Once WhisperKit loads in Phase 3, it must stay resident. Adding LLM in Phase 4 extends the startup sequence; never regress to per-recording model loading.
- **Polish last:** Settings UI, error recovery, and distribution readiness have no upstream blockers and can be done in any order within Phase 5-6.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2 (Audio Capture):** VAD integration specifics — silero-vad vs WebRTC VAD on macOS; Swift bindings availability needs validation before implementation
- **Phase 4 (LLM Cleanup):** Spanish-specific system prompt engineering — no single authoritative source; requires empirical benchmarking with test sentences before finalizing
- **Phase 6 (Distribution):** Developer ID notarization workflow for a non-sandboxed app with Accessibility entitlements — the specific entitlement combination may require validation with Apple's notarization toolchain

Phases with standard patterns (skip research-phase):
- **Phase 1 (Foundation):** CGEventTap, NSStatusItem, NSPasteboard patterns are extremely well-documented; reference implementations (AudioWhisper) available
- **Phase 3 (STT):** WhisperKit integration is well-documented with official examples and a production reference in MacWhisper
- **Phase 5 (Integration):** Error handling and permission UI patterns are standard macOS development

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Core choices (WhisperKit, MLX Swift, HotKey) verified via production reference implementations (AudioWhisper, MacWhisper). Benchmarks from peer-reviewed sources. Spanish support verified via Qwen2.5 multilingual training data. |
| Features | HIGH | Based on official docs and feature pages of 4 direct competitors (SuperWhisper, Sotto, WhisperFlow, Wispr Flow). MVP definition grounded in competitive analysis. |
| Architecture | HIGH | FSM + actor isolation pattern verified via WWDC sessions, Apple Developer docs, and open-source reference implementations. Data flow confirmed against WhisperKit and AVFoundation documentation. |
| Pitfalls | HIGH | Most pitfalls verified via official Apple Developer Forums threads, upstream GitHub issues with linked evidence, and SuperWhisper's own documentation on hallucinations. |

**Overall confidence:** HIGH

### Gaps to Address

- **Spanish LLM prompt quality:** The exact system prompt for Spanish filler word removal and punctuation is not documented anywhere — it must be empirically developed and benchmarked against a test corpus before shipping. Plan for 1-2 prompt iteration cycles in Phase 4.
- **Qwen2.5 vs Qwen3 for cleanup:** ARCHITECTURE.md references Qwen3-4B as an alternative in the scaling table while STACK.md recommends Qwen2.5-3B. Both are supported by mlx-lm. The 3B vs 4B choice for M1 8GB machines should be validated against actual memory pressure during Phase 4.
- **VAD library selection:** No clear winner identified for Swift-native or easily-bridged VAD on macOS. silero-vad requires Python or ONNX runtime; WebRTC VAD has a C library that requires bridging. This should be a day-one decision in Phase 2 to avoid rework.
- **Parakeet as STT fallback:** If WhisperKit Spanish accuracy is unsatisfactory in Phase 3, the fallback (parakeet-mlx via Python subprocess) adds architectural complexity. This risk cannot be eliminated until Phase 3 testing with real Spanish speech samples.

## Sources

### Primary (HIGH confidence)
- [WhisperKit GitHub (argmaxinc)](https://github.com/argmaxinc/WhisperKit) — Version 0.15+, CoreML/ANE, macOS 14+ requirement
- [AudioWhisper GitHub (mazdak)](https://github.com/mazdak/AudioWhisper) — Production reference: Swift + WhisperKit + HotKey + CGEvent paste
- [mlx-lm GitHub (ml-explore)](https://github.com/ml-explore/mlx-lm) — v0.31.0, throughput benchmarks
- [MLX Swift / mlx-swift-examples](https://github.com/ml-explore/mlx-swift-examples) — MLXLLM Swift API
- [Production-Grade Local LLM Inference on Apple Silicon (arXiv:2511.05502)](https://arxiv.org/abs/2511.05502) — Throughput comparisons
- [mac-whisper-speedtest benchmark (anvanvan)](https://github.com/anvanvan/mac-whisper-speedtest) — M4 hardware benchmarks
- [SuperWhisper official docs](https://superwhisper.com/docs/) — UI states, hotkey behavior, hallucination documentation
- [CGEventPost sandboxing (Apple Developer Forums thread 103992)](https://developer.apple.com/forums/thread/103992) — Confirmed blocked in sandbox
- [Whisper hallucination on silence (openai/whisper Discussion #1606)](https://github.com/openai/whisper/discussions/1606) — Confirmed behavior pattern
- [Ctrl+Space input source conflict (Apple Community)](https://discussions.apple.com/thread/8507324) — Confirmed system shortcut conflict
- [Accessibility Permission in macOS 2025 (jano.dev)](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html) — TCC behavior on rebuild

### Secondary (MEDIUM confidence)
- [NVIDIA Parakeet-TDT-0.6b-v3 HuggingFace](https://huggingface.co/mlx-community/parakeet-tdt-0.6b-v3) — MLX port, community-maintained
- [Tauri global shortcut macOS bug #11085](https://github.com/tauri-apps/tauri/issues/11085) — Active permission issue (may be resolved)
- [Sotto official website](https://sotto.to/) — Feature comparison
- [WhisperFlow official website](https://www.whisperflow.de/) — Feature comparison
- [Wispr Flow official website](https://wisprflow.ai/) — Feature comparison, RAM usage

### Tertiary (LOW confidence — validate during implementation)
- Spanish LLM system prompt quality — no documented benchmark exists; empirical testing required
- VAD library Swift compatibility — needs hands-on investigation before Phase 2 starts

---
*Research completed: 2026-03-15*
*Ready for roadmap: yes*
