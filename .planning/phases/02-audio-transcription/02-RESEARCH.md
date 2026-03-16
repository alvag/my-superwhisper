# Phase 2: Audio + Transcription - Research

**Researched:** 2026-03-15
**Domain:** AVFoundation audio capture, WhisperKit STT, energy-based VAD, waveform visualization, macOS notifications
**Confidence:** HIGH (core audio/WhisperKit API), MEDIUM (VAD implementation detail, notification permission behavior)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Waveform: existing 5 bars in OverlayView become reactive to real mic audio levels — taller bars = louder audio, flat during silence. Bars stay red always.
- Overlay size unchanged: 100x48 pts capsule with material blur.
- Update latency ~30-60ms (~16-33 fps) — must feel instantaneous.
- VAD runs post-recording only — analyze full buffer for voice presence after stop hotkey.
- If no speech: do NOT transcribe, do NOT paste. Show macOS native notification: "No se detectó voz".
- On stop: overlay transitions from waveform bars to spinner while transcribing. Overlay disappears when complete and text pasted.
- Menubar icon changes to blue (processing) — established in Phase 1.
- On transcription error: overlay disappears, macOS native notification with error message, return to idle.
- Model: large-v3. Language forced to Spanish (language="es"). No auto-detection.
- WhisperKit model pre-loaded at applicationDidFinishLaunching — no cold-start on first recording (STT-02).
- If user records before model finishes: allow recording, show spinner on stop, wait for model, then transcribe.
- First launch: download model automatically with progress shown in menubar dropdown ("Descargando modelo...").
- Model cached locally after first download.
- Expected RAM: ~1-3GB, transcription time ~3-5s for 30-60s audio on Apple Silicon.
- Audio resampled to 16kHz mono Float32 per AUD-02.
- Phase 2 pastes raw WhisperKit output directly — no cleanup. Raw muletillas and missing punctuation are expected.

### Claude's Discretion
- VAD implementation approach (energy-based threshold, WebRTC VAD, or Silero VAD — researcher decides)
- Audio buffer collection strategy and format conversion pipeline
- Spinner animation style in overlay during processing
- Model download progress UI details
- WhisperKit configuration parameters beyond language and model size
- Error categorization and specific error messages

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| AUD-01 | App captures audio from the default or selected microphone while recording | AVAudioEngine + installTap on inputNode — standard pattern, fully researched |
| AUD-02 | Audio is resampled to 16kHz mono Float32 for STT model input | AVAudioConverter from hardware native rate (48kHz) to 16kHz mono Float32 — mandatory conversion step |
| AUD-03 | Voice Activity Detection (VAD) filters silence before sending to STT to prevent hallucination | Energy-based RMS threshold on accumulated Float32 buffer — recommended approach (see VAD section) |
| STT-01 | Audio is transcribed locally using a speech-to-text model optimized for Spanish on Apple Silicon | WhisperKit large-v3 with DecodingOptions(language: "es") — CoreML/ANE on Apple Silicon |
| STT-02 | STT model is pre-loaded at app launch to avoid cold-start latency | WhisperKit(config:) + prewarmModels() + loadModels() at applicationDidFinishLaunching |
| STT-03 | Transcription completes within reasonable time (<3s for 30-60s of speech on Apple Silicon) | large-v3 ~3-5s on M1/M2/M3 per CONTEXT.md expectations; large-v3-turbo is faster alternative |
| REC-02 | User can press the same hotkey again to stop recording and trigger transcription | AppCoordinator FSM recording→processing transition wired to real STT pipeline |
| REC-03 | User sees an animated waveform visualization while recording is active | OverlayView 5 bars driven by real-time RMS from AVAudioEngine tap on main thread |
</phase_requirements>

---

## Summary

Phase 2 replaces all Phase 1 stubs with a complete audio → VAD → STT pipeline. The three technical domains are: (1) real audio capture with buffer accumulation and format conversion via AVAudioEngine, (2) live waveform visualization by computing RMS from the audio tap and driving bar heights reactively, and (3) WhisperKit integration for model loading, pre-warming, and batch transcription in Spanish.

