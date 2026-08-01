import BLE
import SwiftUI
import Sync

public struct TodayView: View {
    @ObservedObject private var bleManager: BLEManager
    @StateObject private var stepCounter = DeviceStepCounter()

    private let recoveryScore: Int
    private let liveHeartRate: Int?
    private let lastSyncDescription: String
    private let pendingOutboxCount: Int

    public init(
        bleManager: BLEManager,
        recoveryScore: Int = 0,
        liveHeartRate: Int? = nil,
        lastSyncDescription: String = "Sin envios",
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
                appBackground

                ScrollView {
                    VStack(spacing: 22) {
                        topBar
                        brandMark
                        scoreRow
                        coachCard
                        daySection
                        sleepCard
                        syncCard
                        bleDiscoveryCard
                        bottomNav
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 26)
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
        .onAppear {
            stepCounter.start()
        }
    }

    private var appBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.13, green: 0.18, blue: 0.19),
                Color(red: 0.05, green: 0.08, blue: 0.09),
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 34, weight: .medium))

            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.secondary)
                Text(strainDisplay)
                    .font(.subheadline.weight(.bold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.08), in: Capsule())

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
            .background(Color.white.opacity(0.09), in: Capsule())

            Spacer()

            HStack(spacing: 5) {
                Text(bandBatteryText)
                    .font(.caption.weight(.semibold))
                Image(systemName: batteryIcon)
                    .foregroundStyle(batteryColor)
            }
        }
        .foregroundStyle(.white)
    }

    private var brandMark: some View {
        Text("MYWHOOP")
            .font(.system(size: 24, weight: .medium, design: .rounded))
            .tracking(3)
            .foregroundStyle(.white.opacity(0.13))
            .frame(maxWidth: .infinity)
            .padding(.top, -4)
    }

    private var scoreRow: some View {
        HStack(alignment: .top, spacing: 18) {
            statusRing(title: "SUEÑO", value: "--%", progress: 0, color: .cyan)
            statusRing(title: "RECUPERACIÓN", value: recoveryDisplay, progress: Double(max(recoveryScore, 0)) / 100, color: recoveryColor)
            statusRing(title: "ESFUERZO", value: strainDisplay, progress: strainProgress, color: .orange)
        }
        .padding(.top, 14)
    }

    private var coachCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Coach diario", systemImage: "sparkles")
                        .font(.headline.weight(.bold))
                    Spacer()
                    Text("LOCAL")
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(.mint)
                }
                Text(coachMessage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.94))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Puede convertirse en IA real usando tu backend Vento, pero eso agregaria una llamada de red adicional que todavia no esta permitida por los requisitos originales.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var daySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Mi dia")
                    .font(.title.weight(.bold))
                Spacer()
                Button {
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.bold))
                        .frame(width: 52, height: 52)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
            }

            card {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("ACTIVIDADES DE HOY")
                            .font(.caption.weight(.bold))
                            .tracking(1.8)
                        Spacer()
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        actionPill(icon: "plus", title: "AGREGAR ACTIVIDAD")
                        actionPill(icon: "stopwatch", title: "INICIAR")
                    }

                    HStack(spacing: 18) {
                        metricBlock(title: "PASOS", value: stepsText, footnote: stepCounter.status)
                        metricBlock(title: "HR EN VIVO", value: currentHeartRateText, footnote: hrvText)
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

                HStack(alignment: .top) {
                    metricBlock(title: "OBJETIVO", value: "8:00", footnote: "Hora recomendada")
                    Spacer()
                    metricBlock(title: "BANDA", value: connectionDisplay, footnote: batteryFootnote)
                }

                Button {
                } label: {
                    Label("EDITAR ALARMA", systemImage: "pencil")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var syncCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Label("Vento Sync", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline.weight(.bold))
                metricRow(title: "Ultimo envio", value: syncStatusText)
                metricRow(title: "Pendientes", value: "\(pendingOutboxCount)")
                metricRow(title: "Webhook", value: Config.webhookURL == nil ? "No configurado" : "Configurado")
            }
        }
    }

    private var bleDiscoveryCard: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Banda Bluetooth", systemImage: "dot.radiowaves.left.and.right")
                        .font(.headline.weight(.bold))
                    Spacer()
                    Button("Scan") {
                        bleManager.scan()
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Off") {
                        bleManager.disconnect()
                    }
                    .buttonStyle(.bordered)
                }

                if let authenticationNotice = bleManager.authenticationNotice {
                    noticeRow(icon: "lock.fill", text: authenticationNotice, color: .yellow)
                }

                if let lastError = bleManager.lastError {
                    noticeRow(icon: "exclamationmark.triangle.fill", text: lastError, color: .orange)
                }

                if bleManager.discoveredPeripherals.isEmpty {
                    Text("Toca Scan y elige tu banda cuando aparezca. Si WHOOP protege sus caracteristicas privadas, la app solo podra leer servicios publicos como HR/RR y bateria cuando existan.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(Array(bleManager.discoveredPeripherals.prefix(6))) { peripheral in
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
                        Text("RAW NOTIFICATIONS")
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

    private var bottomNav: some View {
        HStack {
            navItem(icon: "house", title: "Inicio", active: true)
            navItem(icon: "heart.text.square", title: "Salud", active: false)
            navItem(icon: "person.3", title: "Comunidad", active: false)
            navItem(icon: "line.3.horizontal", title: "Mas", active: false)
        }
        .padding(12)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
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
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 90, height: 90)
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.15, green: 0.18, blue: 0.19).opacity(0.97), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
    }

    private func actionPill(icon: String, title: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.bold))
            .tracking(0.8)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 8))
    }

    private func metricBlock(title: String, value: String, footnote: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.title2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(.secondary)
            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func noticeRow(icon: String, text: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func navItem(icon: String, title: String, active: Bool) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
            Text(title)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(active ? .white : .secondary)
        .frame(maxWidth: .infinity)
    }

    private var currentHeartRateText: String {
        (bleManager.liveHeartRate ?? liveHeartRate).map { "\($0)" } ?? "--"
    }

    private var hrvText: String {
        bleManager.latestRMSSD.map { "HRV \(Int(round($0))) ms" } ?? "HRV pendiente"
    }

    private var recoveryDisplay: String {
        recoveryScore > 0 ? "\(recoveryScore)%" : "--%"
    }

    private var strainDisplay: String {
        guard let heartRate = bleManager.liveHeartRate else { return "0" }
        return heartRate >= 150 ? "ALTO" : heartRate >= 115 ? "MED" : "BAJO"
    }

    private var strainProgress: Double {
        min(Double(max(bleManager.liveHeartRate ?? 0, 0)) / 190, 1)
    }

    private var bandBatteryText: String {
        bleManager.batteryPercent.map { "\($0)%" } ?? "--%"
    }

    private var batteryIcon: String {
        guard let battery = bleManager.batteryPercent else { return "battery.0percent" }
        switch battery {
        case 75...100: return "battery.100percent"
        case 35..<75: return "battery.50percent"
        default: return "battery.25percent"
        }
    }

    private var batteryColor: Color {
        bleManager.batteryPercent == nil ? Color.secondary : Color.mint
    }

    private var batteryFootnote: String {
        bleManager.batteryPercent.map { "Bateria \($0)%" } ?? "Bateria no expuesta"
    }

    private var stepsText: String {
        let steps = stepCounter.steps + bleManager.stepCount
        return steps > 0 ? steps.formatted() : "--"
    }

    private var connectionDisplay: String {
        switch bleManager.state {
        case .disconnected: return "OFF"
        case .connecting: return "BUSCANDO"
        case .connected: return "LINK"
        case .syncing: return "SYNC"
        case .live: return "LIVE"
        }
    }

    private var syncStatusText: String {
        if Config.webhookURL == nil {
            return "Configura webhook"
        }
        let normalized = lastSyncDescription.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty || normalized == "never" || normalized == "sin envios" {
            return "Pendiente de primera medicion"
        }
        return lastSyncDescription
    }

    private var coachMessage: String {
        if Config.webhookURL == nil {
            return "Configura Vento para guardar tus metricas. Despues de conectar la banda, el resumen diario podra enviarse cuando haya datos suficientes."
        }
        if let rmssd = bleManager.latestRMSSD, rmssd < 25 {
            return "HRV bajo ahora mismo. Prioriza movilidad, zona 2 suave o descanso activo hasta tener mas datos del dia."
        }
        if let heartRate = bleManager.liveHeartRate, heartRate > 110 {
            return "Tu frecuencia esta elevada. Si estas entrenando, mantén el bloque; si estas en reposo, espera a recuperar antes de alta intensidad."
        }
        if recoveryScore >= 67 {
            return "Buen dia para entrenar fuerte si dormiste bien. Calienta progresivo y revisa strain despues de la sesion."
        }
        if recoveryScore > 0 {
            return "Dia moderado. Entrena tecnica, fuerza controlada o cardio suave segun como te sientas."
        }
        return "Conecta la banda para medir HR/HRV en vivo. Con esos datos puedo darte una recomendacion mas util para hoy."
    }

    private var recoveryColor: Color {
        switch recoveryScore {
        case 67...100: return .mint
        case 34...66: return .yellow
        default: return .red
        }
    }
}
