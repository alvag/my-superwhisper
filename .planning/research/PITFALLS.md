# Pitfalls Research

**Domain:** Local voice-to-text macOS menubar app (Apple Silicon, Spanish, local STT + LLM)
**Researched:** 2026-03-15
**Confidence:** HIGH (most pitfalls verified via official docs, Apple Developer Forums, and upstream GitHub issues)

---

## Critical Pitfalls

### Pitfall 1: Ctrl+Space is a macOS System Hotkey for Input Source Switching

**What goes wrong:**
The default global hotkey (Ctrl+Space) is already claimed by macOS as the "Select the previous input source" shortcut for keyboard/input method switching. On any Mac with multiple input sources configured (including Spanish + English layouts), the app's hotkey silently does nothing, or worse, toggles the keyboard layout and also triggers recording. The user has no idea why the app seems unresponsive.

**Why it happens:**
Developers test on a single-language machine. The conflict only manifests when the user has more than one keyboard input source configured in System Settings — extremely common for bilingual Spanish/English users who are the primary target audience.

**How to avoid:**
- Default to a different hotkey (e.g., Ctrl+Shift+Space or Cmd+Shift+R) that does not conflict with macOS system shortcuts.
- On first launch, scan for conflicts using `NSWorkspace` or by checking system keyboard shortcut prefs.
- In Settings UI, show a clear warning when the selected hotkey matches a known macOS system shortcut.
- Document in onboarding that the user must disable the conflicting macOS shortcut in System Settings > Keyboard > Keyboard Shortcuts > Input Sources if they want Ctrl+Space.

**Warning signs:**
- Hotkey works on dev machine but users report it doing nothing.
- Keyboard layout toggles when pressing the hotkey.
- Only fails for users with Spanish+English input sources.

**Phase to address:**
Phase 1 (hotkey capture foundation). Choose the default hotkey carefully and add conflict detection before shipping.

---

### Pitfall 2: CGEventPost is Blocked in Sandboxed Apps

**What goes wrong:**
Simulating Cmd+V via `CGEventPost` to paste transcribed text into the frontmost application requires the app to be **not** sandboxed. In a sandboxed app, `CGEventPost` silently fails — the paste never happens. Apple's documentation states: "Posting keyboard or mouse events using CGEventPost offers a way to circumvent sandbox restrictions, and is therefore not allowed from a sandboxed app."

**Why it happens:**
Developers build and test without sandboxing enabled (the default for Xcode CLI/Swift Package Manager targets). They only hit the wall when trying to distribute via the Mac App Store or when hardened runtime is enabled with sandbox entitlement.

**How to avoid:**
- Decide distribution model early: **Mac App Store** (requires sandboxing — CGEventPost unusable) vs. **Direct download with Developer ID** (can disable sandbox — CGEventPost works).
- For direct distribution: keep the sandbox entitlement disabled, require Accessibility permission for CGEventPost, and use the `com.apple.security.automation.apple-events` entitlement for AppleScript fallback.
- For the clipboard approach: write text to `NSPasteboard`, simulate Cmd+V via CGEventPost (non-sandboxed), wait 100-200ms for the target app to process it, then restore the original clipboard content.
- Never submit this app to the Mac App Store without redesigning the paste mechanism.

**Warning signs:**
- Paste works during development but fails after enabling the App Sandbox entitlement.
- `CGEventPost` calls return without error but no text appears.
- The app works on the dev machine but not on others who have not granted Accessibility access.

**Phase to address:**
Phase 1 (macOS integration foundation). Architecture decision: non-sandboxed distribution only. Document this constraint in the project.

---

### Pitfall 3: Accessibility Permission Lost on Every Xcode Rebuild

**What goes wrong:**
macOS TCC (Transparency, Consent, and Control) ties Accessibility permission to the app's code signature. Every time you build from Xcode into a new DerivedData location, the binary's identity changes and macOS revokes the previously granted Accessibility permission. The app silently loses its global hotkey and paste simulation abilities mid-development.

**Why it happens:**
The app binary changes path or code signature on rebuild. TCC considers it a different app. The permission prompt may not re-appear (the old entry remains but no longer matches).