The critical architectural decision already locked is **batch transcription** (accumulate all audio, transcribe after stop) rather than streaming — this is the correct approach for Whisper and produces significantly better accuracy. VAD runs as a post-recording filter on the accumulated Float32 buffer. The recommendation for VAD (discretionary area) is an **energy-based RMS threshold** computed natively in Swift — no external library required, no C bridging complexity, handles the use case adequately.

The overlay state machine gains a new "spinner" mode that replaces the waveform bars during processing. This requires the OverlayView to accept an explicit mode enum and the OverlayWindowControllerProtocol to expose a way to switch modes, or alternatively for the NSPanel to host a different SwiftUI view during processing.

**Primary recommendation:** Use WhisperKit large-v3, energy-based VAD (RMS threshold on Float32 buffer), AVAudioEngine with AVAudioConverter for 16kHz resampling, and UNUserNotificationCenter (with .provisional authorization) for "No se detectó voz" notifications.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| WhisperKit | 0.15+ | On-device STT via Whisper large-v3 | Swift-native, CoreML/ANE, no Python dependency, used by MacWhisper, macOS 14+ |
| AVFoundation | macOS system | Microphone capture via AVAudioEngine | First-party Apple framework, zero dependencies, real-time buffer access |
| Accelerate (vDSP) | macOS system | RMS calculation for VAD and metering | Hardware-accelerated SIMD, ships with macOS, purpose-built for DSP |
| UserNotifications | macOS system | Native notifications for "No speech", errors | Modern Apple framework, replaces deprecated NSUserNotificationCenter |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| AVAudioConverter | macOS system | Resample hardware rate (48kHz) → 16kHz mono Float32 | Always — hardware native rate never matches Whisper's required 16kHz |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Energy-based VAD (RMS) | WebRTC VAD (reedom/VoiceActivityDetector) | WebRTC VAD is more accurate in noisy environments but requires bridging C code and adds a dependency. Energy-based is sufficient for the "recorded silence only" use case and is pure Swift. |
| Energy-based VAD (RMS) | Silero VAD (ONNX) | Silero requires ONNX Runtime or Python — heavy dependency, adds 50-100MB. Overkill for post-recording batch check. |
| WhisperKit large-v3 | WhisperKit large-v3-turbo | Turbo has 4 decoder layers vs 32 (much faster, less accurate). CONTEXT.md locks us to large-v3 for maximum Spanish accuracy. |

**Installation:**
```bash
# Add to Package.swift dependencies:
# .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.15.0")
# Add to target: .product(name: "WhisperKit", package: "WhisperKit")

# Models download automatically at first launch via WhisperKit.download()
# Cached in: ~/Library/Application Support/huggingface/models/argmaxinc/whisperkit-coreml/
```

---

## Architecture Patterns

### Recommended Project Structure (additions to Phase 1)
```
MyWhisper/
├── Audio/
│   ├── AudioRecorder.swift        # REPLACE stub: real capture + buffer accumulation + RMS publishing
│   └── AudioBuffer.swift          # NEW (optional): typed wrapper for accumulated [Float] samples
├── STT/
│   ├── STTEngine.swift            # NEW: WhisperKit actor wrapper — load, prewarm, transcribe
│   └── STTConfig.swift            # NEW: model name, language, DecodingOptions constants
├── UI/
│   └── OverlayView.swift          # MODIFY: add audioLevel input + spinner mode
├── Coordinator/
│   ├── AppCoordinator.swift       # MODIFY: replace stubs with real pipeline
│   └── AppCoordinatorDependencies.swift  # MODIFY: add STTEngineProtocol
└── App/
    └── AppDelegate.swift           # MODIFY: add model pre-load + download flow
```

### Pattern 1: AVAudioEngine Real Capture with RMS Publishing

**What:** Replace `startStub/stopStub` with real AVAudioEngine capture. The tap callback computes RMS from each buffer chunk and publishes it to a `@Published` or `@Observable` property on AudioRecorder so OverlayView can reactively drive bar heights.

**When to use:** Always for this phase.

