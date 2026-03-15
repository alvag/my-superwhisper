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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Permission health check — runs on every launch (TCC can revoke after OS updates)
        let permissionsManager = PermissionsManager()
        self.permissionsManager = permissionsManager

        let permissionStatus = permissionsManager.checkAllOnLaunch()
        if case .blocked(let reason) = permissionStatus {
            showPermissionBlockedWindow(reason: reason, permissionsManager: permissionsManager)
            // Do NOT initialize hotkey or menubar yet — app is blocked
            return
        }

        // Initialize core components
        coordinator = AppCoordinator()
        menubarController = MenubarController()
        escapeMonitor = EscapeMonitor(coordinator: coordinator)

        // Create remaining dependencies
        let audioRecorder = AudioRecorder()
        let textInjector = TextInjector(permissionsManager: permissionsManager)
        let overlayController = OverlayWindowController()

        // Wire coordinator dependencies
        coordinator.menubarController = menubarController
        coordinator.escapeMonitor = escapeMonitor
        coordinator.audioRecorder = audioRecorder
        coordinator.textInjector = textInjector
        coordinator.overlayController = overlayController

        // Store strong references
        self.audioRecorder = audioRecorder
        self.textInjector = textInjector
        self.overlayController = overlayController

        // Build and attach menu
        statusMenuController = StatusMenuController(coordinator: coordinator)
        menubarController.setMenu(statusMenuController.buildMenu())

        // Register hotkey last (after coordinator is fully wired)
        hotkeyMonitor = HotkeyMonitor(coordinator: coordinator)
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
