import AppKit
import AVFoundation
import ApplicationServices

// MARK: - Types

enum PermissionReason: Equatable {
    case accessibility
    case microphone
}

enum PermissionStatus: Equatable {
    case ok
    case blocked(reason: PermissionReason)
}

// MARK: - Dependencies (injectable for testing)

protocol PermissionsChecking {
    var isAccessibilityTrusted: Bool { get }
    var microphoneAuthorizationStatus: AVAuthorizationStatus { get }
}

struct SystemPermissionsChecker: PermissionsChecking {
    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }
    var microphoneAuthorizationStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }
}

// MARK: - PermissionsManaging Protocol

protocol PermissionsManaging: AnyObject {
    func requestMicrophone() async -> Bool
}

// MARK: - Manager

final class PermissionsManager {
    private let checker: PermissionsChecking
    private static let accessibilityWasGrantedKey = "permissions.accessibility.wasGranted"
    private static let microphoneWasGrantedKey = "permissions.microphone.wasGranted"

    init(checker: PermissionsChecking = SystemPermissionsChecker()) {
        self.checker = checker
        // Track when permissions are first granted so we can detect revocations
        if checker.isAccessibilityTrusted {
            UserDefaults.standard.set(true, forKey: Self.accessibilityWasGrantedKey)
        }
        if checker.microphoneAuthorizationStatus == .authorized {
            UserDefaults.standard.set(true, forKey: Self.microphoneWasGrantedKey)
        }
    }

    // Called from applicationDidFinishLaunching — only blocks if a PREVIOUSLY GRANTED
    // permission was revoked (e.g., after OS update). Fresh installs are handled on-the-fly.
    func checkAllOnLaunch() -> PermissionStatus {
        let accessibilityWasGranted = UserDefaults.standard.bool(forKey: Self.accessibilityWasGrantedKey)
        if accessibilityWasGranted && !checker.isAccessibilityTrusted {
            return .blocked(reason: .accessibility)
        }
        let micWasGranted = UserDefaults.standard.bool(forKey: Self.microphoneWasGrantedKey)
        let micStatus = checker.microphoneAuthorizationStatus
        if micWasGranted && (micStatus == .denied || micStatus == .restricted) {
            return .blocked(reason: .microphone)
        }
        return .ok
    }

    // Called on first recording start (on-the-fly)
    // Returns true immediately if already authorized — no TCC dialog on subsequent calls
    func requestMicrophone() async -> Bool {
        let status = checker.microphoneAuthorizationStatus
        switch status {
        case .authorized:
            UserDefaults.standard.set(true, forKey: Self.microphoneWasGrantedKey)
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if granted {
                UserDefaults.standard.set(true, forKey: Self.microphoneWasGrantedKey)
            }
            return granted
        default:
            return false // denied or restricted — show blocking screen
        }
    }

    // Called on first paste attempt (on-the-fly)
    // Returns true if already trusted; prompts user via system dialog if not
    func requestAccessibility() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        let trusted = AXIsProcessTrustedWithOptions(options)
        if trusted {
            UserDefaults.standard.set(true, forKey: Self.accessibilityWasGrantedKey)
        }
        return trusted
    }

    func openSystemSettingsForAccessibility() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func openSystemSettingsForMicrophone() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }
}

// MARK: - PermissionsManaging Conformance

extension PermissionsManager: PermissionsManaging {}
