import AppKit

protocol WindowOpener: AnyObject {
    func openMainWindow()
    func toggleConnection()
}

final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private weak var tunnel: TunnelManager?
    private weak var opener: WindowOpener?

    init(tunnel: TunnelManager, opener: WindowOpener) {
        self.tunnel = tunnel
        self.opener = opener
        super.init()
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "shield.slash", accessibilityDescription: nil)
            button.image?.isTemplate = true
        }
        rebuildMenu()
    }

    func updateUI() {
        guard let button = statusItem.button else { return }
        let icon: String
        switch tunnel?.state ?? .disconnected {
        case .connected: icon = "shield.checkered"
        case .connecting, .disconnecting: icon = "shield.lefthalf.filled"
        case .disconnected, .error: icon = "shield.slash"
        }
        button.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        button.image?.isTemplate = true
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let statusText: String
        switch tunnel?.state ?? .disconnected {
        case .disconnected: statusText = L("Disconnected")
        case .connecting: statusText = L("Connecting…")
        case .connected(let server, _): statusText = L("Connected — %@", server.name)
        case .disconnecting: statusText = L("Disconnecting…")
        case .error(let msg): statusText = L("Error: %@", String(msg.prefix(40)))
        }
        let header = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        menu.addItem(.separator())

        let isConnected = tunnel?.isConnected ?? false
        let isBusy = tunnel?.isBusy ?? false

        let toggleItem = NSMenuItem(
            title: isConnected ? L("Disconnect") : L("Connect"),
            action: #selector(toggleTapped),
            keyEquivalent: "")
        toggleItem.target = self
        toggleItem.isEnabled = !isBusy
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let openItem = NSMenuItem(title: L("Open window"), action: #selector(openWindow), keyEquivalent: "0")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L("Quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc private func toggleTapped() {
        opener?.toggleConnection()
    }

    @objc private func openWindow() {
        opener?.openMainWindow()
    }
}
