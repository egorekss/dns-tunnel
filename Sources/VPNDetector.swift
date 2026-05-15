import Foundation

struct DetectedVPN {
    enum Kind {
        case systemConfig(uuid: String)
        case process(name: String)
        case unknownUtun(iface: String)
    }
    let displayName: String
    let kind: Kind
}

final class VPNDetector {
    private let knownProcs = [
        "openvpn", "wg-quick", "wireguard-go",
        "sing-box", "v2ray", "xray", "tun2socks",
        "OutlineService", "Tunnelblick"
    ]

    func detect() -> [DetectedVPN] {
        var result: [DetectedVPN] = []

        // 1. Системные VPN-конфиги (NetworkExtension-based, IKEv2, L2TP, IPSec)
        let scutilOutput = run("/usr/sbin/scutil", ["--nc", "list"])
        let pattern = "\\* \\(Connected\\)\\s+([0-9A-F-]+)\\s+VPN\\s+\\([^)]+\\)\\s+\"([^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            for line in scutilOutput.components(separatedBy: "\n") {
                let nsLine = line as NSString
                let matches = regex.matches(in: line, options: [], range: NSRange(location: 0, length: nsLine.length))
                for m in matches {
                    let uuid = nsLine.substring(with: m.range(at: 1))
                    let name = nsLine.substring(with: m.range(at: 2))
                    result.append(DetectedVPN(displayName: name, kind: .systemConfig(uuid: uuid)))
                }
            }
        }

        // 2. Известные VPN-процессы
        let psOut = run("/bin/ps", ["-axo", "comm"])
        for proc in knownProcs {
            if psOut.contains(proc) {
                result.append(DetectedVPN(displayName: proc, kind: .process(name: proc)))
            }
        }

        // 3. Catch-all: default route в utun, но больше ничего не нашли
        let route = run("/sbin/route", ["-n", "get", "default"])
        for line in route.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("interface:") && t.contains("utun") && result.isEmpty {
                let iface = t.replacingOccurrences(of: "interface: ", with: "")
                result.append(DetectedVPN(displayName: L("unknown VPN on %@", iface), kind: .unknownUtun(iface: iface)))
            }
        }
        return result
    }

    func disconnect(_ vpns: [DetectedVPN], completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var processesToKill: [String] = []

            for vpn in vpns {
                switch vpn.kind {
                case .systemConfig(let uuid):
                    _ = self.run("/usr/sbin/scutil", ["--nc", "stop", uuid])
                case .process(let name):
                    processesToKill.append(name)
                case .unknownUtun:
                    break
                }
            }

            if !processesToKill.isEmpty {
                let runner = HelperRunner()
                let semaphore = DispatchSemaphore(value: 0)
                var capturedErr: Error?
                runner.killVPNs(processesToKill) { result in
                    if case .failure(let e) = result { capturedErr = e }
                    semaphore.signal()
                }
                semaphore.wait()
                if let err = capturedErr {
                    DispatchQueue.main.async { completion(.failure(err)) }
                    return
                }
            }

            // Ждём до 10 сек пока default route уйдёт с utun
            var clean = false
            for _ in 0..<20 {
                Thread.sleep(forTimeInterval: 0.5)
                let route = self.run("/sbin/route", ["-n", "get", "default"])
                let stillUtun = route.components(separatedBy: "\n").contains { line in
                    let t = line.trimmingCharacters(in: .whitespaces)
                    return t.hasPrefix("interface:") && t.contains("utun")
                }
                if !stillUtun { clean = true; break }
            }
            DispatchQueue.main.async {
                completion(clean ? .success(()) : .failure(SimpleError(L("Could not free default route. Disconnect VPN manually."))))
            }
        }
    }

    private func run(_ path: String, _ args: [String]) -> String {
        let task = Process()
        task.launchPath = path
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do { try task.run() } catch { return "" }
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
