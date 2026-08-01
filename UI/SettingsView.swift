import SwiftUI
import Sync

public struct SettingsView: View {
    @AppStorage(Config.webhookURLDefaultsKey) private var webhookURL: String = ""

    public init() {}

    public var body: some View {
        Form {
            Section("Vento") {
                TextField("Webhook URL", text: $webhookURL)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif
                    .autocorrectionDisabled()
            }
        }
        .navigationTitle("Settings")
    }
}
