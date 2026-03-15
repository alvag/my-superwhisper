# Architecture Research

**Domain:** Local voice-to-text macOS menubar app (Apple Silicon)
**Researched:** 2026-03-15
**Confidence:** HIGH (core pipeline patterns), MEDIUM (LLM integration specifics), HIGH (macOS system integration)

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    macOS System Layer                            │
│  ┌─────────────┐  ┌──────────────────┐  ┌───────────────────┐  │
│  │ CGEventTap  │  │  NSStatusItem    │  │  NSPasteboard +   │  │
│  │ (hotkey)    │  │  (menubar icon)  │  │  CGEvent (paste)  │  │
│  └──────┬──────┘  └────────┬─────────┘  └─────────┬─────────┘  │
└─────────┼──────────────────┼───────────────────────┼────────────┘
          │ hotkey events    │ state updates          │ inject text
┌─────────▼──────────────────▼───────────────────────▼────────────┐
│                   App Coordinator (@MainActor)                   │
│            (orchestrates pipeline, owns app state)               │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  AppState: idle | recording | transcribing | cleaning      │  │
│  │            | pasting | error                               │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────┬───────────────────┬────────────────────┬─────────────┘
           │ start/stop        │ pcm buffer          │ raw transcript
┌──────────▼──────┐  ┌────────▼──────────┐  ┌──────▼──────────────┐
│  AudioRecorder  │  │  STT Engine       │  │  LLM Cleaner        │
│  (actor)        │  │  (actor)          │  │  (actor)            │
│                 │  │                   │  │                     │
│ AVAudioEngine   │  │ WhisperKit        │  │ MLX Swift / Ollama  │
│ installTap      │  │ (CoreML/ANE)      │  │ (quantized 3B-7B)   │
│ AVAudioConverter│  │ large-v3-turbo    │  │ keep-warm strategy  │
│ 44kHz→16kHz    │  │ pre-loaded        │  │ system prompt       │
│ Float32         │  │ on @MainActor     │  │ for Spanish cleanup │
└─────────────────┘  └───────────────────┘  └─────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| AppCoordinator | Owns FSM state, orchestrates pipeline stages, handles errors | `@MainActor` class with `@Observable` state |
| HotkeyMonitor | Global event tap for Ctrl+Space, reports press events to Coordinator | `CGEventTap` + `CGEventMask`, requires Accessibility permission |
| MenubarController | Status item icon, popover/menu with state icon, settings access | `NSStatusItem` + `NSHostingView` (SwiftUI) |
| AudioRecorder | Microphone capture, format conversion, buffer accumulation | `AVAudioEngine` + `AVAudioConverter`, actor-isolated |
| STTEngine | Model loading, audio→text transcription, CoreML execution | `WhisperKit` Swift package, pre-loaded at startup |
| LLMCleaner | Prompt construction, LLM inference, response extraction | MLX Swift (`MLXLLM`) or Ollama REST API, keep-warm |
| TextInjector | Save clipboard, write text, simulate Cmd+V, restore clipboard | `NSPasteboard` + `CGEvent` keyboard simulation |

## Recommended Project Structure

```
MyWhisper/
├── App/
│   ├── MyWhisperApp.swift          # @main, NSApplicationDelegate, no dock icon
│   └── AppDelegate.swift           # Setup lifecycle: launch agents, request permissions
│
├── Coordinator/
│   ├── AppCoordinator.swift        # @MainActor FSM, pipeline orchestration
│   └── AppState.swift              # enum: idle | recording | transcribing | cleaning | pasting | error
│
├── Audio/
│   ├── AudioRecorder.swift         # actor: AVAudioEngine capture + format conversion
│   └── AudioBuffer.swift           # Accumulates Float32 PCM chunks until stop
│
├── STT/
│   ├── STTEngine.swift             # actor: WhisperKit wrapper, model lifecycle
│   └── STTConfig.swift             # Model name, language tag, decode options
│
├── LLM/
│   ├── LLMCleaner.swift            # actor: MLX or Ollama inference
│   ├── LLMConfig.swift             # Model name, system prompt, temperature
│   └── Prompts.swift               # System prompt templates for Spanish cleanup
│
├── System/
│   ├── HotkeyMonitor.swift         # CGEventTap global hotkey listener
│   ├── TextInjector.swift          # NSPasteboard save/restore + CGEvent paste
│   └── PermissionsManager.swift    # Accessibility + microphone permission checks
│
├── UI/
│   ├── MenubarController.swift     # NSStatusItem setup and icon state
│   ├── StatusView.swift            # SwiftUI popover: state indicator, last transcript
│   └── SettingsView.swift          # Hotkey config, model selection
│
└── Persistence/
    └── UserSettings.swift          # @AppStorage: hotkey, model, preferences
```

