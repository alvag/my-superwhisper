import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator!
    private var menubarController: MenubarController!
    private var hotkeyMonitor: HotkeyMonitor!
    private var escapeMonitor: EscapeMonitor!
    private var statusMenuController: StatusMenuController!
    private var permissionsManager: PermissionsManager?
    private var permissionWindow: NSWindow?
    private var audioRecorder: AudioRecorder?
    private var textInjector: TextInjector?
    private var overlayController: OverlayWindowController?
    private var sttEngine: STTEngine?
    private var haikuCleanup: HaikuCleanupService?
    private var apiKeyWindowController: APIKeyWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Initialize core components FIRST — menubar must always be visible
        coordinator = AppCoordinator()
        menubarController = MenubarController()
        escapeMonitor = EscapeMonitor(coordinator: coordinator)

        let permissionsManager = PermissionsManager()
        self.permissionsManager = permissionsManager

        // Create remaining dependencies
        let audioRecorder = AudioRecorder()
        let textInjector = TextInjector(permissionsManager: permissionsManager)
        let overlayController = OverlayWindowController()
        let sttEngine = STTEngine()
        let haikuCleanup = HaikuCleanupService()
        let apiKeyWindowController = APIKeyWindowController(haikuCleanup: haikuCleanup)

        // Wire coordinator dependencies
        coordinator.menubarController = menubarController
        coordinator.escapeMonitor = escapeMonitor
        coordinator.audioRecorder = audioRecorder
        coordinator.textInjector = textInjector
        coordinator.overlayController = overlayController
        coordinator.permissionsManager = permissionsManager
        coordinator.sttEngine = sttEngine
        coordinator.haikuCleanup = haikuCleanup
        coordinator.apiKeyWindowController = apiKeyWindowController

        // Store strong references
        self.audioRecorder = audioRecorder
        self.textInjector = textInjector
        self.overlayController = overlayController
        self.sttEngine = sttEngine
        self.haikuCleanup = haikuCleanup
        self.apiKeyWindowController = apiKeyWindowController

        // Build and attach menu
        statusMenuController = StatusMenuController(coordinator: coordinator, haikuCleanup: haikuCleanup)
        menubarController.setMenu(statusMenuController.buildMenu())

        // Request provisional notification authorization (silent, no dialog)
        NotificationHelper.requestAuthorization()

        // Register hotkey last (after coordinator is fully wired)
        hotkeyMonitor = HotkeyMonitor(coordinator: coordinator)

        // Permission health check — runs on every launch (TCC can revoke after OS updates)
        // Menubar is already visible so user can see the app and quit if needed
        let permissionStatus = permissionsManager.checkAllOnLaunch()
        if case .blocked(let reason) = permissionStatus {
            showPermissionBlockedWindow(reason: reason, permissionsManager: permissionsManager)
        }

        // Pre-load STT model (STT-02) -- background task, non-blocking
        Task {
            do {
                try await sttEngine.prepareModel()
            } catch {
                print("[AppDelegate] STT model pre-load failed: \(error)")
                // Non-fatal -- model will load on first transcription attempt
            }
        }
    }

    private func showPermissionBlockedWindow(reason: PermissionReason, permissionsManager: PermissionsManager) {
        let view = PermissionBlockedView(reason: reason, permissionsManager: permissionsManager)
        let hostingView = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "MyWhisper — Permisos Requeridos"
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
        NSApp.setActivationPolicy(.regular) // Show in Dock so user can interact
        NSApp.activate(ignoringOtherApps: true)
        self.permissionWindow = window
    }
}
