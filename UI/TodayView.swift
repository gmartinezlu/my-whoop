import BLE
import SwiftUI
import Sync

public struct TodayView: View {
    @ObservedObject private var bleManager: BLEManager
    private let recoveryScore: Int
    private let liveHeartRate: Int?
    private let lastSyncDescription: String
    private let pendingOutboxCount: Int

    public init(
        bleManager: BLEManager,
        recoveryScore: Int = 0,
        liveHeartRate: Int? = nil,
        lastSyncDescription: String = "Never",
        pendingOutboxCount: Int = 0
    ) {
        self.bleManager = bleManager
        self.recoveryScore = recoveryScore
        self.liveHeartRate = liveHeartRate
        self.lastSyncDescription = lastSyncDescription
        self.pendingOutboxCount = pendingOutboxCount
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.10, green: 0.15, blue: 0.16), Color(red: 0.02, green: 0.04, blue: 0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        header
                        scoreRow
                        coachCard
                        daySection
                        sleepCard
                        syncCard
                        bleDiscoveryCard
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
            }
            .toolbar {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 34, weight: .medium))
            Spacer()
            HStack(spacing: 14) {
                Image(systemName: "chevron.left")
                    .foregroundStyle(.secondary)
                Text("HOY")
                    .font(.subheadline.weight(.bold))
                    .tracking(1.5)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.08), in: Capsule())
            Spacer()
            HStack(spacing: 5) {
                Text(bandBatteryText)
                    .font(.caption.weight(.semibold))
                Image(systemName: "battery.75")
                    .foregroundStyle(.mint)
            }
        }
        .foregroundStyle(.white)
    }

    private var scoreRow: some View {
        HStack(alignment: .top, spacing: 18) {
            statusRing(title: "SUEÑO", value: "--", progress: 0, color: .cyan)
            statusRing(title: "RECUPERACIÓN", value: recoveryDisplay, progress: Double(max(recoveryScore, 0)) / 100, color: recoveryColor)
            statusRing(title: "ESFUERZO", value: strainDisplay, progress: min(Double(max(bleManager.liveHeartRate ?? 0, 0)) / 190, 1), color: .orange)
        }
    }

    private var coachCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Coach", systemImage: "sparkles")
                        .font(.headline.weight(.semibold))
                    Spacer()
                    Text("LOCAL")
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(.mint)
                }
                Text(coachMessage)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
                Text("El coach usa reglas locales por ahora; no envía datos a IA externa.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var daySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Mi día")
                    .font(.title2.weight(.bold))
                Spacer()
                Button {
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .frame(width: 48, height: 48)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
            }

            card {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("ACTIVIDADES DE HOY")
                            .font(.caption.weight(.bold))
                            .tracking(1.8)
                        Spacer()
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 12) {
                        actionPill(icon: "plus", title: "AGREGAR")
                        actionPill(icon: "stopwatch", title: "INICIAR")
                    }
                    HStack {
                        metricBlock(title: "PASOS", value: "\(bleManager.stepCount)")
                        metricBlock(title: "HR EN VIVO", value: currentHeartRateText)
                    }
                }
            }
        }
    }

    private var sleepCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("EL SUEÑO DE ESTA NOCHE")
                        .font(.caption.weight(.bold))
                        .tracking(1.5)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    metricBlock(title: "OBJETIVO", value: "8:00")
                    Spacer()
                    metricBlock(title: "BANDA", value: bleManager.state.rawValue.uppercased())
                }
                Button {
                } label: {
                    Label("EDITAR ALARMA", systemImage: "pencil")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var syncCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Label("Vento Sync", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline.weight(.semibold))
                metricRow(title: "Último envío", value: syncStatusText)
                metricRow(title: "Pendientes", value: "\(pendingOutboxCount)")
                metricRow(title: "Webhook", value: Config.webhookURL == nil ? "No configurado" : "Configurado")
            }
        }
    }

    private var bleDiscoveryCard: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("BLE", systemImage: "dot.radiowaves.left.and.right")
                        .font(.headline.weight(.semibold))
                    Spacer()
                    Button("Scan") {
                        bleManager.scan()
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Disconnect") {
                        bleManager.disconnect()
                    }
                    .buttonStyle(.bordered)
                }

                if let lastError = bleManager.lastError {
                    Text(lastError)
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }

                if bleManager.discoveredPeripherals.isEmpty {
                    Text("Toca Scan y elige tu banda cuando aparezca.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(bleManager.discoveredPeripherals.prefix(5))) { peripheral in
                        Button {
                            bleManager.connect(to: peripheral.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(peripheral.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text(peripheral.id.uuidString)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text("\(peripheral.rssi) dBm")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        Divider().background(Color.white.opacity(0.08))
                    }
                }

                if !bleManager.gattServices.isEmpty {
                    Text("GATT: \(bleManager.gattServices.count) servicios encontrados")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.mint)
                }

                if !bleManager.rawNotifications.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RAW")
                            .font(.caption.weight(.bold))
                            .tracking(1.4)
                        ForEach(Array(bleManager.rawNotifications.prefix(4))) { notification in
                            Text("\(notification.characteristicUUID): \(notification.hexPayload)")
                                .font(.system(.caption2, design: .monospaced))
                                .lineLimit(2)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
    }

    private func statusRing(title: String, value: String, progress: Double, color: Color) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 88, height: 88)
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.15, green: 0.18, blue: 0.19).opacity(0.96), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
    }

    private func actionPill(icon: String, title: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.bold))
            .tracking(1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }

    private func metricBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
            Text(title)
                .font(.caption2.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(.secondary)
        }
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private var currentHeartRateText: String {
        (bleManager.liveHeartRate ?? liveHeartRate).map { "\($0)" } ?? "--"
    }

    private var recoveryDisplay: String {
        recoveryScore > 0 ? "\(recoveryScore)%" : "--%"
    }

    private var strainDisplay: String {
        guard let heartRate = bleManager.liveHeartRate else { return "--" }
        return heartRate >= 120 ? "ALTA" : "BAJA"
    }

    private var bandBatteryText: String {
        bleManager.batteryPercent.map { "\($0)%" } ?? "--%"
    }

    private var syncStatusText: String {
        if Config.webhookURL == nil {
            return "Configura webhook"
        }
        return lastSyncDescription == "Never" ? "Sin envíos aún" : lastSyncDescription
    }

    private var coachMessage: String {
        if Config.webhookURL == nil {
            return "Configura Vento para guardar tus métricas. Después de conectar la banda, el resumen diario podrá enviarse automáticamente."
        }
        if let rmssd = bleManager.latestRMSSD, rmssd < 25 {
            return "HRV bajo ahora mismo. Prioriza movilidad, zona 2 suave o descanso activo hasta tener más datos del día."
        }
        if let heartRate = bleManager.liveHeartRate, heartRate > 110 {
            return "Tu frecuencia está elevada. Si estás entrenando, mantén el bloque; si estás en reposo, espera a recuperar antes de alta intensidad."
        }
        if recoveryScore >= 67 {
            return "Buen día para entrenar fuerte si dormiste bien. Calienta progresivo y revisa strain después de la sesión."
        }
        if recoveryScore > 0 {
            return "Día moderado. Entrena técnica, fuerza controlada o cardio suave según cómo te sientas."
        }
        return "Conecta la banda para medir HR/HRV en vivo. Con esos datos puedo darte una recomendación más útil para hoy."
    }

    private var recoveryColor: Color {
        switch recoveryScore {
        case 67...100: return .mint
        case 34...66: return .yellow
        default: return .red
        }
    }
}