**How to avoid:**
- Sign the app with a consistent Developer ID certificate from the start of development — even locally. This stabilizes the code signature identity.
- Set a fixed build output path in Xcode instead of using DerivedData.
- Add a permission health check on startup: call `AXIsProcessTrusted()` and show a clear UI prompt if it returns false, directing the user to System Settings > Privacy & Security > Accessibility.
- In the Accessibility list, the user must remove and re-add the app after each unsigned rebuild.

**Warning signs:**
- Global hotkey stops working after a rebuild.
- `AXIsProcessTrusted()` returns `false` unexpectedly.
- The app appears in the Accessibility list but the toggle is off or the entry is stale.

**Phase to address:**
Phase 1. Set up proper code signing from day one, not as an afterthought.

---

### Pitfall 4: Whisper Hallucination on Silence and Non-Speech Audio

**What goes wrong:**
When Whisper receives audio containing silence, background noise, or very short clips (under ~1 second), it generates fabricated text instead of returning empty output. Common hallucinated outputs include "Subtitles by..." "Thanks for watching!" "Transcribed by..." or looping repetitions of the last recognized phrase. This corrupts the user's document with nonsense text.

**Why it happens:**
Whisper's training data included subtitle files where silence at the end was annotated with credits text. The model learned to generate these patterns when no speech is detected. The autoregressive decoder uses previous tokens to predict next tokens, so once hallucination starts it can snowball into long repeated loops.

**How to avoid:**
- Implement a Voice Activity Detection (VAD) gate before sending audio to Whisper. Use `WebRTC VAD` or `silero-vad` to verify speech is present.
- If the recording is shorter than 1 second or the VAD confidence is below a threshold, discard it and show the user a "No speech detected" message.
- Trim leading and trailing silence from the audio buffer before transcription — silence at the boundaries is the primary hallucination trigger.
- Set `no_speech_threshold` parameter in whisper.cpp (or equivalent) to suppress outputs when the model's own no-speech probability is high.
- Use macOS Sonoma 14+ for whisper.cpp — older macOS versions experience increased hallucination rates with CoreML builds.

**Warning signs:**
- Short recordings produce random text like "Subtitles by..." or "You" repeatedly.
- Output length is disproportionate to recording length.
- Same phrase appears multiple times in the output.
- Transcription of silence produces any output at all.

**Phase to address:**
Phase 2 (STT integration). VAD must be implemented before any user testing, not added later as a fix.

---

### Pitfall 5: Whisper CoreML First-Load Latency (ANE Compilation)

**What goes wrong:**
When whisper.cpp is configured to use CoreML/ANE (Apple Neural Engine), the first run compiles the model to a device-specific format via `ANECompilerService`. This compilation takes **4+ minutes** on first launch and ~25 seconds on each subsequent cold start. A user who launches the app and presses the hotkey immediately gets a hang with no feedback.

**Why it happens:**
Apple's ANE requires device-specific compilation of CoreML models that cannot be pre-compiled and shipped. The developer tests with a warmed cache; users always hit the cold start.

**How to avoid:**
- Perform a background warm-up transcription on app launch (e.g., transcribe 500ms of silence) with a loading indicator.
- Keep the model loaded in memory for the app's lifetime — do not unload it when idle.
- Show a "Preparing model..." state on first launch with a progress indicator; block the hotkey until warm-up completes.
- Consider whether ANE/CoreML benefit justifies the cold start cost: GPU via Metal (`ggml` Metal backend) has more predictable load times and is the recommended primary path for whisper.cpp on Apple Silicon.
- If using CoreML: cache the compiled model in the user's Application Support directory and verify the cache exists before the first transcription.

**Warning signs:**
- App appears frozen for 4+ minutes on first launch after install.
- Subsequent launches are fast but first-ever launch is extremely slow.
- No spinner or progress feedback leaves the user believing the app crashed.

**Phase to address:**
Phase 2 (STT integration). Implement warm-up before any end-to-end testing.

---

### Pitfall 6: Local LLM Rewrites Text Meaning Instead of Just Cleaning It

