import UserNotifications

enum NotificationHelper {
    /// Request provisional notification authorization at app launch.
    /// .provisional delivers to Notification Center without a blocking permission dialog.
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .provisional]
        ) { _, _ in }
    }

    /// Show a macOS notification immediately.
    /// - Parameters:
    ///   - title: The notification title (e.g., "No se detecto voz")
    ///   - body: Optional body text (e.g., error details)
    static func show(title: String, body: String = "") {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil  // Silent -- no sound for VAD/error notifications

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // Deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }
}