**Example:**
```swift
// Source: AVFoundation installTap pattern + Accelerate vDSP_rmsqv
actor AudioRecorder: AudioRecorderProtocol {
    private var audioEngine: AVAudioEngine?
    private var converter: AVAudioConverter?
    private var accumulator: [Float] = []

    // Published via @MainActor property for UI to observe
    nonisolated(unsafe) var audioLevel: Float = 0.0  // 0.0–1.0 normalized RMS

    func start() throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        // CRITICAL: query actual hardware format — never hardcode
        let hardwareFormat = inputNode.outputFormat(forBus: 0)

        // Target format for WhisperKit: 16kHz mono Float32
        let whisperFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!
        converter = AVAudioConverter(from: hardwareFormat, to: whisperFormat)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: hardwareFormat) { [weak self] buffer, _ in
            guard let self else { return }
            // Compute RMS on raw buffer for visualization (fast, before conversion)
            let rms = self.computeRMS(buffer: buffer)
            Task { @MainActor in self.audioLevel = rms }
            // Convert and accumulate for STT
            if let converted = self.convert(buffer: buffer) {
                Task { await self.appendSamples(converted) }
            }
        }
        try engine.start()
        self.audioEngine = engine
    }

    func stop() -> [Float] {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        let result = accumulator
        accumulator = []
        return result
    }

    private func computeRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0] else { return 0 }
        let frameCount = Int(buffer.frameLength)
        var rms: Float = 0
        vDSP_rmsqv(data, 1, &rms, vDSP_Length(frameCount))
        // Normalize: typical speech RMS ~0.01–0.3, cap at 1.0
        return min(rms * 10, 1.0)
    }

    private func appendSamples(_ samples: [Float]) {
        accumulator.append(contentsOf: samples)
    }
}
```

### Pattern 2: OverlayView Mode Switching (Waveform ↔ Spinner)

**What:** OverlayView gains an explicit `mode` enum. OverlayWindowController passes the mode, or the coordinator updates a shared observable. When processing starts, the view switches from animated bars to a SwiftUI `ProgressView()` (indeterminate spinner).

**When to use:** When AppCoordinator transitions from .recording → .processing.

**Example:**
```swift
enum OverlayMode {
    case recording(audioLevel: Float)  // 5 bars driven by level
    case processing                     // spinner
}

struct OverlayView: View {
    var mode: OverlayMode = .recording(audioLevel: 0)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 12, y: 4)

            switch mode {
            case .recording(let level):
                AudioBarsView(level: level)
            case .processing:
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
                    .tint(.blue)
            }
        }
        .frame(width: 100, height: 48)
    }
}
```

### Pattern 3: STTEngine Actor with Model Lifecycle

**What:** An `actor STTEngine` owns WhisperKit. It pre-loads at launch (download if needed, prewarm, load). During processing it transcribes the [Float] buffer. The model stays resident for the app lifetime.

**When to use:** Exclusively — never reload per recording (4-25s cold start cost).

**Example:**
```swift
// Source: WhisperKit GitHub + helrabelo.dev blog
actor STTEngine {
    private var whisperKit: WhisperKit?
    private var isLoading = false
    private var loadTask: Task<Void, Error>?

    // Called at app launch — download + prewarm + load
    func prepareModel() async throws {
        guard whisperKit == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        // Download model if not cached (first launch only)
        let modelFolder = try await WhisperKit.download(
            variant: "openai_whisper-large-v3",
            from: "argmaxinc/whisperkit-coreml",
            progressCallback: { progress in
                // Notify AppDelegate/MenubarController of progress
                NotificationCenter.default.post(
                    name: .whisperKitDownloadProgress,
                    object: progress.fractionCompleted
                )
            }
        )

        let config = WhisperKitConfig(
            model: "openai_whisper-large-v3",
            modelFolder: modelFolder,
            computeOptions: .init(audioEncoderCompute: .cpuAndNeuralEngine)
        )
        whisperKit = try await WhisperKit(config)
        try await whisperKit?.prewarmModels()
        try await whisperKit?.loadModels()
    }

    func transcribe(_ audioArray: [Float]) async throws -> String {
        // Wait for model if still loading
        if whisperKit == nil { try await prepareModel() }
        guard let kit = whisperKit else { throw STTError.notLoaded }

        let options = DecodingOptions(
            language: "es",           // Force Spanish — no auto-detection
            temperature: 0.0,
            temperatureFallbackCount: 3,
            sampleLength: 224,
            noSpeechThreshold: 0.6   // Suppress when model itself sees no speech
        )

        let results = try await kit.transcribe(audioArray: audioArray, decodeOptions: options)
        return results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    var isReady: Bool { whisperKit != nil }
}
```