### Structure Rationale

- **Coordinator/:** Single point of orchestration prevents spaghetti calls between Audio/STT/LLM layers. The FSM guards against impossible state transitions (e.g., starting a new recording while still cleaning).
- **Audio/:** Isolated from STT so the recording module can be tested without model dependencies. The buffer accumulates until stop, enabling batch transcription (not streaming).
- **STT/ and LLM/:** Separate actors prevent memory contention. STT and LLM models both consume significant unified memory; keep them in distinct ownership domains.
- **System/:** All macOS API surface area in one place. Accessibility, clipboard, and keyboard simulation are the highest-risk integration points; isolating them simplifies debugging.
- **UI/:** SwiftUI for views, minimal logic. State display only — no business logic here.

## Architectural Patterns

### Pattern 1: Finite State Machine for Pipeline Control

**What:** An explicit enum-based FSM in AppCoordinator guards all state transitions. The coordinator is the only entity that transitions state; all other actors report results and wait.
**When to use:** Any time multiple async operations must run in strict sequence and partial failures need clean recovery.
**Trade-offs:** Slightly more boilerplate than ad-hoc flags; massively easier to debug and extend.

**Example:**
```swift
@MainActor
@Observable
final class AppCoordinator {
    var state: AppState = .idle

    func handleHotkey() async {
        switch state {
        case .idle:
            state = .recording
            await audioRecorder.start()
        case .recording:
            state = .transcribing
            let pcm = await audioRecorder.stop()
            let raw = try await sttEngine.transcribe(pcm)
            state = .cleaning
            let clean = try await llmCleaner.clean(raw)
            state = .pasting
            await textInjector.inject(clean)
            state = .idle
        default:
            break // ignore hotkey during processing
        }
    }
}
```

### Pattern 2: Actor Isolation per Processing Stage

**What:** Each pipeline stage (AudioRecorder, STTEngine, LLMCleaner) is a Swift `actor`. Actors serialize access automatically, preventing data races on shared model state.
**When to use:** Any stage that owns mutable non-thread-safe resources (model weights, audio engine, LLM context).
**Trade-offs:** Requires `await` at every actor boundary; adds async context requirements. Worth it — CoreML and AVAudioEngine are not thread-safe.

**Example:**
```swift
actor STTEngine {
    private var whisperKit: WhisperKit?

    func load() async throws {
        whisperKit = try await WhisperKit(model: "large-v3-turbo")
    }

    func transcribe(_ buffer: [Float]) async throws -> String {
        guard let kit = whisperKit else { throw STTError.notLoaded }
        let result = try await kit.transcribe(audioArray: buffer)
        return result.text
    }
}
```

### Pattern 3: Keep-Warm Model Strategy

**What:** Both STT and LLM models are loaded at app launch and kept resident in unified memory. A menubar app staying in memory indefinitely makes this practical.
**When to use:** Background apps with sub-5-second pipeline requirement. Cold-starting WhisperKit adds ~2-3 seconds; MLX LLM cold start adds ~10-31 seconds.
**Trade-offs:** Uses ~2-6GB unified memory continuously. Acceptable for M1+ with 16GB+; add a user setting to unload models when idle for machines with 8GB.

**Loading sequence at startup:**
```
1. App launches → AppDelegate
2. STTEngine.load()     (~2-3 seconds, CoreML compilation first time)
3. LLMCleaner.load()   (~5-10 seconds for 3B quantized MLX model)
4. Menubar icon appears as "ready"
5. CGEventTap registered → app ready for hotkey
```

### Pattern 4: Clipboard Save/Restore for Text Injection

**What:** Save current clipboard contents before injection, write transcribed text, simulate Cmd+V, then restore original clipboard after a short delay.
**When to use:** The standard pattern for voice-typing apps on macOS. Avoids requiring Accessibility API's `AXUIElement` text insertion (which doesn't work in all apps).
**Trade-offs:** Briefly clobbers the user's clipboard (~300ms window). The Accessibility API insertion approach avoids this but fails in many apps (terminals, games, Electron apps). The save/restore approach has near-universal compatibility.

