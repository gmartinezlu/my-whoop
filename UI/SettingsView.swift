import SwiftUI
import Sync

public struct SettingsView: View {
    @AppStorage(Config.webhookURLDefaultsKey) private var webhookURL: String = ""

    public init() {}

    public var body: some View {
        Form {
            Section("Webhook de Vento") {
                LabeledContent("Estado", value: webhookStatus)
                TextField("Webhook URL", text: $webhookURL)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif
                    .autocorrectionDisabled()
                Button("Usar webhook de mywhoop") {
                    webhookURL = Config.defaultVentoWebhookURLString
                }
                Button("Limpiar webhook", role: .destructive) {
                    webhookURL = ""
                }
                Text("Este webhook guarda tus metricas en Vento en la base whoop_daily_metrics.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Ajustes")
    }

    private var webhookStatus: String {
        guard !webhookURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "No configurado"
        }
        return URL(string: webhookURL) == nil ? "URL invalida" : "Configurado"
    }
}