### Pattern 4: Energy-Based VAD on Accumulated Buffer

**What:** After `audioRecorder.stop()` returns the [Float] buffer, compute its overall RMS. If below a threshold, no speech was recorded. Return early without calling STT.

**When to use:** Always, before every transcription call.

**Example:**
```swift
// Source: vDSP_rmsqv (Accelerate framework) — pure Swift, no external dependencies
import Accelerate

func hasSpeech(in samples: [Float], threshold: Float = 0.01) -> Bool {
    guard !samples.isEmpty else { return false }
    var rms: Float = 0
    vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
    return rms >= threshold
}

// Usage in AppCoordinator:
let buffer = await audioRecorder.stop()
guard hasSpeech(in: buffer) else {
    // No speech: notify user, return to idle
    showNotification(title: "No se detectó voz")
    transitionTo(.idle)
    return
}
// Speech detected: proceed to transcription
```

**Threshold selection:** 0.01 RMS corresponds to approximately -40 dBFS. Typical speech from a Mac built-in mic at normal speaking distance is 0.02–0.15 RMS. Background room tone / HVAC is typically 0.003–0.008. Use 0.01 as the default; expose as a tunable constant.

### Pattern 5: macOS Notifications for Silent/Error Cases

**What:** UNUserNotificationCenter delivers native macOS banners. The `.provisional` authorization option avoids requiring an explicit user permission dialog for notification delivery.

**When to use:** For "No se detectó voz" and "Error de transcripción" (per locked decision).

**Example:**
```swift
// Source: UNUserNotificationCenter Apple Developer Documentation
import UserNotifications

func requestNotificationPermission() {
    UNUserNotificationCenter.current().requestAuthorization(
        options: [.alert, .sound, .provisional]
    ) { granted, _ in
        // .provisional delivers silently to Notification Center without banner
        // until user explicitly keeps or turns off — no blocking prompt
    }
}

func showNotification(title: String, body: String = "") {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = nil  // Silent — no sound for VAD/error notifications

    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil  // Deliver immediately
    )
    UNUserNotificationCenter.current().add(request)
}
```

### Anti-Patterns to Avoid

- **Hardcoding 16kHz in installTap format:** Hardware native rate is 48kHz on modern Macs. Requesting 16kHz directly silently fails or produces garbage audio. Always query `inputNode.outputFormat(forBus: 0)` first and use AVAudioConverter.
- **Streaming chunks to WhisperKit:** WhisperKit transcribes fixed-length 30-second Mel windows. Feeding short chunks degrades accuracy severely. Always batch the full recording.
- **Calling WhisperKit.transcribe() on main thread:** CoreML inference blocks for 3-5 seconds. Must be in an actor or `Task { }` — never on MainActor during transcription.
- **Reloading WhisperKit per recording:** 4-25s cold start per use. Load once at launch, keep resident.
- **Blocking CGEventTap callback with any work:** The tap fires on a Carbon event thread. Only dispatch a `Task { }` from the callback — zero other work.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Sample rate conversion (48kHz → 16kHz) | Manual interpolation | `AVAudioConverter` | Format negotiation, edge cases (mono/stereo, float types), dithering |
| Whisper model management | Custom CoreML loader | `WhisperKit` | CoreML compilation, ANE scheduling, model caching, threading |
| RMS calculation | Manual sqrt(sum/n) loop | `vDSP_rmsqv` from Accelerate | Hardware-accelerated SIMD, 10-100x faster, correct numerical handling |
| macOS notification delivery | Custom NSPanel toast | `UNUserNotificationCenter` | System integration, Do Not Disturb respect, notification center history |
| Whisper model download | HuggingFace HTTP client | `WhisperKit.download()` | Progress callback, cache validation, model variant resolution |

**Key insight:** The entire STT pipeline (download, cache, prewarm, transcribe) is handled by WhisperKit. The only custom code needed is: (1) the AVAudioConverter pipeline, (2) the energy-based VAD threshold, and (3) wiring them into the AppCoordinator FSM.