**Example:**
```swift
final class TextInjector {
    func inject(_ text: String) async {
        let pasteboard = NSPasteboard.general
        // Save
        let saved = pasteboard.string(forType: .string)
        // Write new text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        // Simulate Cmd+V
        postKeyEvent(keyCode: 0x09, flags: .maskCommand, down: true)
        postKeyEvent(keyCode: 0x09, flags: .maskCommand, down: false)
        // Restore after paste completes
        try? await Task.sleep(for: .milliseconds(100))
        pasteboard.clearContents()
        if let saved { pasteboard.setString(saved, forType: .string) }
    }
}
```

## Data Flow

### Primary Pipeline: Hotkey to Pasted Text

```
User presses Ctrl+Space
    ↓
CGEventTap fires → HotkeyMonitor.onHotkey()
    ↓
AppCoordinator.handleHotkey() [main actor]
    ↓ (state: idle → recording)
AudioRecorder.start() [actor]
    ↓
  AVAudioEngine.installTap(onBus: 0, format: 44.1kHz stereo)
    → AVAudioConverter → Float32 PCM @ 16kHz mono
    → Append to internal [Float] accumulation buffer

User presses Ctrl+Space again
    ↓
AppCoordinator.handleHotkey() [main actor]
    ↓ (state: recording → transcribing)
AudioRecorder.stop() → returns [Float] (all accumulated audio)
    ↓
STTEngine.transcribe([Float]) [actor]
    → WhisperKit.transcribe(audioArray:)
    → CoreML model on Neural Engine / GPU
    → Returns raw String (e.g., "eh bueno pues eso es lo que quería decir")
    ↓ (state: transcribing → cleaning)
LLMCleaner.clean(rawText) [actor]
    → Build system prompt + user message
    → MLX Swift inference (quantized 3B model @ ~100 tok/s)
    → Returns cleaned String (e.g., "Bueno, eso es lo que quería decir.")
    ↓ (state: cleaning → pasting)
TextInjector.inject(cleanText)
    → NSPasteboard.setString(cleanText)
    → CGEvent: keyDown(V, .maskCommand) + keyUp
    → Wait 100ms
    → NSPasteboard.setString(previousClipboard)
    ↓ (state: pasting → idle)
MenubarController updates icon to idle
```

### Audio Format Conversion Detail

```
AVAudioEngine input node
    44,100 Hz stereo Float32
         ↓
    AVAudioConverter
         ↓
    16,000 Hz mono Float32
         ↓  (interleaved samples, normalized -1.0..1.0)
    [Float] array buffer
         ↓
    WhisperKit.transcribe(audioArray: [Float])
```

Note: Whisper requires exactly 16kHz mono Float32. AVAudioEngine always captures at the device's native format (typically 44.1kHz or 48kHz). The conversion step is mandatory — attempting to tap at 16kHz directly silently fails.

### State Management

```
AppState (enum, @MainActor)
    .idle        → icon: microphone (gray)
    .recording   → icon: microphone (red, pulsing)
    .transcribing → icon: waveform (yellow)
    .cleaning    → icon: sparkles (yellow)
    .pasting     → icon: checkmark (green, brief)
    .error(msg)  → icon: exclamation (red)

MenubarController observes AppCoordinator via @Observable
    → Updates NSStatusItem.button.image on main thread
    → No explicit Combine/NotificationCenter needed
```

### Key Data Flows

1. **Hotkey event:** CGEventTap callback (background thread) → must dispatch to MainActor; don't call coordinator directly from callback.
2. **Audio buffers:** AVAudioEngine tap fires on audio thread → copy buffer data synchronously, enqueue to actor mailbox, never block the audio thread.
3. **LLM response extraction:** LLM may produce reasoning tokens (`<think>...</think>` for Qwen3); strip everything before the final assistant text before returning.

## Scaling Considerations

This is a single-user local desktop app; traditional scaling doesn't apply. The relevant "scaling" dimension is model size vs. latency vs. memory use:

