import AppKit

@MainActor
final class HistoryWindowController: NSObject, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private var panel: NSPanel?
    private let historyService: TranscriptionHistoryService
    private var tableView: NSTableView?

    init(historyService: TranscriptionHistoryService) {
        self.historyService = historyService
        super.init()
    }

    func show() {
        if let existing = panel {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            refresh()
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "MyWhisper - Historial"
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        let contentView = panel.contentView!

        // Scroll view + table
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        contentView.addSubview(scrollView)

        let tableView = NSTableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = false
        tableView.allowsEmptySelection = true

        let textColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("text"))
        textColumn.title = "Texto"
        textColumn.width = 300
        textColumn.isEditable = false
        tableView.addTableColumn(textColumn)

        let dateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("date"))
        dateColumn.title = "Fecha"
        dateColumn.width = 120
        dateColumn.isEditable = false
        tableView.addTableColumn(dateColumn)

        scrollView.documentView = tableView
        self.tableView = tableView

        // Clear history button
        let clearButton = NSButton(title: "Limpiar historial", target: self, action: #selector(clearHistory))
        clearButton.bezelStyle = .rounded
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(clearButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: clearButton.topAnchor, constant: -8),

            clearButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            clearButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])

        panel.center()
        NSApp.setActivationPolicy(.regular)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.panel = panel
    }

    func refresh() {
        tableView?.reloadData()
    }

    // MARK: - Actions

    @objc private func clearHistory() {
        historyService.clear()
        tableView?.reloadData()
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return historyService.entries.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let entries = historyService.entries
        guard row < entries.count else { return nil }
        let entry = entries[row]
        switch tableColumn?.identifier.rawValue {
        case "text": return entry.truncated
        case "date": return entry.date.historyDisplayString
        default: return nil
        }
    }

    // MARK: - NSTableViewDelegate

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = tableView else { return }
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 else { return }
        let entries = historyService.entries
        guard selectedRow < entries.count else { return }

        // Copy full text to clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entries[selectedRow].text, forType: .string)

        // Show notification
        NotificationHelper.show(title: "Texto copiado")

        // Deselect to allow re-clicking same entry
        tableView.deselectAll(nil)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        self.panel = nil
    }
}

// MARK: - Date extension

extension Date {
    var historyDisplayString: String {
        if abs(timeIntervalSinceNow) > 86400 {
            let df = DateFormatter()
            df.locale = Locale(identifier: "es")
            df.dateStyle = .short
            df.timeStyle = .short
            return df.string(from: self)
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
