import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section(title: "CONNECTION") {
                    Toggle("Automatically disconnect other VPNs when connecting", isOn: $settings.autoDisconnectVPNs)
                    Text("System VPNs (Streisand, IKEv2, L2TP, NetworkExtension) are stopped via `scutil --nc stop`. Known processes (openvpn, wg-quick, sing-box, v2ray, xray, OutlineService, Tunnelblick) are killed by the helper script.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                section(title: "DNS") {
                    Toggle("Use public DNS (1.1.1.1, 8.8.8.8)", isOn: $settings.publicDNS)
                    Text("When the tunnel is active, DNS queries must not go through the tunnel itself, otherwise there will be a circular dependency. Recommended to keep on.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                section(title: "APPEARANCE") {
                    Toggle("Show Dock icon", isOn: $settings.showDockIcon)
                    Text("When disabled, the app runs only from the menu bar (like a regular VPN client).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                section(title: "SYSTEM COMPONENTS") {
                    HStack {
                        Image(systemName: HelperRunner.helperInstalled() ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(HelperRunner.helperInstalled() ? .green : .orange)
                        Text(HelperRunner.helperInstalled()
                             ? "Helper script installed"
                             : "Helper script not found")
                    }
                    if !HelperRunner.helperInstalled() {
                        Text("Run `Scripts/install-helper.sh` from the app folder with administrator privileges.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Image(systemName: iodineExists ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(iodineExists ? .green : .orange)
                        Text(iodineExists
                             ? "iodine: \(iodinePath)"
                             : "iodine not installed — `brew install iodine`")
                    }
                }

                Spacer(minLength: 8)
            }
            .padding(20)
        }
    }

    @ViewBuilder
    func section<C: View>(title: LocalizedStringKey, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            content()
        }
    }

    var iodinePath: String {
        for p in ["/opt/homebrew/sbin/iodine", "/opt/homebrew/bin/iodine", "/usr/local/sbin/iodine", "/usr/local/bin/iodine"] {
            if FileManager.default.isExecutableFile(atPath: p) { return p }
        }
        return ""
    }

    var iodineExists: Bool {
        return !iodinePath.isEmpty
    }
}
