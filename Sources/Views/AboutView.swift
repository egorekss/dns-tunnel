import SwiftUI
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

struct AboutView: View {
    let donateAddress = "THMomvCtsbthM4hoZSW4AyvSbyn5wc6WUt"
    let githubURL = "https://github.com/egorekss/dns-tunnel"
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Image(systemName: "shield.checkered")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundColor(.accentColor)
                    .padding(.top, 16)

                Text("DNS Tunnel")
                    .font(.title2.weight(.semibold))

                Text("Version \(version)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Universal client for the iodine DNS tunnel for macOS. Connects to an iodined server and forwards IP traffic through DNS queries. Works in places where regular VPN is blocked but DNS is open.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 28)

                Divider().padding(.vertical, 6)

                VStack(spacing: 10) {
                    Text("Support the author")
                        .font(.headline)
                    Text("If this app is useful — send some USDT on TRON network (TRC20):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    if let qr = generateQR(from: donateAddress, size: 180) {
                        Image(nsImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 180, height: 180)
                            .background(Color.white)
                            .cornerRadius(6)
                    }

                    Text("USDT • TRC20 (TRON)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)

                    Text(donateAddress)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.12))
                        .cornerRadius(4)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(donateAddress, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                    } label: {
                        Label(copied ? "Copied" : "Copy address", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }

                Divider().padding(.vertical, 6)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("License:").foregroundColor(.secondary)
                        Text("MIT")
                    }
                    HStack {
                        Text("Source code:").foregroundColor(.secondary)
                        Link(githubURL, destination: URL(string: githubURL)!)
                    }
                    HStack {
                        Text("Iodine:").foregroundColor(.secondary)
                        Link("code.kryo.se/iodine", destination: URL(string: "https://code.kryo.se/iodine/")!)
                    }
                }
                .font(.caption)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    func generateQR(from string: String, size: CGFloat) -> NSImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scale = size / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        let img = NSImage(size: NSSize(width: size, height: size))
        img.addRepresentation(NSBitmapImageRep(cgImage: cgImage))
        return img
    }
}