| Model Scale | STT Choice | LLM Choice | Pipeline Time | RAM Use |
|-------------|-----------|------------|---------------|---------|
| Minimal (8GB Mac) | whisper-base or whisper-small | Qwen3-1.7B 4-bit | ~1-2s | ~1.5GB |
| Recommended (16GB) | whisper-large-v3-turbo | Qwen3-4B 4-bit or Mistral-7B 4-bit | ~2-4s | ~3-5GB |
| High quality (32GB+) | whisper-large-v3 | Qwen3-8B 4-bit | ~3-5s | ~6-8GB |

### Scaling Priorities

1. **First bottleneck:** LLM cold start. A 3B-7B MLX model takes 10-31 seconds to load. Solution: load at app launch, keep warm.
2. **Second bottleneck:** STT first inference. CoreML compiles Metal shaders on first run, adding several seconds. Subsequent runs use cached shaders. Solution: run a silent dummy transcription at startup.

## Anti-Patterns

### Anti-Pattern 1: Calling CoreML / WhisperKit from Main Thread

**What people do:** Call `whisperKit.transcribe()` directly from a button action or CGEventTap callback without async dispatch.
**Why it's wrong:** CoreML inference blocks the thread for seconds. On the main thread this freezes the UI and the menubar icon. On the CGEventTap thread this can crash the system event queue.
**Do this instead:** Wrap all model inference in Swift `actor` methods and always `await` them from an `async` context. Use `Task { await sttEngine.transcribe(...) }` to bridge from synchronous call sites.

### Anti-Pattern 2: Streaming Audio Directly to Whisper

**What people do:** Pipe the raw AVAudioEngine tap buffer directly to Whisper in real time (streaming mode).
**Why it's wrong:** Whisper's encoder processes fixed-length 30-second Mel spectrogram windows. Streaming short chunks causes severe accuracy degradation, especially for Spanish where sentence context matters for punctuation. The project spec explicitly says batch-after-stop.
**Do this instead:** Accumulate all Float32 PCM samples into a buffer during recording. Pass the complete buffer to WhisperKit after stop. This is the "batch transcription" mode and produces significantly better results.

### Anti-Pattern 3: Reloading Models Per Recording

**What people do:** Initialize WhisperKit and the LLM client fresh for each recording to keep memory low.
**Why it's wrong:** WhisperKit load time is 2-3 seconds (plus ~30s first-ever CoreML compilation). MLX LLM load time is 10-31 seconds. The user's 3-5 second pipeline budget is consumed before any audio is processed.
**Do this instead:** Load both models once at app launch. Keep them in memory for the lifetime of the app. Expose a "unload models" setting for low-memory machines.

### Anti-Pattern 4: Blocking the CGEventTap Callback

**What people do:** Perform synchronous work (file I/O, UI updates, model calls) inside the CGEventTap callback.
**Why it's wrong:** The CGEventTap callback runs on a dedicated Carbon event thread. Blocking it delays system-wide keyboard event delivery. macOS will disable the tap if it blocks for too long.
**Do this instead:** The callback should only post a `Task` or signal a continuation. All real work happens on the MainActor or in actor methods:

```swift
// In the CGEventTap callback (C-style closure):
let coordinator = Unmanaged<AppCoordinator>.fromOpaque(refcon!).takeUnretainedValue()
Task { @MainActor in
    await coordinator.handleHotkey()
}
return Unmanaged.passUnretained(event!)
```

### Anti-Pattern 5: Using NSEvent.addGlobalMonitorForEvents Instead of CGEventTap

**What people do:** Use the simpler `NSEvent.addGlobalMonitorForEvents(matching:handler:)` for hotkeys.
**Why it's wrong:** `NSEvent` global monitors cannot intercept or consume the event — they only observe it. This means the hotkey also triggers in the focused app (pressing Ctrl+Space could trigger autocompletion or other shortcuts in IDEs/editors). CGEventTap can consume the event, preventing it from reaching the focused app.
**Do this instead:** Use `CGEventTap` with `CGEventTapLocation.cgSessionEventTap` and return `nil` from the callback to consume (suppress) the hotkey event.

## Integration Points