---

## Common Pitfalls

### Pitfall 1: AVAudioEngine Sample Rate Mismatch (CRITICAL)
**What goes wrong:** AVAudioEngine's inputNode defaults to hardware native rate (48kHz on most modern Macs). Installing a tap with a requested format of 16kHz silently fails or produces corrupted audio. WhisperKit receives garbage and produces garbage transcription.
**Why it happens:** Documentation implies you can specify any format in installTap — you cannot. The format must match the hardware format.
**How to avoid:** Always call `inputNode.outputFormat(forBus: 0)` to get the actual hardware format. Install the tap with the HARDWARE format. Use a separate `AVAudioConverter` to convert each buffer chunk to 16kHz mono Float32 before accumulating.
**Warning signs:** Transcription of clear speech produces incoherent output. Audio playback of recorded buffer sounds wrong speed.

### Pitfall 2: WhisperKit Hallucination on Silence (CRITICAL)
**What goes wrong:** If a silent or near-silent recording reaches WhisperKit, it generates fabricated text ("Subtitles by...", "Thanks for watching", looping repetitions). This gets pasted into the user's document.
**Why it happens:** Whisper's training data included subtitles where silence = credits text. The model learned this association.
**How to avoid:** Run energy-based VAD (RMS threshold check) on the accumulated buffer BEFORE calling `sttEngine.transcribe()`. If RMS < 0.01, skip transcription entirely and show "No se detectó voz" notification.
**Warning signs:** Silent test recordings produce text output.

### Pitfall 3: WhisperKit CoreML First-Load Latency (STT-02)
**What goes wrong:** First-ever CoreML compilation of the large-v3 model takes 4+ minutes on first app launch. User presses hotkey immediately and nothing happens.
**Why it happens:** Apple's Neural Engine requires device-specific compilation of CoreML models. Cannot be pre-compiled and shipped.
**How to avoid:** Call `prewarmModels()` + `loadModels()` in `applicationDidFinishLaunching` in a background Task. Show "Descargando/preparando modelo..." in the menubar dropdown. The locked decision says: if user records before load finishes, allow recording, then show spinner after stop and wait for load to complete before transcribing.
**Warning signs:** 4-minute hang on first ever launch with no feedback.

### Pitfall 4: Audio Thread Safety
**What goes wrong:** The AVAudioEngine tap callback fires on a real-time audio thread. Any blocking, allocation, or actor calls that wait will cause audio glitches or system-level audio stalls. If AppCoordinator is mutated directly from the tap callback, data races occur.
**Why it happens:** AVAudioEngine's tap callback is not the main thread and not an actor context.
**How to avoid:** In the tap callback: compute RMS immediately (stack allocation only, no heap), then dispatch `Task { @MainActor in self.audioLevel = rms }` for UI and `Task { await self.appendSamples(converted) }` for buffer accumulation. Zero blocking operations in the callback itself.
**Warning signs:** Audio crackling or stuttering during recording. Xcode Sanitizer data race warnings.

### Pitfall 5: OverlayView Loses Reference to AudioRecorder Level
**What goes wrong:** The overlay NSPanel hosts a SwiftUI view, but the view needs real-time audio level updates. If the AudioRecorder is an actor, bridging its non-isolated `audioLevel` to the SwiftUI view requires careful @Observable or @MainActor bridging.
**Why it happens:** Actors and @Observable don't automatically bridge across thread contexts for UI.
**How to avoid:** Declare `audioLevel` as a `@MainActor`-isolated `@Published` or `@Observable` var on a separate `@Observable` class (e.g., `AudioLevelMonitor: @MainActor, @Observable`), updated by the actor via `Task { @MainActor in monitor.level = rms }`. OverlayView observes this class.
**Warning signs:** Bars stay flat despite active recording. Compiler errors about main-actor isolation.

### Pitfall 6: UNUserNotificationCenter Requires Request Before First Use
**What goes wrong:** Notifications silently fail to appear if `requestAuthorization()` was never called.
**Why it happens:** macOS requires explicit authorization even for provisional notifications.
**How to avoid:** Call `UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .provisional])` once at app launch in `applicationDidFinishLaunching`. The `.provisional` flag means the user sees notifications in Notification Center without a blocking permission dialog.
**Warning signs:** `showNotification()` called but nothing appears.

