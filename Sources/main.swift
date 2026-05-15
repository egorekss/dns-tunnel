import Cocoa
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, WindowOpener {
    let serverStore = ServerStore()
    let settings = AppSettings()
    lazy var tunnel = TunnelManager(store: serverStore, settings: settings)
    var menuBarController: MenuBarController!
    var mainWindow: NSWindow?
    var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyDockVisibility()
        menuBarController = MenuBarController(tunnel: tunnel, opener: self)

        tunnel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.menuBarController.updateUI()
            }
            .store(in: &cancellables)

        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyDockVisibility()
            }
            .store(in: &cancellables)

        // Первый запуск или нет настроенных серверов — сразу открываем окно
        if serverStore.servers.isEmpty {
            openMainWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { openMainWindow() }
        return true
    }

    func applyDockVisibility() {
        NSApp.setActivationPolicy(settings.showDockIcon ? .regular : .accessory)
    }

    func openMainWindow() {
        if mainWindow == nil {
            let view = ContentView()
                .environmentObject(serverStore)
                .environmentObject(settings)
                .environmentObject(tunnel)

            let host = NSHostingController(rootView: view)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.contentViewController = host
            window.title = "DNS Tunnel"
            window.center()
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 460, height: 540)
            mainWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    func toggleConnection() {
        if tunnel.isConnected {
            tunnel.disconnect()
        } else {
            tunnel.handleConnectFlow(detectedHandler: { _ in
                return self.settings.autoDisconnectVPNs
            }, completion: { _ in })
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