**What goes wrong:**
A 3B-7B parameter LLM used for "filler word removal and punctuation" starts rewriting sentences, changing verb tense, adding information not spoken, dropping key phrases, or "correcting" technical terms, proper nouns, and domain-specific vocabulary. The user dictates one thing; a different thing appears on screen. This is a trust-destroying failure mode.

**Why it happens:**
Small LLMs do not reliably follow constrained instructions. When instructed to "clean up" text, they interpret this liberally. The smaller the model, the more it hallucinates additions or paraphrases rather than making minimal edits. Prompt brittleness means small wording changes in the system prompt produce dramatically different behavior.

**How to avoid:**
- Write the system prompt to be maximally constrained: "Do NOT change any words except to remove filler words. Do NOT add information. Do NOT rephrase sentences. Only add punctuation."
- Include negative examples in the few-shot prompt showing what NOT to do.
- Test with a benchmark of 20 Spanish sentences across different topics and verify output fidelity before shipping.
- Set `temperature=0` (or as low as the runtime allows) to minimize creative rewriting.
- Consider skipping the LLM for short transcriptions (under 10 words) — punctuation errors are minor; meaning changes are catastrophic.
- Add an output length sanity check: if the LLM output is more than 20% longer than the input, something went wrong — fall back to the raw STT output.

**Warning signs:**
- Output contains words or phrases not present in the input.
- Technical terms, names, or URLs are "corrected" to something else.
- Output is noticeably longer than input without justification.
- Verb tenses or personal pronouns change between input and output.

**Phase to address:**
Phase 3 (LLM cleanup integration). Benchmark before wiring into the full pipeline.

---

### Pitfall 7: macOS Permission Resets After Major OS Updates

**What goes wrong:**
After upgrading to a new major macOS version (e.g., Sonoma to Sequoia), previously granted Microphone and Accessibility permissions are revoked for third-party apps. The app silently stops recording or the hotkey stops working. The user assumes the app is broken rather than that permissions need re-granting.

**Why it happens:**
macOS TCC database is reset or migrated during major OS upgrades. Apple also changed permission re-confirmation intervals in Sequoia (screen recording was changed to require re-confirmation monthly/weekly before being adjusted in 15.1).

**How to avoid:**
- Implement permission health checks on every app launch, not just on first run.
- Show a persistent menubar indicator change (e.g., a warning icon) when any required permission is missing.
- In the "Not Working?" help flow, the first troubleshooting step is always "Check permissions in System Settings."
- Write a permission status screen accessible from the menubar that shows green/red for Microphone and Accessibility.

**Warning signs:**
- App stops working after a macOS update.
- `AVCaptureDevice.authorizationStatus(for: .audio)` returns `.denied` or `.notDetermined` after previously working.
- `AXIsProcessTrusted()` returns `false` without any user action.

**Phase to address:**
Phase 1. Build the permission checking and user-facing status indicators as core infrastructure, not a post-launch fix.

---

### Pitfall 8: AVAudioEngine Sample Rate Mismatch

**What goes wrong:**
AVAudioEngine's input node defaults to the hardware device's native sample rate. Built-in mics on modern Macs default to 48kHz, not 44.1kHz. Whisper expects 16kHz input. If the app requests 16kHz from AVAudioEngine without proper resampling, the engine either throws an error or silently records at the wrong rate. Audio sent to Whisper at 48kHz instead of 16kHz sounds 3x faster to the model, producing garbage transcription.

**Why it happens:**
Documentation is inconsistent about what sample rate the input node reports. Developers assume 44.1kHz is the default, or assume AVAudioEngine handles resampling automatically, neither of which is true.

**How to avoid:**
- Always query `inputNode.outputFormat(forBus: 0)` to get the actual hardware sample rate — never hardcode it.
- Install an `AVAudioConverter` between the input tap and the buffer feeding Whisper to resample to exactly 16000 Hz.
- Test explicitly with an external USB microphone (which may report a different sample rate than built-in hardware).
- When `installTap(onBus:bufferSize:format:block:)` returns a buffer, verify `AVAudioPCMBuffer.format.sampleRate` before processing.

**Warning signs:**
- Transcription quality is very poor even for simple phrases.
- Audio playback of the raw captured buffer sounds wrong (too fast or too slow).
- `AVAudioEngine.start()` throws an error mentioning format incompatibility.
- Buffer sizes are inconsistent run to run.