### External (System) Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| AVAudioEngine | Direct framework import, tap on input node | Requires NSMicrophoneUsageDescription in Info.plist |
| CGEventTap | C API bridged to Swift, requires Accessibility permission | Must call `AXIsProcessTrusted()` at launch and prompt user |
| NSPasteboard | AppKit, direct API | No special permission; but be good citizen and restore contents |
| CGEvent (keyboard) | C API, post synthetic events | Same Accessibility permission as CGEventTap |
| WhisperKit | Swift Package Manager, `argmaxinc/WhisperKit` | Models download from HuggingFace on first use, cached in App Support |
| MLX Swift | Swift Package Manager, `ml-explore/mlx-swift` + `mlx-swift-examples` (MLXLLM) | Python not required; pure Swift + Metal |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| HotkeyMonitor ↔ AppCoordinator | `Task { @MainActor in ... }` dispatch | Never call coordinator synchronously from C callback |
| AudioRecorder ↔ AppCoordinator | `async/await` actor call, returns `[Float]` | Coordinator calls `stop()` which drains and returns buffer |
| STTEngine ↔ AppCoordinator | `async throws` actor method | Throws `STTError` on failure; coordinator catches and sets `.error` state |
| LLMCleaner ↔ AppCoordinator | `async throws` actor method | Returns cleaned `String`; on timeout falls back to raw transcript |
| TextInjector ↔ AppCoordinator | `async` method (not actor, no shared state) | Coordinator `await`s injection completion before returning to idle |
| MenubarController ↔ AppCoordinator | `@Observable` observation, main thread | SwiftUI/AppKit reads `coordinator.state` reactively, no explicit binding |

## Suggested Build Order

Dependencies flow upward — each layer must exist before the one above it:

```
Phase 1: Foundation
  ├── AppCoordinator + AppState FSM (stub methods)
  ├── HotkeyMonitor (CGEventTap, permissions check)
  └── MenubarController (NSStatusItem, state icon)

Phase 2: Audio Pipeline
  ├── AudioRecorder (AVAudioEngine capture)
  └── AudioBuffer + format conversion (44kHz→16kHz Float32)
      [Can test: press hotkey, see recording state, press again, get [Float] array]

Phase 3: STT Integration
  ├── STTEngine (WhisperKit wrapper, model loading)
  └── Integration: AudioRecorder → STTEngine → raw text
      [Can test: full pipeline except LLM and paste]

Phase 4: LLM Integration
  ├── LLMCleaner (MLX Swift or Ollama, keep-warm)
  └── Prompts.swift (Spanish cleanup system prompt)
      [Can test: raw text → cleaned text]

Phase 5: Text Injection
  ├── TextInjector (NSPasteboard + CGEvent)
  └── Integration: full end-to-end pipeline
      [Full E2E: hotkey → speak → stop → clean text appears at cursor]

Phase 6: Polish
  ├── Settings UI (hotkey config, model selection)
  ├── Error handling and recovery
  └── Startup optimization (dummy inference warmup)
```

## Sources

- [WhisperKit — On-device Speech Recognition for Apple Silicon (argmaxinc)](https://github.com/argmaxinc/WhisperKit)
- [WhisperKit on macOS: Integrating On-Device ML in SwiftUI](https://www.helrabelo.dev/blog/whisperkit-on-macos-integrating-on-device-ml)
- [MLX Swift — Swift API for MLX (ml-explore)](https://github.com/ml-explore/mlx-swift)
- [MLX Swift Examples with MLXLLM](https://github.com/ml-explore/mlx-swift-examples)
- [Explore LLMs on Apple Silicon with MLX — WWDC25](https://developer.apple.com/videos/play/wwdc2025/298/)
- [Production-Grade Local LLM Inference: MLX vs Ollama vs llama.cpp (arXiv 2511.05502)](https://arxiv.org/abs/2511.05502)
- [AVFoundation AVAudioNode installTap buffer format for whisper.cpp (ggml-org issue #2008)](https://github.com/ggerganov/whisper.cpp/issues/2008)
- [CGEvent paste simulation — Apple Developer Forums](https://developer.apple.com/forums/thread/659804)
- [NSPasteboard transient type — nspasteboard.org](https://nspasteboard.org/)
- [JustDictate — macOS dictation with Parakeet, clipboard inject architecture](https://github.com/gowtham-ponnana/JustDictate)
- [Building STTInput: Universal Voice-to-Text for macOS](https://yuta-san.medium.com/building-sttinput-universal-voice-to-text-for-macos-080ca40cb9de)
- [Accessibility Permission in macOS (2025)](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html)
- [Whisper Large V3 Turbo — performance benchmarks](https://whispernotes.app/blog/introducing-whisper-large-v3-turbo)

---
*Architecture research for: local voice-to-text macOS menubar app (Apple Silicon)*
*Researched: 2026-03-15*
