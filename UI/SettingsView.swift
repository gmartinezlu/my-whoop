import BLE
import SwiftUI
import Sync

public struct SettingsView: View {
    @AppStorage(Config.webhookURLDefaultsKey) private var webhookURL: String = ""
    @AppStorage(Config.coachURLDefaultsKey) private var coachURL: String = ""

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

            Section("Coach IA de Vento") {
                LabeledContent("Estado", value: coachStatus)
                TextField("Coach URL", text: $coachURL)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif
                    .autocorrectionDisabled()
                Button("Usar coach de mywhoop") {
                    coachURL = Config.defaultVentoCoachURLString
                }
                Button("Limpiar coach", role: .destructive) {
                    coachURL = ""
                }
                Text("Este endpoint usa Vento para generar recomendaciones con tus metricas actuales.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Log BLE crudo") {
                LabeledContent("Archivo", value: RawBLELogStore.fileName)
                ShareLink(item: RawBLELogStore.fileURL) {
                    Label("Exportar log BLE crudo", systemImage: "square.and.arrow.up")
                }
                Button("Limpiar log BLE", role: .destructive) {
                    RawBLELogStore.clear()
                }
                Text("Los frames WHOOP que no calzan con el decoder quedan guardados aqui como hex dump para ajustar el protocolo con datos reales de tu banda.")
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

    private var coachStatus: String {
        guard !coachURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "No configurado"
        }
        return URL(string: coachURL) == nil ? "URL invalida" : "Configurado"
    }
}
