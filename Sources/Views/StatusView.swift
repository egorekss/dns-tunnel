import SwiftUI
import AppKit

struct StatusView: View {
    @EnvironmentObject var tunnel: TunnelManager
    @EnvironmentObject var store: ServerStore
    @EnvironmentObject var settings: AppSettings

    @State private var elapsed: TimeInterval = 0
    @State private var pendingDetected: [DetectedVPN] = []
    @State private var showVPNAlert = false

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 8)

            ZStack {
                Circle()
                    .fill(statusBgColor.opacity(0.16))
                    .frame(width: 168, height: 168)
                Circle()
                    .strokeBorder(statusBgColor.opacity(0.32), lineWidth: 2)
                    .frame(width: 168, height: 168)
                Image(systemName: statusIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 84, height: 84)
                    .foregroundColor(statusColor)
            }

            VStack(spacing: 6) {
                Text(statusTitle)
                    .font(.system(size: 18, weight: .semibold))
                if case .connected(_, let since) = tunnel.state {
                    Text(formatDuration(elapsed))
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .onAppear { elapsed = Date().timeIntervalSince(since) }
                        .onReceive(timer) { _ in elapsed = Date().timeIntervalSince(since) }
                } else if case .error(let msg) = tunnel.state {
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .lineLimit(3)
                }
            }

            if !store.servers.isEmpty {
                HStack(spacing: 8) {
                    Text("Server:").foregroundColor(.secondary)
                    Picker("", selection: serverBinding) {
                        ForEach(store.servers) { s in
                            Text(s.name).tag(Optional(s.id))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 220)
                    .disabled(tunnel.isConnected || tunnel.isBusy)
                }
            }

            Button(action: handleToggle) {
                Text(tunnel.isConnected ? "Disconnect" : "Connect")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: 240)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(tunnel.isConnected ? .red : .accentColor)
            .disabled(tunnel.isBusy || store.servers.isEmpty)
            .keyboardShortcut(.defaultAction)

            Spacer(minLength: 8)

            HStack {
                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/tmp/proxy-tunnel.log"))
                } label: {
                    Label("Open log", systemImage: "doc.text")
                }
                .buttonStyle(.link)

                Spacer()

                if !HelperRunner.helperInstalled() {
                    Label("Helper not installed", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .padding(.top, 8)
        .alert("Active VPNs detected", isPresented: $showVPNAlert, presenting: pendingDetected) { _ in
            Button("Disconnect and connect") {
                runConnectFlow(autoDisconnect: true)
            }
            Button("Cancel", role: .cancel) { }
        } message: { detected in
            Text("Found: \(detected.map { $0.displayName }.joined(separator: ", "))\n\nThese connections must be terminated. Do this automatically?")
        }
    }

    var serverBinding: Binding<UUID?> {
        Binding(
            get: { store.selectedID ?? store.servers.first?.id },
            set: { store.selectedID = $0 }
        )
    }

    func handleToggle() {
        if tunnel.isConnected {
            tunnel.disconnect()
        } else {
            tunnel.handleConnectFlow(detectedHandler: { detected in
                if settings.autoDisconnectVPNs {
                    return true
                } else {
                    DispatchQueue.main.async {
                        self.pendingDetected = detected
                        self.showVPNAlert = true
                    }
                    return false
                }
            }, completion: { _ in })
        }
    }

    func runConnectFlow(autoDisconnect: Bool) {
        tunnel.handleConnectFlow(detectedHandler: { _ in autoDisconnect }, completion: { _ in })
    }

    var statusIcon: String {
        switch tunnel.state {
        case .connected: return "shield.checkered"
        case .connecting, .disconnecting: return "shield.lefthalf.filled"
        case .disconnected, .error: return "shield.slash"
        }
    }

    var statusColor: Color {
        switch tunnel.state {
        case .connected: return .green
        case .connecting, .disconnecting: return .orange
        case .disconnected: return .secondary
        case .error: return .red
        }
    }

    var statusBgColor: Color {
        switch tunnel.state {
        case .connected: return .green
        case .connecting, .disconnecting: return .orange
        case .disconnected: return .gray
        case .error: return .red
        }
    }

    var statusTitle: LocalizedStringKey {
        switch tunnel.state {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting…"
        case .connected(let s, _): return "Connected — \(s.name)"
        case .disconnecting: return "Disconnecting…"
        case .error: return "Error"
        }
    }

    func formatDuration(_ t: TimeInterval) -> String {
        let total = Int(t)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}
