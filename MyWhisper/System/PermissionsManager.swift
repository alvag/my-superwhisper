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

    init(checker: PermissionsChecking = SystemPermissionsChecker()) {
        self.checker = checker
    }

    // Called from applicationDidFinishLaunching — checks previously granted permissions
    func checkAllOnLaunch() -> PermissionStatus {
        if !checker.isAccessibilityTrusted {
            return .blocked(reason: .accessibility)
        }
        let micStatus = checker.microphoneAuthorizationStatus
        if micStatus == .denied || micStatus == .restricted {
            return .blocked(reason: .microphone)
        }
        return .ok
    }

    // Called on first recording start (on-the-fly)
    func requestMicrophone() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized: return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false // denied or restricted — show blocking screen
        }
    }

    // Called on first paste attempt (on-the-fly)
    // Returns true if already trusted; false if user must enable in System Settings
    func requestAccessibility() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        return AXIsProcessTrustedWithOptions(options)
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