**Phase to address:**
Phase 2 (audio capture foundation). Write a sample rate verification test before integrating STT.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcode sample rate to 44100 Hz | Simpler code | Breaks on modern mics (48kHz default), external audio interfaces, USB headsets | Never — always query the hardware |
| Load STT model on each transcription call | Avoids managing lifetime | 4-25s cold start per use, app feels broken | Never — load once and keep resident |
| Skip VAD, send all audio to Whisper | Simpler pipeline | Hallucination on silence, corrupted output | Only acceptable in automated test harness |
| Use App Sandbox | Easier App Store distribution | CGEventPost is completely blocked; paste mechanism must be fully redesigned | Never for this app's architecture |
| Skip notarization for distribution | Saves $99/year Developer Program fee | Users cannot open the app on macOS 15+ without disabling Gatekeeper, "app is damaged" error | Never — always notarize for distribution |
| Hardcode system prompt without testing | Faster initial build | LLM rewrites meaning; discovered only by users | Never — benchmark the LLM prompt before shipping |
| Allow Ctrl+Space as default hotkey | Familiar to Superwhisper users | Conflicts with macOS Input Source switching; silently broken for Spanish+English users | Never — choose a non-conflicting default |
| Single permission check at first launch | Simpler code | Permissions reset after OS updates go undetected | Never — check on every launch |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| AVAudioEngine + Whisper | Assume `installTap` uses requested buffer size | `bufferSize` parameter is advisory; actual size varies. Process whatever size the tap delivers. |
| whisper.cpp CoreML | Enable CoreML/ANE for maximum speed | GPU via Metal is more predictable. ANE has 4-minute cold compile on first use. Benchmark both before choosing. |
| CGEventPost paste | Simulate Cmd+V immediately after writing to clipboard | Add a 100-200ms delay between `NSPasteboard.clearContents()`/`setString()` and posting the Cmd+V event — clipboard write is asynchronous to the target app. |
| Ollama / llama.cpp LLM | Use default concurrency settings | Set `OLLAMA_NUM_PARALLEL=1` to prevent thread contention on Apple Silicon GPU. |
| macOS Accessibility API | Check permission once on first launch | Call `AXIsProcessTrusted()` on every launch. TCC state can change at any time (OS updates, user manually revokes). |
| Audio device switching | Assume input device is constant | Register for `AVAudioSession.routeChangeNotification` / Core Audio property listeners. Device changes (e.g., AirPods connect) cause audio gaps and format changes. |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Loading Whisper model on each transcription | 4-25s delay before every transcription | Load on app start, keep in memory | Every use, immediately |
| Loading LLM model on each cleanup call | 2-10s additional delay per use | Keep Ollama server running in background, pre-load model with a warmup call | Every use |
| Running STT + LLM sequentially without overlap | Total latency = STT time + LLM time | STT is the bottleneck; LLM cleanup adds < 1s for a warmed model. Accept sequential for simplicity. | Acceptable at target scale |
| MacBook Air thermal throttling | CPU collapses to 800 MHz mid-inference; latency spikes 3-10x | Use Metal GPU path (not CPU-only); schedule inference in bursts not continuous | On fanless devices (Air M1-M4) under sustained load |
| Whisper large-v3 on 8GB RAM Mac | Unified memory exhausted; swap kills performance | Use whisper medium or distil-large-v3; test on minimum-spec target hardware | Any Mac with 8GB RAM running large model |
| Clipboard race condition on paste | Old clipboard content pasted instead of transcription | Write to clipboard, wait 150ms, simulate Cmd+V, wait 200ms, restore original clipboard | Fast typists or apps with slow clipboard handlers |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Requesting Accessibility permission without explanation | User denies out of fear, app silently broken | Show a pre-permission explanation screen: "This is needed to capture your global hotkey and paste text." |
| Storing transcription logs unencrypted | Private dictations readable by any app | Store activity log in Application Support with restricted file permissions (0600). Do not log full transcription text by default — log only timestamps and word counts. |
| Running Ollama server on default port 11434 without binding restriction | Any local process or web page can send requests to the LLM | Acceptable for local-only app, but document it. Consider binding to 127.0.0.1 and adding a per-request token if the attack surface is a concern. |
| Using `NSTemporaryDirectory()` for audio buffers | Other apps can read mic audio from /tmp | Write temp audio files to a subdirectory under `NSApplicationSupportDirectory` with restricted permissions, or use in-memory buffers exclusively. |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No visual feedback during processing | User presses hotkey again, starts second recording while first is processing | Menubar icon must show 3 distinct states: idle, recording, processing. Disable hotkey re-trigger during processing or show an error beep. |
| Paste appears with no warning in wrong app | Text pasted in password field, search bar, or terminal command | This is extremely hard to prevent (we cannot know what's focused). Mitigate by showing a brief "Pasted X words" toast notification so the user can immediately Cmd+Z if wrong. |
| No speech detected — silent failure | User thinks app worked but nothing was pasted | Show a notification: "No speech detected." Do not paste silence-induced hallucinations. |
| LLM cleaned text significantly different | User cannot trust the output | Provide an "Undo cleanup" option or show raw transcription in the activity log for reference. |
| Permission denied on first run — no recovery UI | App appears to do nothing | Permission check screen must be the first thing shown, with a direct "Open System Settings" button. |

---

## "Looks Done But Isn't" Checklist

- [ ] **Audio capture:** Tested with an external USB microphone (different sample rate than built-in) — verify sample rate conversion works
- [ ] **STT model:** Tested with silence-only recording — verify VAD blocks it and no hallucination is pasted
- [ ] **STT model:** Tested with a 45-second dictation — verify no repetition loops in output
- [ ] **LLM cleanup:** Verified output with a 20-sentence benchmark — verify no meaning changes, no additions
- [ ] **Hotkey:** Tested on a machine with both Spanish and English input sources — verify no conflict with Ctrl+Space input switching
- [ ] **Paste:** Tested in TextEdit, VS Code, Terminal, browser address bar, password field — verify paste works in all except password field (expected failure)
- [ ] **Permissions:** Revoked Accessibility and Microphone permissions and relaunched — verify clear user guidance appears
- [ ] **Permissions:** Tested after simulating OS update (manually revoke TCC in System Settings) — verify permission health check detects it
- [ ] **Distribution:** Tested by downloading from a web server and double-clicking — verify Gatekeeper does not block it (notarization required)
- [ ] **Cold start:** Unloaded model from memory and triggered transcription — verify warm-up happens before first real transcription
- [ ] **Thermal:** Ran 10 consecutive transcriptions on a MacBook Air — verify latency doesn't degrade due to throttling
- [ ] **Spanish accent:** Tested with recordings using Latin American regional accents — verify Whisper large-v3 handles them acceptably

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Ctrl+Space conflict shipped as default | LOW | Ship a settings update changing the default hotkey; show a one-time migration dialog |
| CGEventPost blocked (sandboxed by mistake) | HIGH | Requires removing sandbox entitlement, re-signing, re-notarizing, re-distributing. Plan distribution model before writing any paste code. |
| Hallucination shipped without VAD | MEDIUM | Add VAD gate in a patch release. Users who already have corrupted documents cannot be helped retroactively. |
| LLM prompt rewrites meaning | MEDIUM | Ship a patch with a tightened prompt. Add a "disable LLM cleanup" toggle as immediate mitigation. |
| CoreML cold start blocking app | LOW | Ship a warm-up background task; or switch to Metal GPU backend (no cold start issue). |
| Accessibility permission lost after OS update | LOW | Ship a permission health check if not already present. Users can re-grant manually. |
| Sample rate mismatch in production | MEDIUM | Root-cause requires audio pipeline rework. Add a sample-rate verification assertion in debug builds to catch early. |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Ctrl+Space system hotkey conflict | Phase 1: Hotkey foundation | Test on machine with Spanish + English input sources; hotkey does not toggle layout |
| CGEventPost blocked in sandbox | Phase 1: Architecture decision | Confirm sandbox is disabled in entitlements; paste works in TextEdit |
| Accessibility permission lost on rebuild | Phase 1: Code signing setup | Rebuild app twice; hotkey still works without re-granting permissions |
| macOS permission resets after OS update | Phase 1: Permission infrastructure | Manually revoke in System Settings; app shows permission warning on next launch |
| AVAudioEngine sample rate mismatch | Phase 2: Audio capture | Unit test: capture 2s audio, verify buffer sample rate = 16000 Hz after conversion |
| Audio device switch gaps | Phase 2: Audio capture | Connect/disconnect AirPods during recording; recording does not crash or corrupt |
| Whisper hallucination on silence | Phase 2: STT integration | Record silence, send to Whisper; verify output is empty or "No speech detected" |
| Whisper CoreML cold start latency | Phase 2: STT integration | First transcription after app launch completes under 5s (warm-up done at startup) |
| LLM rewrites meaning | Phase 3: LLM cleanup integration | Run 20-sentence benchmark; 0 meaning changes, 0 hallucinated additions |
| Thermal throttling on MacBook Air | Phase 2/3: Pipeline testing | Run 10 consecutive transcriptions; latency stays within 2x of first transcription |
| Clipboard race condition | Phase 1: Paste mechanism | Rapid successive paste simulations; verify correct text always pasted |
| Notarization required for distribution | Phase 4: Distribution | Download from URL and double-click; Gatekeeper does not block it |

---

## Sources

- [Handling audio capture gaps on macOS — Nonstrict (2024)](https://nonstrict.eu/blog/2024/handling-audio-capture-gaps-on-macos/)
- [AVAudioEngine sample rate mismatch — Apple Developer Forums](https://developer.apple.com/forums/thread/680785)
- [Accessibility Permission in macOS — jano.dev (2025)](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html)
- [CGEvent to simulate paste — Apple Developer Forums](https://developer.apple.com/forums/thread/659804)
- [Accessibility permission in sandboxed app — Apple Developer Forums](https://developer.apple.com/forums/thread/707680)
- [CGEventPost doesn't work in sandboxed app — Apple Developer Forums](https://developer.apple.com/forums/thread/103992)
- [Whisper hallucination on silence — openai/whisper Discussion #1606](https://github.com/openai/whisper/discussions/1606)
- [Whisper hallucination — possible solution Discussion #679](https://github.com/openai/whisper/discussions/679)
- [Large Model hallucination and repeating — whisper.cpp Discussion #1490](https://github.com/ggml-org/whisper.cpp/discussions/1490)
- [Hallucinations & Unexpected Results — Superwhisper official docs](https://superwhisper.com/docs/common-issues/hallucinations)
- [CoreML first-run compilation delay — whisper.cpp Issue #2126](https://github.com/ggml-org/whisper.cpp/issues/2126)
- [Apple Neural Engine for LLM Inference — InsiderLLM](https://insiderllm.com/guides/apple-neural-engine-llm-inference/)
- [How to run local LLM without thermal throttling — Alibaba Insights](https://www.alibaba.com/product-insights/how-to-run-a-local-llm-on-a-refurbished-macbook-air-m1-without-thermal-throttling-or-battery-panic.html)
- [Building a macOS app to detect thermal throttling — Stan's blog (2025)](https://stanislas.blog/2025/12/macos-thermal-throttling-app/)
- [App Permissions on macOS Sequoia — TrozWare (2024)](https://troz.net/post/2024/sequoia_app_permissions/)
- [Notarizing macOS software — Apple Developer Documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Whisper Spanish code-switching not supported — openai/whisper Discussion #49](https://github.com/openai/whisper/discussions/49)
- [Ctrl+Space conflict with input source switching — Apple Community](https://discussions.apple.com/thread/8507324)
- [Real-Time Speech-to-Text with MLX Whisper — maeda.pm (2024)](https://maeda.pm/2024/11/10/real-time-speech-to-text-on-macos-with-mlx-whisper-with-copy-to-pasteboard-capabilities/)
- [Quantization for Whisper Models analysis — arXiv 2025](https://arxiv.org/html/2503.09905v1)

---
*Pitfalls research for: Local voice-to-text macOS menubar app (Apple Silicon, Spanish)*
*Researched: 2026-03-15*
