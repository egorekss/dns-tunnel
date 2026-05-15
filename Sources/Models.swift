import Foundation

/// Localization helper. Looks up `key` in Localizable.strings of the current locale.
func L(_ key: String, comment: String = "") -> String {
    return NSLocalizedString(key, comment: comment)
}

func L(_ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, comment: "")
    return String(format: format, arguments: args)
}

struct ServerConfig: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var domain: String = ""
    var password: String = ""
    var serverIP: String = ""

    func validate() -> String? {
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            return L("Please enter a server name")
        }
        if domain.trimmingCharacters(in: .whitespaces).isEmpty {
            return L("Please enter the tunnel domain")
        }
        if password.isEmpty {
            return L("Please enter the password")
        }
        let ip = serverIP.trimmingCharacters(in: .whitespaces)
        if ip.isEmpty {
            return L("Please enter the server IP")
        }
        let parts = ip.split(separator: ".")
        if parts.count != 4 { return L("IP must be in format 1.2.3.4") }
        for p in parts {
            guard let n = Int(p), (0...255).contains(n) else {
                return L("IP must be in format 1.2.3.4")
            }
        }
        return nil
    }
}

final class ServerStore: ObservableObject {
    @Published private(set) var servers: [ServerConfig] = []
    @Published var selectedID: UUID? {
        didSet { saveSelection() }
    }

    private let serversKey = "servers.v1"
    private let selectedKey = "selectedServerID.v1"

    init() {
        load()
    }

    var selectedServer: ServerConfig? {
        if let id = selectedID, let s = servers.first(where: { $0.id == id }) {
            return s
        }
        return servers.first
    }

    private func load() {
        let d = UserDefaults.standard

        if let data = d.data(forKey: serversKey),
           let decoded = try? JSONDecoder().decode([ServerConfig].self, from: data) {
            servers = decoded
        }
        if let s = d.string(forKey: selectedKey), let id = UUID(uuidString: s) {
            selectedID = id
        }

        // Миграция со старых отдельных ключей (одиночный сервер) — читаем из текущего bundle И из legacy
        if servers.isEmpty {
            let legacy = UserDefaults(suiteName: "com.proxyusn.dnstunnel")
            let domain = (d.string(forKey: "tunnelDomain") ?? legacy?.string(forKey: "tunnelDomain")) ?? ""
            let password = (d.string(forKey: "tunnelPassword") ?? legacy?.string(forKey: "tunnelPassword")) ?? ""
            let ip = (d.string(forKey: "serverIP") ?? legacy?.string(forKey: "serverIP")) ?? ""
            if !domain.isEmpty, !ip.isEmpty {
                let s = ServerConfig(name: L("My server"), domain: domain, password: password, serverIP: ip)
                servers = [s]
                selectedID = s.id
                save()
            }
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(data, forKey: serversKey)
        }
    }

    private func saveSelection() {
        if let id = selectedID {
            UserDefaults.standard.set(id.uuidString, forKey: selectedKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedKey)
        }
    }

    func add(_ s: ServerConfig) {
        servers.append(s)
        if selectedID == nil { selectedID = s.id }
        save()
    }

    func update(_ s: ServerConfig) {
        if let i = servers.firstIndex(where: { $0.id == s.id }) {
            servers[i] = s
            save()
        }
    }

    func delete(_ id: UUID) {
        servers.removeAll { $0.id == id }
        if selectedID == id { selectedID = servers.first?.id }
        save()
    }
}

final class AppSettings: ObservableObject {
    @Published var autoDisconnectVPNs: Bool {
        didSet { UserDefaults.standard.set(autoDisconnectVPNs, forKey: "settings.autoDisconnectVPNs") }
    }
    @Published var publicDNS: Bool {
        didSet { UserDefaults.standard.set(publicDNS, forKey: "settings.publicDNS") }
    }
    @Published var showDockIcon: Bool {
        didSet { UserDefaults.standard.set(showDockIcon, forKey: "settings.showDockIcon") }
    }

    init() {
        let d = UserDefaults.standard
        autoDisconnectVPNs = (d.object(forKey: "settings.autoDisconnectVPNs") as? Bool) ?? true
        publicDNS = (d.object(forKey: "settings.publicDNS") as? Bool) ?? true
        showDockIcon = (d.object(forKey: "settings.showDockIcon") as? Bool) ?? true
    }
}

struct SimpleError: LocalizedError {
    let message: String
    init(_ m: String) { self.message = m }
    var errorDescription: String? { message }
}
