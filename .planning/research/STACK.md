# Stack Research

**Domain:** macOS system-wide media playback pause/resume (v1.1 Pause Playback feature)
**Researched:** 2026-03-16
**Confidence:** HIGH

> **Scope note:** This file covers only the NEW APIs needed for v1.1 Pause Playback.
> The existing validated stack (Swift/SwiftUI, WhisperKit, Haiku API, KeyboardShortcuts,
> CoreAudio, CGEventPost) is unchanged and is not re-researched here.

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| AppKit (NSEvent) | macOS 13+ | Construct system-defined HID media key events | The only public way to synthesize a play/pause media key event at the system level. The `NSEvent.otherEvent(with: .systemDefined, ...)` API with subtype 8 is the established mechanism used by rogue amoeba, BeardedSpice, and dozens of open-source macOS utilities for 15+ years. |
| CoreGraphics (CGEvent) | macOS 13+ | Post the synthesized media key event to the HID tap | Already imported and used in `TextInjector.swift` for Cmd+V simulation (`CGEvent.post(tap: .cgSessionEventTap)`). The media key variant uses `.cghidEventTap` instead. Zero new dependency. |
| IOKit.hidsystem | macOS SDK | Provides `NX_KEYTYPE_PLAY = 16` and related key code constants | Header-only import (`import IOKit.hidsystem`), no linkage change. Defines the stable constant needed to target the play/pause key. |

### Supporting Libraries

None required. All needed APIs exist in frameworks already imported by the project.

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Existing `TextInjector.swift` | Reference implementation for CGEvent posting pattern | The media key posting code is structurally identical to the Cmd+V simulation already in place. |

---

## Installation

No new SPM packages. No new entitlements. No Info.plist additions.

Add to the new `MediaController.swift` file:

```swift
import AppKit       // already in project
import CoreGraphics // already in project (TextInjector.swift)
import IOKit.hidsystem  // NEW — header-only, no link flag needed in Swift
```

In Xcode, `IOKit` is auto-linked when imported via Swift. No `OTHER_LDFLAGS` change needed.

---

## Implementation Pattern

The complete pause/resume toggle is ~20 lines of Swift. The pattern constructs an
`NSEvent` of type `.systemDefined` with subtype 8 (the HID auxiliary key subtype),
encodes `NX_KEYTYPE_PLAY` (= 16) in the upper 16 bits of `data1`, and posts it via
`CGEvent.post`. macOS routes the event to whichever app currently owns the Now Playing
session — Spotify, Apple Music, VLC, Safari/Chrome with HTML5 audio, any compliant app.

```swift
import AppKit
import CoreGraphics
import IOKit.hidsystem

// NX_KEYTYPE_PLAY = 16  (from IOKit/hidsystem/ev_keymap.h)
private let kPlayPauseKey: Int = 16

func postMediaPlayPauseKey() {
    func post(keyDown: Bool) {
        let flags = NSEvent.ModifierFlags(rawValue: keyDown ? 0xa00 : 0xb00)
        let data1 = (kPlayPauseKey << 16) | (keyDown ? 0xa00 : 0xb00)
        guard let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: flags,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        ) else { return }
        event.cgEvent?.post(tap: .cghidEventTap)
    }
    post(keyDown: true)
    post(keyDown: false)
}
```

Call once at recording start (pauses whatever is playing), call again at recording stop
(resumes). Track internal state to avoid spurious resume if nothing was playing at start.

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| HID media key posting (NSEvent + CGEvent) | NSAppleScript per-app | Only if per-app control is a hard requirement AND all target apps support AppleScript (Spotify, Apple Music, VLC do; browsers and most third-party players do not). Requires per-app user approval in System Settings > Privacy > Automation, separate AppleScript per app, fragile to app renames. Far more complexity for narrower coverage. |
| HID media key posting (NSEvent + CGEvent) | MediaRemote private framework | Was viable until macOS 15.4 (2024). Apple restricted it to Apple-signed processes with a private entitlement. Third-party apps receive silent failures. Do not use on modern macOS. |
| HID media key posting (NSEvent + CGEvent) | MPRemoteCommandCenter (MediaPlayer framework) | Controls only YOUR app's own AVPlayer session. It is a command receiver, not a command sender. Solves the wrong problem entirely. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| MediaRemote private framework | Broken for third-party apps since macOS 15.4 (2024). The `mediaremoted` daemon requires an Apple-only entitlement; apps without it are silently denied. Widespread breakage reported across community and GitHub issues. | HID media key event posting |
| MPRemoteCommandCenter / MPNowPlayingInfoCenter | These APIs register YOUR app as a Now Playing participant and let it receive play/pause commands. They do not send commands to other apps. Importing MediaPlayer framework adds unnecessary weight for this use case. | HID media key event posting |
| NSAppleScript per-app scripting | Requires a separate script per app, per-app user approval popups, does not work for browsers or apps without AppleScript dictionaries, and is brittle to app updates. BackgroundMusic uses this approach as a last resort; it is not the primary mechanism. | HID media key event posting |
| Third-party libraries (SPMediaKeyTap, MediaKeyTap, nhurden/MediaKeyTap) | These are event INTERCEPTORS (tap incoming media keys to reroute them), not event SENDERS. They solve the wrong problem — we need to send a pause command, not intercept an existing one. Also: SPMediaKeyTap is Objective-C and unmaintained. | Inline HID posting (~20 lines, no dependency) |

