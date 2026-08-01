import SwiftUI
import Sync

public struct SettingsView: View {
    @AppStorage(Config.webhookURLDefaultsKey) private var webhookURL: String = ""

    public init() {}

    public var body: some View {
        Form {
            Section("Vento") {
                TextField("Webhook URL", text: $webhookURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
            }
        }
        .navigationTitle("Settings")
    }
}
