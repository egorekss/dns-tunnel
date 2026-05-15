import SwiftUI

struct ServersView: View {
    @EnvironmentObject var store: ServerStore
    @State private var sheetServer: ServerConfig?
    @State private var pendingDelete: ServerConfig?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Servers")
                    .font(.headline)
                Spacer()
                Button {
                    sheetServer = ServerConfig()
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if store.servers.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "server.rack")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No servers yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Press “+ Add” to enter your iodined server parameters.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.servers) { server in
                        ServerRow(server: server,
                                  isSelected: (store.selectedID ?? store.servers.first?.id) == server.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                store.selectedID = server.id
                            }
                            .contextMenu {
                                Button("Make active") { store.selectedID = server.id }
                                Button("Edit") { sheetServer = server }
                                Divider()
                                Button("Delete", role: .destructive) { pendingDelete = server }
                            }
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(item: $sheetServer) { server in
            ServerEditView(server: server) { saved in
                if store.servers.contains(where: { $0.id == saved.id }) {
                    store.update(saved)
                } else {
                    store.add(saved)
                }
                sheetServer = nil
            } onCancel: {
                sheetServer = nil
            }
            .frame(width: 460, height: 380)
        }
        .alert(item: $pendingDelete) { server in
            Alert(
                title: Text("Delete “\(server.name)”?"),
                message: Text("Server will be removed from the list."),
                primaryButton: .destructive(Text("Delete")) { store.delete(server.id) },
                secondaryButton: .cancel(Text("Cancel"))
            )
        }
    }
}

struct ServerRow: View {
    let server: ServerConfig
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.6))
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text("\(server.domain) • \(server.serverIP)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