---

## Stack Patterns by Variant

**Pause the system Now Playing app (universal, recommended):**
- Post `NX_KEYTYPE_PLAY` via `CGEvent.post(tap: .cghidEventTap)`
- macOS routes to the active Now Playing session automatically
- Works with Spotify, Apple Music, VLC, browser-based media, podcast apps, etc.
- No knowledge of which app is playing required

**State tracking (avoid double-resume bug):**
- Record whether media was playing when recording started
- On recording start: send pause, set `didPauseMedia = true`
- On recording stop: send resume ONLY IF `didPauseMedia == true`, then reset flag
- Without this, starting recording when nothing is playing would erroneously start playback

**Detecting whether something is currently playing:**
- No clean public API exists post-macOS 15.4 (MediaRemote blocked)
- Pragmatic approach: always send pause on start, always send resume on stop
- If nothing was playing, the toggle event is a no-op in most apps (they ignore play commands when already stopped)
- If this is unacceptable, ship with a Settings toggle (already planned) so users can disable it

---

## Version Compatibility

| API | macOS Support | Notes |
|-----|--------------|-------|
| `NSEvent.otherEvent(with: .systemDefined, ...)` | macOS 10.6+ | Stable API, unchanged across macOS versions through Sequoia (15.x) |
| `CGEvent.post(tap: .cghidEventTap)` | macOS 10.4+ | Same pattern used in TextInjector; works in non-sandboxed Developer ID apps |
| `NX_KEYTYPE_PLAY = 16` | macOS SDK constant | Defined in `IOKit/hidsystem/ev_keymap.h`; value has not changed across macOS versions |
| MediaRemote private framework | Broken as of macOS 15.4 | Do not use — entitlement-gated as of 2024 |

**macOS version target:** The existing project requires macOS 14+ (WhisperKit). The HID media key API works on macOS 13+, so no deployment target change is needed.

**Non-sandboxed requirement:** The existing app is already non-sandboxed (Developer ID distribution) because CGEventPost is used for paste simulation. HID event posting via `.cghidEventTap` has the same non-sandbox requirement — no new entitlement needed since the constraint is already satisfied.

---

## Sources

- [Apple Developer Docs: MPRemoteCommandCenter](https://developer.apple.com/documentation/mediaplayer/mpremotecommandcenter) — confirmed it handles INCOMING commands for own app, not outgoing commands to other apps; HIGH confidence
- [Apple Developer Docs: MPNowPlayingInfoCenter](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter) — confirmed it publishes Now Playing metadata, not for controlling other apps; HIGH confidence
- [Rogue Amoeba: Apple Keyboard Media Key Event Handling (2007)](https://weblog.rogueamoeba.com/2007/09/29/apple-keyboard-media-key-event-handling/) — original reverse-engineering of the NSEvent systemDefined subtype 8 pattern; technique confirmed still in use by major apps; HIGH confidence
- [MediaRemote breakage on macOS 15.4](https://github.com/feedback-assistant/reports/issues/637) — community-tracked breakage confirming entitlement restriction added in macOS 15.4; MEDIUM confidence (GitHub issue, multiple confirming reports)
- [BackgroundMusic source](https://github.com/kyleneideck/BackgroundMusic) — confirmed AppleScript is used for app-specific pause; HID key posting is the system-wide approach; HIGH confidence (open source codebase)
- [Apple Developer Forums: Play/Pause Now Playing with MediaRemote](https://developer.apple.com/forums/thread/688433) — developer discussion confirming MediaRemote route and its limitations; MEDIUM confidence
- Existing `TextInjector.swift` in this codebase — confirms `CGEvent.post(.cgSessionEventTap)` already works without new entitlements; HIGH confidence (production code)

---

*Stack research for: v1.1 Pause Playback feature — macOS system-wide media control*
*Researched: 2026-03-16*
