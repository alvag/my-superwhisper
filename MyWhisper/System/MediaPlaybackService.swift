import AppKit
import CoreGraphics
import IOKit.hidsystem

final class MediaPlaybackService: MediaPlaybackServiceProtocol {
    private var pausedByApp = false

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "pausePlaybackEnabled")
    }

    func pause() {
        guard isEnabled else { return }
        postMediaKeyToggle()
        pausedByApp = true
    }

    func resume() {
        guard pausedByApp else { return }
        pausedByApp = false
        guard isEnabled else { return }
        postMediaKeyToggle()
    }

    private func postMediaKeyToggle() {
        postKey(down: true)
        postKey(down: false)
    }

    private func postKey(down: Bool) {
        let flags = NSEvent.ModifierFlags(rawValue: down ? 0xA00 : 0xB00)
        let data1 = (Int(NX_KEYTYPE_PLAY) << 16) | (down ? 0xA00 : 0xB00)
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
}
