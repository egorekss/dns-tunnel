import SwiftUI

struct ContentView: View {
    @State private var selection: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selection) {
                Text("Connection").tag(0)
                Text("Servers").tag(1)
                Text("Settings").tag(2)
                Text("About").tag(3)
            }
            .pickerStyle(.segmented)
            .labelStyle(.titleOnly)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()

            Group {
                switch selection {
                case 0: StatusView()
                case 1: ServersView()
                case 2: SettingsView()
                default: AboutView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
