import SwiftUI

struct ServerEditView: View {
    @State var server: ServerConfig
    var onSave: (ServerConfig) -> Void
    var onCancel: () -> Void
    @State private var error: String?

    var isNew: Bool { server.name.isEmpty && server.domain.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isNew ? "New server" : "Edit server")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            VStack(spacing: 12) {
                FormRow(label: "Name") {
                    TextField("My VPS", text: $server.name)
                        .textFieldStyle(.roundedBorder)
                }
                FormRow(label: "Tunnel domain") {
                    TextField("t.example.com", text: $server.domain)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                }
                FormRow(label: "Password") {
                    SecureField("iodined password", text: $server.password)
                        .textFieldStyle(.roundedBorder)
                }
                FormRow(label: "Server IP") {
                    TextField("1.2.3.4", text: $server.serverIP)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                }

                Text("Parameters come from the iodined config on the server side. See docs/server-setup.md.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
            }

            Spacer()

            Divider()

            HStack {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    if let err = server.validate() {
                        error = err
                    } else {
                        onSave(server)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}

private struct FormRow<Content: View>: View {
    let label: LocalizedStringKey
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 0) {
                Text(label)
                Text(":")
            }
            .frame(width: 130, alignment: .trailing)
            .foregroundColor(.secondary)
            content()
        }
    }
}
