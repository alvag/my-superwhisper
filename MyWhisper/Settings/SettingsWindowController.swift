import AppKit
import CoreAudio
import KeyboardShortcuts
import ServiceManagement

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private var panel: NSPanel?
    private let vocabularyService: VocabularyService
    private let microphoneService: MicrophoneDeviceService
    private var apiKeyWindowController: APIKeyWindowController?
    private var haikuCleanup: (any HaikuCleanupProtocol)?

    // UI references
    private var tableView: NSTableView?
    private var vocabEntries: [VocabularyEntry] = []

    init(vocabularyService: VocabularyService, microphoneService: MicrophoneDeviceService, haikuCleanup: (any HaikuCleanupProtocol)?) {
        self.vocabularyService = vocabularyService
        self.microphoneService = microphoneService
        self.haikuCleanup = haikuCleanup
        super.init()
        self.apiKeyWindowController = APIKeyWindowController(haikuCleanup: haikuCleanup)
    }

    func show() {
        if let existing = panel {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Load current vocabulary entries
        vocabEntries = vocabularyService.entries

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 590),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "MyWhisper - Preferencias"
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        let contentView = panel.contentView!
        contentView.translatesAutoresizingMaskIntoConstraints = false

        var allConstraints: [NSLayoutConstraint] = []

        // ---- Section 1: Hotkey ----
        let hotkeyLabel = NSTextField(labelWithString: "Atajo de grabacion:")
        hotkeyLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hotkeyLabel)

        let recorder = KeyboardShortcuts.RecorderCocoa(for: .toggleRecording)
        recorder.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(recorder)

        // ---- Section 2: Microphone ----
        let micLabel = NSTextField(labelWithString: "Microfono:")
        micLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(micLabel)

        let micPopup = NSPopUpButton()
        micPopup.translatesAutoresizingMaskIntoConstraints = false
        micPopup.target = self
        micPopup.action = #selector(microphoneChanged(_:))
        contentView.addSubview(micPopup)

        // Populate microphone list
        let devices = microphoneService.availableInputDevices()
        // Add system default option first
        let defaultItem = NSMenuItem(title: "Predeterminado del sistema", action: nil, keyEquivalent: "")
        defaultItem.tag = -1
        micPopup.menu?.addItem(defaultItem)

        var selectedIndex = 0
        for (index, device) in devices.enumerated() {
            let item = NSMenuItem(title: device.name, action: nil, keyEquivalent: "")
            item.tag = Int(device.id)
            micPopup.menu?.addItem(item)
            if let selectedID = microphoneService.selectedDeviceID, selectedID == device.id {
                selectedIndex = index + 1 // +1 for system default item
            }
        }
        micPopup.selectItem(at: selectedIndex)

        // ---- Section 3: API Key ----
        let apiKeyButton = NSButton(title: "Cambiar clave de API...", target: self, action: #selector(changeAPIKey))
        apiKeyButton.bezelStyle = .rounded
        apiKeyButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(apiKeyButton)

        // ---- Section 4: Vocabulary Corrections ----
        let vocabLabel = NSTextField(labelWithString: "Correcciones de vocabulario:")
        vocabLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(vocabLabel)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        contentView.addSubview(scrollView)

        let tableView = NSTableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = false

        let wrongColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("wrong"))
        wrongColumn.title = "Incorrecto"
        wrongColumn.width = 180
        wrongColumn.isEditable = true
        tableView.addTableColumn(wrongColumn)

        let correctColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("correct"))
        correctColumn.title = "Correcto"
        correctColumn.width = 180
        correctColumn.isEditable = true
        tableView.addTableColumn(correctColumn)

        scrollView.documentView = tableView
        self.tableView = tableView

        // Vocab buttons (+/-)
        let addButton = NSButton(title: "+", target: self, action: #selector(addVocabEntry))
        addButton.bezelStyle = .rounded
        addButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(addButton)

        let removeButton = NSButton(title: "-", target: self, action: #selector(removeVocabEntry))
        removeButton.bezelStyle = .rounded
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(removeButton)

        // ---- Section 5: Launch at Login ----
        let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Iniciar al arranque", target: self, action: #selector(launchAtLoginChanged(_:)))
        launchAtLoginCheckbox.translatesAutoresizingMaskIntoConstraints = false
        launchAtLoginCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
        contentView.addSubview(launchAtLoginCheckbox)

        // ---- Section 6: Pause Playback ----
        let pauseCheckbox = NSButton(checkboxWithTitle: "Pausar reproduccion al grabar", target: self, action: #selector(pausePlaybackChanged(_:)))
        pauseCheckbox.translatesAutoresizingMaskIntoConstraints = false
        pauseCheckbox.state = UserDefaults.standard.bool(forKey: "pausePlaybackEnabled") ? .on : .off
        contentView.addSubview(pauseCheckbox)

        // ---- Section 7: Maximize Mic Volume ----
        let volumeCheckbox = NSButton(checkboxWithTitle: "Maximizar volumen al grabar", target: self, action: #selector(maximizeMicVolumeChanged(_:)))
        volumeCheckbox.translatesAutoresizingMaskIntoConstraints = false
        volumeCheckbox.state = UserDefaults.standard.bool(forKey: "maximizeMicVolumeEnabled") ? .on : .off
        contentView.addSubview(volumeCheckbox)

        // ---- Auto Layout ----
        allConstraints += [
            // Section 1: Hotkey
            hotkeyLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            hotkeyLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            recorder.centerYAnchor.constraint(equalTo: hotkeyLabel.centerYAnchor),
            recorder.leadingAnchor.constraint(equalTo: hotkeyLabel.trailingAnchor, constant: 12),
            recorder.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),

            // Section 2: Microphone
            micLabel.topAnchor.constraint(equalTo: hotkeyLabel.bottomAnchor, constant: 16),
            micLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            micPopup.centerYAnchor.constraint(equalTo: micLabel.centerYAnchor),
            micPopup.leadingAnchor.constraint(equalTo: micLabel.trailingAnchor, constant: 12),
            micPopup.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            // Section 3: API Key Button
            apiKeyButton.topAnchor.constraint(equalTo: micLabel.bottomAnchor, constant: 16),
            apiKeyButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            // Section 4: Vocabulary
            vocabLabel.topAnchor.constraint(equalTo: apiKeyButton.bottomAnchor, constant: 16),
            vocabLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            scrollView.topAnchor.constraint(equalTo: vocabLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            scrollView.heightAnchor.constraint(equalToConstant: 160),

            addButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 6),
            addButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            addButton.widthAnchor.constraint(equalToConstant: 30),

            removeButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 6),
            removeButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 6),
            removeButton.widthAnchor.constraint(equalToConstant: 30),

            // Section 5: Launch at Login
            launchAtLoginCheckbox.topAnchor.constraint(equalTo: addButton.bottomAnchor, constant: 16),
            launchAtLoginCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            // Section 6: Pause Playback
            pauseCheckbox.topAnchor.constraint(equalTo: launchAtLoginCheckbox.bottomAnchor, constant: 10),
            pauseCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            // Section 7: Maximize Mic Volume
            volumeCheckbox.topAnchor.constraint(equalTo: pauseCheckbox.bottomAnchor, constant: 10),
            volumeCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            volumeCheckbox.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20),
        ]

        NSLayoutConstraint.activate(allConstraints)

        panel.center()
        NSApp.setActivationPolicy(.regular)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.panel = panel
    }

    // MARK: - Actions

    @objc private func microphoneChanged(_ sender: NSPopUpButton) {
        guard let selectedItem = sender.selectedItem else { return }
        let tag = selectedItem.tag
        if tag == -1 {
            // System default selected
            microphoneService.selectedDeviceID = nil
        } else {
            microphoneService.selectedDeviceID = AudioDeviceID(tag)
        }
    }

    @objc private func changeAPIKey() {
        apiKeyWindowController?.show()
    }

    @objc private func addVocabEntry() {
        vocabEntries.append(VocabularyEntry(wrong: "", correct: ""))
        vocabularyService.entries = vocabEntries
        tableView?.reloadData()
    }

    @objc private func removeVocabEntry() {
        guard let tableView = tableView, tableView.selectedRow >= 0 else { return }
        vocabEntries.remove(at: tableView.selectedRow)
        vocabularyService.entries = vocabEntries
        tableView.reloadData()
    }

    @objc private func launchAtLoginChanged(_ sender: NSButton) {
        do {
            if sender.state == .on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[Settings] LaunchAtLogin error: \(error)")
            // Revert checkbox to actual state
            sender.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
    }

    @objc private func pausePlaybackChanged(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "pausePlaybackEnabled")
    }

    @objc private func maximizeMicVolumeChanged(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "maximizeMicVolumeEnabled")
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return vocabEntries.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row < vocabEntries.count else { return nil }
        let entry = vocabEntries[row]
        switch tableColumn?.identifier.rawValue {
        case "wrong": return entry.wrong
        case "correct": return entry.correct
        default: return nil
        }
    }

    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        guard row < vocabEntries.count else { return }
        let value = object as? String ?? ""
        switch tableColumn?.identifier.rawValue {
        case "wrong": vocabEntries[row].wrong = value
        case "correct": vocabEntries[row].correct = value
        default: break
        }
        vocabularyService.entries = vocabEntries
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        self.panel = nil
    }
}
