import AppKit

final class MenubarController {
    let statusItem: NSStatusItem

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        update(state: .idle)
    }

    func update(state: AppState) {
        statusItem.button?.image = Self.image(for: state)
    }

    func setMenu(_ menu: NSMenu) {
        statusItem.menu = menu
    }

    static func image(for state: AppState) -> NSImage? {
        switch state {
        case .idle:
            // Template image — macOS renders it matching menubar appearance (light/dark)
            let img = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "MyWhisper")
            img?.isTemplate = true
            return img
        case .recording, .processing, .error:
            // Colored image — draw SF Symbol with explicit color baked in
            let color: NSColor
            switch state {
            case .recording: color = .systemRed
            case .processing: color = .systemBlue
            case .error: color = .systemOrange
            default: color = .labelColor
            }
            return coloredSymbol("mic.fill", color: color)
        }
    }

    private static func coloredSymbol(_ name: String, color: NSColor, pointSize: CGFloat = 14) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: "MyWhisper")?
            .withSymbolConfiguration(config) else { return nil }

        let size = symbol.size
        let image = NSImage(size: size, flipped: false) { rect in
            symbol.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        image.isTemplate = false
        return image
    }
}
