import Foundation

final class HelperRunner {
    static let helperPath = "/usr/local/bin/proxy-tunnel.sh"

    static func helperInstalled() -> Bool {
        return FileManager.default.fileExists(atPath: helperPath)
    }

    func connect(server: ServerConfig, completion: @escaping (Result<Void, Error>) -> Void) {
        let cmd = "\(Self.helperPath) connect \(shellQuote(server.domain)) \(shellQuote(server.password)) \(shellQuote(server.serverIP))"
        runSudo(cmd, completion: completion)
    }

    func disconnect(completion: @escaping (Result<Void, Error>) -> Void) {
        runSudo("\(Self.helperPath) disconnect", completion: completion)
    }

    func killVPNs(_ processes: [String], completion: @escaping (Result<Void, Error>) -> Void) {
        let args = processes.joined(separator: " ")
        runSudo("\(Self.helperPath) kill-vpns \(args)", completion: completion)
    }

    private func shellQuote(_ s: String) -> String {
        return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func appleScriptEscape(_ s: String) -> String {
        return s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func runSudo(_ cmd: String, completion: @escaping (Result<Void, Error>) -> Void) {
        if !Self.helperInstalled() {
            completion(.failure(SimpleError(L("Helper not installed (%@). Run Scripts/install-helper.sh.", Self.helperPath))))
            return
        }
        let script = "do shell script \"\(appleScriptEscape(cmd))\" with administrator privileges"
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", script]
            let outPipe = Pipe()
            let errPipe = Pipe()
            task.standardOutput = outPipe
            task.standardError = errPipe
            do {
                try task.run()
            } catch {
                completion(.failure(error))
                return
            }
            task.waitUntilExit()
            if task.terminationStatus == 0 {
                completion(.success(()))
            } else {
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let errStr = String(data: errData, encoding: .utf8) ?? "Unknown error"
                completion(.failure(SimpleError(errStr.trimmingCharacters(in: .whitespacesAndNewlines))))
            }
        }
    }
}