---

## Code Examples

Verified patterns from official sources:

### WhisperKit: Initialization with Specific Model
```swift
// Source: WhisperKit GitHub README + transloadit.com/devtips/transcribe-audio-on-ios-macos-whisperkit/
let config = WhisperKitConfig(
    model: "openai_whisper-large-v3",
    modelRepo: "argmaxinc/whisperkit-coreml",
    computeOptions: .init(audioEncoderCompute: .cpuAndNeuralEngine)
)
let whisperKit = try await WhisperKit(config)
```

### WhisperKit: Model Download with Progress
```swift
// Source: WhisperKit GitHub source + helrabelo.dev blog
let modelFolder = try await WhisperKit.download(
    variant: "openai_whisper-large-v3",
    from: "argmaxinc/whisperkit-coreml",
    progressCallback: { progress in
        DispatchQueue.main.async {
            self.downloadProgress = Float(progress.fractionCompleted)
        }
    }
)
```

### WhisperKit: Transcribe with DecodingOptions (Spanish forced)
```swift
// Source: helrabelo.dev/blog/whisperkit-on-macos-integrating-on-device-ml
let options = DecodingOptions(
    language: "es",
    temperature: 0.0,
    temperatureFallbackCount: 3,
    sampleLength: 224,
    noSpeechThreshold: 0.6
)
let results = try await whisperKit.transcribe(audioArray: audioSamples, decodeOptions: options)
let text = results.map { $0.text }.joined(separator: " ")
```

### AVAudioConverter: Hardware Rate to 16kHz Mono Float32
```swift
// Source: AVFoundation installTap pitfall — Phase 1 research PITFALLS.md
let hardwareFormat = inputNode.outputFormat(forBus: 0)  // e.g. 48kHz stereo
let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                  sampleRate: 16000, channels: 1, interleaved: false)!
let converter = AVAudioConverter(from: hardwareFormat, to: targetFormat)!

func convert(buffer: AVAudioPCMBuffer) -> [Float]? {
    let ratio = targetFormat.sampleRate / hardwareFormat.sampleRate
    let outFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
    guard let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat,
                                           frameCapacity: outFrameCount) else { return nil }
    var error: NSError?
    converter.convert(to: outBuffer, error: &error) { _, status in
        status.pointee = .haveData
        return buffer
    }
    guard error == nil, let data = outBuffer.floatChannelData?[0] else { return nil }
    return Array(UnsafeBufferPointer(start: data, count: Int(outBuffer.frameLength)))
}
```

### RMS Computation for VAD (Accelerate)
```swift
// Source: Accelerate vDSP framework — Apple developer documentation
import Accelerate

func computeRMS(samples: [Float]) -> Float {
    guard !samples.isEmpty else { return 0 }
    var rms: Float = 0
    vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
    return rms
}

// VAD gate
func hasSpeech(in samples: [Float], threshold: Float = 0.01) -> Bool {
    computeRMS(samples: samples) >= threshold
}
```

