import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator!
    private var menubarController: MenubarController!
    private var hotkeyMonitor: HotkeyMonitor!
    private var escapeMonitor: EscapeMonitor!
    private var statusMenuController: StatusMenuController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Initialize core components
        coordinator = AppCoordinator()
        menubarController = MenubarController()
        escapeMonitor = EscapeMonitor(coordinator: coordinator)

        // Wire coordinator dependencies
        coordinator.menubarController = menubarController
        coordinator.escapeMonitor = escapeMonitor

        // Build and attach menu
        statusMenuController = StatusMenuController(coordinator: coordinator)
        menubarController.setMenu(statusMenuController.buildMenu())

        // Register hotkey last (after coordinator is fully wired)
        hotkeyMonitor = HotkeyMonitor(coordinator: coordinator)

        // Permission health check — PermissionsManager added in Plan 03
        // textInjector and overlayController added in Plan 04
    }
}
