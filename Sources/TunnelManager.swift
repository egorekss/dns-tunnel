import Foundation

enum TunnelState: Equatable {
    case disconnected
    case connecting
    case connected(server: ServerConfig, since: Date)
    case disconnecting
    case error(String)

    static func == (lhs: TunnelState, rhs: TunnelState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected): return true
        case (.connecting, .connecting): return true
        case (.disconnecting, .disconnecting): return true
        case (.connected(let a, _), .connected(let b, _)): return a.id == b.id
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

final class TunnelManager: ObservableObject {
    @Published var state: TunnelState = .disconnected

    private let store: ServerStore
    private let settings: AppSettings
    private let helper = HelperRunner()
    private let detector = VPNDetector()
    private var pollTimer: Timer?

    init(store: ServerStore, settings: AppSettings) {
        self.store = store
        self.settings = settings
        startPolling()
    }

    var isConnected: Bool {
        if case .connected = state { return true }
        return false
    }

    var isBusy: Bool {
        switch state {
        case .connecting, .disconnecting: return true
        default: return false
        }
    }

    func connect(completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard let server = store.selectedServer else {
            state = .error(L("No server selected"))
            completion?(.failure(SimpleError(L("No server selected"))))
            return
        }
        if let err = server.validate() {
            state = .error(err)
            completion?(.failure(SimpleError(err)))
            return
        }
        state = .connecting
        helper.connect(server: server) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.state = .connected(server: server, since: Date())
                    completion?(.success(()))
                case .failure(let err):
                    self.state = .error(err.localizedDescription)
                    completion?(.failure(err))
                }
            }
        }
    }

    func disconnect(completion: ((Result<Void, Error>) -> Void)? = nil) {
        state = .disconnecting
        helper.disconnect { result in
            DispatchQueue.main.async {
                self.state = .disconnected
                if case .failure(let err) = result {
                    completion?(.failure(err))
                } else {
                    completion?(.success(()))
                }
            }
        }
    }

    /// Главная точка входа от UI: проверяет конфликтующие VPN, отключает их (если включено в настройках),
    /// и затем поднимает iodine. Возвращает в completion список найденных VPN для UX.
    func handleConnectFlow(detectedHandler: @escaping ([DetectedVPN]) -> Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        let detected = detector.detect()
        if detected.isEmpty {
            connect(completion: completion)
            return
        }
        let shouldDisconnect = detectedHandler(detected)
        if !shouldDisconnect {
            completion(.failure(SimpleError(L("Cancelled by user"))))
            return
        }
        state = .connecting
        detector.disconnect(detected) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.connect(completion: completion)
                case .failure(let err):
                    self.state = .error(err.localizedDescription)
                    completion(.failure(err))
                }
            }
        }
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.pollStatus()
        }
        pollStatus()
    }

    private func pollStatus() {
        let alive = checkHelperAlive()
        if alive {
            if case .connected = state { return }
            if case .connecting = state { return }
            if let s = store.selectedServer {
                state = .connected(server: s, since: Date())
            }
        } else {
            switch state {
            case .connected, .connecting:
                state = .disconnected
            default: break
            }
        }
    }

    private func checkHelperAlive() -> Bool {
        let pidPath = "/tmp/proxy-tunnel.pid"
        guard FileManager.default.fileExists(atPath: pidPath),
              let pidStr = try? String(contentsOfFile: pidPath),
              let pid = Int32(pidStr.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return kill(pid, 0) == 0
    }
}