### AppCoordinator: Updated Pipeline (recording → processing)
```swift
// Source: Phase 1 AppCoordinator.swift — updated pattern for Phase 2
case .recording:
    escapeMonitor?.stopMonitoring()
    let buffer = await audioRecorder.stop()

    // VAD gate — silence check
    guard hasSpeech(in: buffer) else {
        overlayController?.hide()
        showNotification(title: "No se detectó voz")
        transitionTo(.idle)
        return
    }

    // Switch overlay from waveform to spinner
    overlayController?.showProcessing()
    transitionTo(.processing)

    do {
        let text = try await sttEngine.transcribe(buffer)
        overlayController?.hide()
        await textInjector?.inject(text)
        transitionTo(.idle)
    } catch {
        overlayController?.hide()
        showNotification(title: "Error de transcripción", body: error.localizedDescription)
        transitionTo(.idle)
    }
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| whisper.cpp Metal backend | WhisperKit CoreML/ANE | 2023+ (WhisperKit v0.1+) | Faster inference on Apple Silicon, pure Swift |
| NSUserNotificationCenter | UNUserNotificationCenter | macOS 10.14 (deprecated) | Modern framework, macOS 15+ compatible |
| NSEvent.addGlobalMonitorForEvents | CGEventTap (already done Phase 1) | Always | Event consumption capability |
| installTap with requested 16kHz format | installTap with hardware format + AVAudioConverter | Always correct | Prevents silent format failure |

**Deprecated/outdated:**
- `NSUserNotificationCenter`: Deprecated macOS 11+. Use `UserNotifications` framework.
- `whisperKit.prewarmModels()` alone: Must follow with `loadModels()` for model to be ready.
- Tap format = requested output format: Hardware-format tap + explicit converter is the correct pattern.

---

## Open Questions

1. **Large-v3 model size on first download**
   - What we know: large-v3 CoreML model is ~3GB download from HuggingFace
   - What's unclear: Exact download time on typical broadband; whether WhisperKit.download() is resumable after interruption
   - Recommendation: Show clear "Descargando modelo..." progress in menubar. Trust WhisperKit's built-in caching. First launch UX is a known one-time cost.

2. **`noSpeechThreshold` vs. energy VAD — overlap**
   - What we know: DecodingOptions has `noSpeechThreshold` parameter that suppresses output when the model's own silence probability exceeds it
   - What's unclear: Is it sufficient without a pre-transcription RMS check? The locked decision requires RMS VAD before transcription.
   - Recommendation: Use both. Pre-transcription RMS VAD (fast, avoids wasting 3-5s on silence) AND `noSpeechThreshold: 0.6` in DecodingOptions (secondary safety net for hallucination suppression).

3. **OverlayWindowController mode switching**
   - What we know: Phase 1 uses a single static OverlayView, hides/shows the panel
   - What's unclear: Whether to update the panel's existing view (update mode enum) or swap the NSHostingView contentView
   - Recommendation: Add a `showProcessing()` method to OverlayWindowControllerProtocol that replaces the panel's NSHostingView rootView with a processing-mode view. Simpler than passing state through the panel.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (already configured in MyWhisperTests target) |
| Config file | MyWhisper.xcodeproj (test target: MyWhisperTests) |
| Quick run command | `xcodebuild test -scheme MyWhisper -destination 'platform=macOS' -only-testing:MyWhisperTests/AudioRecorderTests` |
| Full suite command | `xcodebuild test -scheme MyWhisper -destination 'platform=macOS'` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AUD-01 | AudioRecorder starts AVAudioEngine and captures real audio | unit (mic required) | `xcodebuild test ... -only-testing:MyWhisperTests/AudioRecorderTests/testStartCaptures` | ❌ Wave 0 |
| AUD-02 | Captured buffer is 16kHz mono Float32 after conversion | unit | `xcodebuild test ... -only-testing:MyWhisperTests/AudioRecorderTests/testBufferFormat` | ❌ Wave 0 |
| AUD-03 | VAD returns false for silent buffer, true for speech-level RMS | unit | `xcodebuild test ... -only-testing:MyWhisperTests/VADTests/testSilenceDetection` | ❌ Wave 0 |
| STT-01 | STTEngine.transcribe() returns non-empty string for known audio | integration (manual) | Manual test — requires model download | manual-only |
| STT-02 | STTEngine.isReady after prepareModel() completes | unit (mock) | `xcodebuild test ... -only-testing:MyWhisperTests/STTEngineTests/testModelLoads` | ❌ Wave 0 |
| STT-03 | Transcription time <5s for 30s buffer on target hardware | performance (manual) | Manual timing test with stopwatch | manual-only |
| REC-02 | AppCoordinator transitions recording→processing when hotkey pressed in recording state | unit | `xcodebuild test ... -only-testing:MyWhisperTests/AppCoordinatorTests/testHotkeyStopsRecordingAndTranscribes` | ❌ Wave 0 (existing testHotkeyStopsRecordingAndReturnsIdle needs update) |
| REC-03 | OverlayView renders bars at varying heights based on audioLevel input | unit (SwiftUI preview) | `xcodebuild test ... -only-testing:MyWhisperTests/OverlayViewTests/testBarsHeightChanges` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme MyWhisper -destination 'platform=macOS' -only-testing:MyWhisperTests/AudioRecorderTests -only-testing:MyWhisperTests/VADTests -only-testing:MyWhisperTests/AppCoordinatorTests`
- **Per wave merge:** `xcodebuild test -scheme MyWhisper -destination 'platform=macOS'`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `MyWhisperTests/AudioRecorderTests.swift` — update/extend to cover AUD-01, AUD-02 (real capture tests require mic hardware; mock-based buffer format test is viable)
- [ ] `MyWhisperTests/VADTests.swift` — NEW: covers AUD-03 with pure Float32 array tests (no hardware needed)
- [ ] `MyWhisperTests/STTEngineTests.swift` — NEW: covers STT-02 with mock WhisperKit dependency (protocol injection)
- [ ] `MyWhisperTests/OverlayViewTests.swift` — NEW: covers REC-03 (SwiftUI view unit test for bar heights)
- [ ] `MyWhisper/Coordinator/AppCoordinatorDependencies.swift` — add `STTEngineProtocol` for injection
- [ ] Note: xcodebuild license must be accepted (`sudo xcodebuild -license accept`) before any build/test — existing blocker from STATE.md

