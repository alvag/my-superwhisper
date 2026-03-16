import AppKit

@MainActor
final class APIKeyWindowController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var haikuCleanup: (any HaikuCleanupProtocol)?
    private var onComplete: (() -> Void)?

    // UI references kept for callbacks
    private var secureTextField: NSSecureTextField?
    private var saveButton: NSButton?
    private var statusLabel: NSTextField?

    init(haikuCleanup: (any HaikuCleanupProtocol)?) {
        self.haikuCleanup = haikuCleanup
        super.init()
    }

    /// Show the API key entry panel. onComplete called after successful save.
    func show(onComplete: (() -> Void)? = nil) {
        self.onComplete = onComplete

        // Bring existing panel to front if already open
        if let existing = panel {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 180),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "MyWhisper — Clave de API"
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        let contentView = panel.contentView!
        contentView.translatesAutoresizingMaskIntoConstraints = false

        // Label
        let label = NSTextField(labelWithString: "Introduce tu clave de API de Anthropic:")
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)

        // Secure text field for API key (masked)
        let secureField = NSSecureTextField()
        secureField.placeholderString = "sk-ant-..."
        secureField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(secureField)
        self.secureTextField = secureField

        // Status/error label (hidden initially)
        let status = NSTextField(labelWithString: "")
        status.translatesAutoresizingMaskIntoConstraints = false
        status.textColor = .systemRed
        status.isHidden = true
        contentView.addSubview(status)
        self.statusLabel = status

        // Save button
        let button = NSButton(title: "Guardar", target: self, action: #selector(saveClicked))
        button.bezelStyle = .rounded
        button.keyEquivalent = "\r"
        button.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(button)
        self.saveButton = button

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            secureField.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 10),
            secureField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            secureField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            status.topAnchor.constraint(equalTo: secureField.bottomAnchor, constant: 6),
            status.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            status.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            button.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            button.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])

        panel.center()
        NSApp.setActivationPolicy(.regular)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.panel = panel
    }

    @objc private func saveClicked() {
        guard let key = secureTextField?.stringValue, !key.isEmpty else {
            showStatus("Introduce una clave", isError: true)
            return
        }

        saveButton?.isEnabled = false
        showStatus("Validando...", isError: false)

        Task {
            do {
                try await haikuCleanup?.saveAPIKey(key)
                panel?.close()
                self.panel = nil
                onComplete?()
            } catch let error as HaikuCleanupError {
                switch error {
                case .authFailed:
                    showStatus("Clave invalida o sin credito", isError: true)
                case .networkError:
                    showStatus("Error de red — comprueba tu conexion", isError: true)
                default:
                    showStatus("Error: \(error.localizedDescription)", isError: true)
                }
                saveButton?.isEnabled = true
            } catch {
                showStatus("Error inesperado", isError: true)
                saveButton?.isEnabled = true
            }
        }
    }

    private func showStatus(_ message: String, isError: Bool) {
        statusLabel?.stringValue = message
        statusLabel?.textColor = isError ? .systemRed : .secondaryLabelColor
        statusLabel?.isHidden = false
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // Restore accessory (menubar-only) mode when panel closes
        NSApp.setActivationPolicy(.accessory)
        self.panel = nil
    }
}
