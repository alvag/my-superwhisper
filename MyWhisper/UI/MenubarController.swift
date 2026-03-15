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
        let symbolName = "mic"
        let config: NSImage.SymbolConfiguration
        switch state {
        case .idle:
            config = .init(paletteColors: [.secondaryLabelColor])
        case .recording:
            config = .init(paletteColors: [.systemRed])
        case .processing:
            config = .init(paletteColors: [.systemBlue])
        case .error:
            config = .init(paletteColors: [.systemOrange])
        }
        let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: state.description)?
            .withSymbolConfiguration(config)
        img?.isTemplate = false // MUST be false to preserve color
        return img
    }
}