---

## Sources

### Primary (HIGH confidence)
- [WhisperKit GitHub (argmaxinc)](https://github.com/argmaxinc/WhisperKit) — version, installation, API shape (download, transcribe, prewarm, loadModels)
- [WhisperKit on macOS: Integrating On-Device ML — helrabelo.dev](https://www.helrabelo.dev/blog/whisperkit-on-macos-integrating-on-device-ml) — DecodingOptions with language, actor pattern, transcription flow
- [Phase 1 PITFALLS.md](.planning/research/PITFALLS.md) — AVAudioEngine sample rate, hallucination on silence, CoreML cold start (HIGH — project research)
- [Phase 1 ARCHITECTURE.md](.planning/research/ARCHITECTURE.md) — Actor isolation pattern, buffer accumulation, data flow (HIGH — project research)
- [Apple Developer: AVAudioNode.installTap](https://developer.apple.com/documentation/avfaudio/avaudionode/1387122-installtap) — tap callback behavior, bufferSize advisory
- [Apple Developer: UNUserNotificationCenter](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter) — provisional authorization, macOS 14+ behavior
- [Accelerate vDSP](https://developer.apple.com/documentation/accelerate/vdsp) — vDSP_rmsqv function for RMS computation

### Secondary (MEDIUM confidence)
- [WhisperKit Issue #171 — prewarmModels()](https://github.com/argmaxinc/WhisperKit/issues/171) — prewarm + loadModels() sequence confirmed
- [WhisperKit.download() progressCallback](https://github.com/argmaxinc/WhisperKit) — progress.fractionCompleted pattern (verified in source reference, not directly fetched)
- [Creating a Live Audio Waveform in SwiftUI — createwithswift.com](https://www.createwithswift.com/creating-a-live-audio-waveform-in-swiftui/) — AVAudioEngine tap → @Observable pattern for SwiftUI reactivity
- [Voice Activity Detection pitfalls — picovoice.ai](https://picovoice.ai/blog/complete-guide-voice-activity-detection-vad/) — energy-based VAD thresholds for typical speech vs silence environments

### Tertiary (LOW confidence — needs validation during implementation)
- AVAudioConverter block-based convert API exact parameter types — search results confirm pattern but exact Swift closure signature needs compiler verification
- `noSpeechThreshold` default value in WhisperKit DecodingOptions — confirmed name from search, exact default value unverified (use 0.6 as starting point from Whisper paper)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — WhisperKit and AVFoundation are the only viable choices, confirmed by Phase 1 research and current project
- Architecture: HIGH — patterns from Phase 1 research validated against existing code structure, actor/FSM patterns are established
- VAD approach: MEDIUM — energy-based RMS is the correct recommendation but threshold tuning (0.01) is empirical; will need adjustment during implementation with real recordings
- Pitfalls: HIGH — AVAudioEngine sample rate and WhisperKit hallucination pitfalls are well-documented and verified in Phase 1 research

**Research date:** 2026-03-15
**Valid until:** 2026-04-15 (WhisperKit is actively developed; check for API changes before implementation if more than 2 weeks pass)
