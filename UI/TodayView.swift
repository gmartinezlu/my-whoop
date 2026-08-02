import BLE
import Combine
import Compute
import SwiftUI
import Sync

public struct TodayView: View {
    @ObservedObject private var bleManager: BLEManager
    @StateObject private var stepCounter = DeviceStepCounter()
    @StateObject private var healthStore = HealthMetricsStore()
    @AppStorage("mywhoop.moodEntries") private var moodEntriesRaw: String = "[]"
    @State private var workoutActive = false
    @State private var activeWorkoutSamples: [HeartRateSample] = []
    @State private var activeWorkoutMovement: [Double] = []
    @State private var completedWorkouts: [WorkoutSession] = []
    @State private var dailyHeartRateSamples: [HeartRateSample] = []
    @State private var dailyMovementSamples: [Double] = []
    @State private var lastSampledStepCount = 0
    @State private var previousConnectionState: BLEConnectionState = .disconnected
    @State private var selectedMoodScore = 3
    @State private var ecgPoints: [Double] = Array(repeating: 0.50, count: 72)

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
                        liveHealthCard
                        daySection
                        insightsCard
                        sleepCard
                        cycleCard
                        emotionalHealthCard
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
            ConnectionAlertManager.requestPermission()
            stepCounter.start()
            healthStore.start()
            previousConnectionState = bleManager.state
        }
        .onReceive(sampleTimer) { _ in
            recordLiveSample()
        }
        .onChange(of: bleManager.state) { newState in
            handleConnectionChange(newState)
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
            statusRing(title: "SUEÑO", value: sleepRingText, progress: sleepProgress, color: .cyan)
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
                        actionButton(icon: "plus", title: "AGREGAR", action: finishWorkout)
                        actionButton(icon: workoutActive ? "stop.circle" : "stopwatch", title: workoutActive ? "FINALIZAR" : "INICIAR", action: toggleWorkout)
                    }

                HStack(spacing: 18) {
                        metricBlock(title: "PASOS", value: stepsText, footnote: stepsFootnote)
                        metricBlock(title: "HR EN VIVO", value: currentHeartRateText, footnote: workoutStatusText)
                    }

                    if !completedWorkouts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SESIONES")
                                .font(.caption2.weight(.bold))
                                .tracking(1.4)
                                .foregroundStyle(.secondary)
                            ForEach(Array(completedWorkouts.enumerated()), id: \.offset) { _, session in
                                metricRow(title: workoutTimeRange(session), value: "HR \(Int(round(session.averageHR))) · strain \(String(format: "%.1f", session.strain))")
                            }
                        }
                    }
                }
            }
        }
    }

    private var liveHealthCard: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Label("Salud en vivo", systemImage: "waveform.path.ecg")
                        .font(.headline.weight(.bold))
                    Spacer()
                    Text(connectionDisplay)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(bleManager.state == .live ? .mint : .orange)
                }

                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(currentHeartRateText)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("LPM")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(hrvText)
                            .font(.subheadline.weight(.bold))
                        Text(batteryFootnote)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                ECGWaveform(points: ecgPoints)
                    .stroke(Color.mint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .frame(height: 76)
                    .background(Color.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 8))

                noticeRow(icon: "heart.fill", text: "La linea ECG es una visualizacion de pulso calculada desde HR/RR BLE; no es un electrocardiograma medico de una derivacion.", color: Color.secondary)
            }
        }
    }

    private var insightsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Mi panel de control")
                        .font(.title2.weight(.bold))
                    Spacer()
                    Text(healthStore.status.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(healthStore.status.contains("activo") ? .mint : .orange)
                }

                dashboardRow(icon: "waveform.path.ecg", title: "Variabilidad de la frecuencia cardiaca", value: hrvText)
                dashboardRow(icon: "figure.walk", title: "Pasos", value: stepsText)
                dashboardRow(icon: "lungs", title: "VO2 max", value: vo2Text)
                dashboardRow(icon: "flame", title: "Calorias activas", value: caloriesText)
                dashboardRow(icon: "dumbbell", title: "Tiempo de actividad de fuerza", value: strengthText)
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

                HStack(alignment: .top, spacing: 18) {
                    metricBlock(title: "DURACION", value: sleepDurationText, footnote: "\(awakeningsCount) despertares")
                    Spacer()
                    metricBlock(title: "EFICIENCIA", value: sleepEfficiencyText, footnote: "Estimacion HR + movimiento")
                }

                HStack(spacing: 8) {
                    ForEach(Array(sleepStageFractions.enumerated()), id: \.offset) { _, item in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(stageColor(item.stage))
                                .frame(height: max(12, 52 * item.fraction))
                            Text(item.stage.rawValue.uppercased())
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, alignment: .bottom)
                    }
                }

                noticeRow(icon: "moon.zzz.fill", text: "Para medir toda la noche, la app necesita recibir HR/RR/movimiento mientras duermes. Si WHOOP protege esos datos privados, la app solo puede estimar con datos disponibles.", color: .cyan)
            }
        }
    }

    private var emotionalHealthCard: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Salud emocional", systemImage: "brain.head.profile")
                        .font(.headline.weight(.bold))
                    Spacer()
                    Text(moodTrend)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.mint)
                }

                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { score in
                        Button {
                            selectedMoodScore = score
                        } label: {
                            Text(moodLabel(score))
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selectedMoodScore == score ? Color.mint.opacity(0.25) : Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    addMoodEntry()
                } label: {
                    Label("GUARDAR ESTADO DE ANIMO", systemImage: "checkmark")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                if moodEntries.isEmpty {
                    Text("Registra tu estado de animo para ver si tu semana esta optima, estable o fluctuante.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(Array(moodEntries.suffix(10))) { entry in
                            VStack(spacing: 5) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(moodColor(entry.moodScore))
                                    .frame(height: CGFloat(entry.moodScore) * 16)
                                Text("\(entry.moodScore)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 96, alignment: .bottom)
                }
            }
        }
    }

    private var cycleCard: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Ciclo menstrual", systemImage: "calendar")
                        .font(.headline.weight(.bold))
                    Spacer()
                    Text(healthStore.cycleSummary.status.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(healthStore.cycleSummary.currentDay == nil ? .orange : .mint)
                }

                HStack(alignment: .top, spacing: 18) {
                    metricBlock(title: "DIA DEL CICLO", value: cycleDayText, footnote: healthStore.cycleSummary.phase)
                    metricBlock(title: "PROXIMO PERIODO", value: nextPeriodText, footnote: daysUntilPeriodText)
                }

                cyclePhaseStrip

                Text(healthStore.cycleSummary.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var syncCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Webhook de Vento", systemImage: "paperplane.circle")
                        .font(.headline.weight(.bold))
                    Spacer()
                    Text(Config.webhookURL == nil ? "OFF" : "ON")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Config.webhookURL == nil ? .orange : .mint)
                }
                metricRow(title: "Ultimo envio", value: syncStatusText)
                metricRow(title: "Pendientes", value: "\(pendingOutboxCount)")
                metricRow(title: "Destino", value: webhookDestinationText)

                NavigationLink {
                    SettingsView()
                } label: {
                    Label(Config.webhookURL == nil ? "CONFIGURAR WEBHOOK" : "EDITAR WEBHOOK", systemImage: "link")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
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

    private func actionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            actionPill(icon: icon, title: title)
        }
        .buttonStyle(.plain)
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

    private func dashboardRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26)
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline.weight(.bold))
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
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
        dailyStrain > 0 ? String(format: "%.1f", dailyStrain) : "0"
    }

    private var strainProgress: Double {
        min(dailyStrain / 21, 1)
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
        let steps = healthStore.healthStepsToday ?? (stepCounter.steps + bleManager.stepCount)
        return steps > 0 ? steps.formatted() : "--"
    }

    private var stepsFootnote: String {
        healthStore.healthStepsToday == nil ? stepCounter.status : "Apple Health"
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

    private var webhookDestinationText: String {
        guard let host = Config.webhookURL?.host else {
            return "Sin URL"
        }
        return host
    }

    private var coachMessage: String {
        if Config.webhookURL == nil {
            return "Configura Vento para guardar tus metricas. Despues de conectar la banda, el resumen diario podra enviarse cuando haya datos suficientes."
        }
        if workoutActive {
            return "Actividad en curso. Mantén la intensidad si puedes hablar en frases cortas; baja el ritmo si HR sube sin movimiento o te sientes fatigado."
        }
        if dailyStrain >= 14 {
            return "Ya acumulaste strain alto hoy. Prioriza recuperacion, hidratacion y movilidad suave."
        }
        if moodTrend == "Fluctuante" {
            return "Tu estado emocional se ve fluctuante. Mejor una sesion tecnica o zona 2 antes que maxima intensidad."
        }
        if let rmssd = bleManager.latestRMSSD, rmssd < 25 {
            return "HRV bajo ahora mismo. Prioriza movilidad, zona 2 suave o descanso activo hasta tener mas datos del dia."
        }
        if let cycleDay = healthStore.cycleSummary.currentDay, healthStore.cycleSummary.phase == "Lutea" || cycleDay <= 2 {
            return "Tu ciclo sugiere ajustar carga segun energia y sintomas. Haz fuerza controlada o cardio suave si HRV/sueno no acompañan."
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

    private var sampleTimer: Publishers.Autoconnect<Timer.TimerPublisher> {
        Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    }

    private let restingHR = 60.0
    private let maxHR = 190.0
    private let biologicalSex: BiologicalSex = .male

    private var moodEntries: [MoodEntry] {
        EmotionalJournalCodec.decode(moodEntriesRaw)
    }

    private var moodTrend: String {
        EmotionalJournalCodec.trend(entries: moodEntries)
    }

    private var dailyStrain: Double {
        let completed = completedWorkouts.map(\.strain).reduce(0, +)
        let activeTRIMP = StrainScorer.trimp(samples: activeWorkoutSamples, restingHR: restingHR, maxHR: maxHR, sex: biologicalSex)
        return min(21, completed + StrainScorer.strainScore(fromTRIMP: activeTRIMP))
    }

    private var workoutStatusText: String {
        if workoutActive {
            return "\(activeWorkoutSamples.count) muestras · \(hrvText)"
        }
        return completedWorkouts.isEmpty ? hrvText : "\(completedWorkouts.count) sesiones · \(hrvText)"
    }

    private var sleepSummary: SleepSummary {
        SleepStager.stage(samples: dailyHeartRateSamples, movement: dailyMovementSamples, restingHR: restingHR)
    }

    private var sleepRingText: String {
        if healthStore.healthSleepHours != nil {
            return "\(max(0, 100 - awakeningsCount * 6))%"
        }
        return sleepSummary.sleepHours > 0 ? "\(Int(round(sleepSummary.efficiencyPercent)))%" : "--%"
    }

    private var sleepProgress: Double {
        if healthStore.healthSleepHours != nil {
            return Double(max(0, 100 - awakeningsCount * 6)) / 100.0
        }
        return min(max(sleepSummary.efficiencyPercent / 100, 0), 1)
    }

    private var sleepDurationText: String {
        if let healthSleepHours = healthStore.healthSleepHours, healthSleepHours > 0 {
            let totalMinutes = Int(round(healthSleepHours * 60))
            return "\(totalMinutes / 60):\(String(format: "%02d", totalMinutes % 60))"
        }
        guard sleepSummary.sleepHours > 0 else { return "--" }
        let totalMinutes = Int(round(sleepSummary.sleepHours * 60))
        return "\(totalMinutes / 60):\(String(format: "%02d", totalMinutes % 60))"
    }

    private var sleepEfficiencyText: String {
        if healthStore.healthSleepHours != nil {
            return "\(max(0, 100 - awakeningsCount * 6))%"
        }
        return sleepSummary.sleepHours > 0 ? "\(Int(round(sleepSummary.efficiencyPercent)))%" : "--%"
    }

    private var awakeningsCount: Int {
        if let healthAwakenings = healthStore.healthSleepAwakenings {
            return healthAwakenings
        }
        let epochs = sleepSummary.epochs
        guard epochs.count > 1 else { return 0 }
        return zip(epochs, epochs.dropFirst()).filter { $0.stage != .awake && $1.stage == .awake }.count
    }

    private var sleepStageFractions: [(stage: SleepStage, fraction: Double)] {
        let epochs = sleepSummary.epochs
        guard !epochs.isEmpty else {
            return [(.awake, 0.05), (.light, 0.05), (.deep, 0.05), (.rem, 0.05)]
        }
        let total = Double(epochs.count)
        return [SleepStage.awake, .light, .deep, .rem].map { stage in
            let count = Double(epochs.filter { $0.stage == stage }.count)
            return (stage, max(count / total, 0.05))
        }
    }

    private func recordLiveSample() {
        let steps = stepCounter.steps + bleManager.stepCount
        let stepDelta = max(steps - lastSampledStepCount, 0)
        lastSampledStepCount = steps
        let movement = min(Double(stepDelta) / 12.0, 1.0)

        guard let heartRate = bleManager.liveHeartRate else { return }
        updateECGPoints(heartRate: heartRate)
        let sample = HeartRateSample(timestamp: Date(), bpm: Double(heartRate))
        dailyHeartRateSamples.append(sample)
        dailyMovementSamples.append(movement)

        if dailyHeartRateSamples.count > 2880 {
            dailyHeartRateSamples.removeFirst(dailyHeartRateSamples.count - 2880)
            dailyMovementSamples.removeFirst(max(dailyMovementSamples.count - 2880, 0))
        }

        if workoutActive {
            activeWorkoutSamples.append(sample)
            activeWorkoutMovement.append(movement)
        }
    }

    private func toggleWorkout() {
        workoutActive ? finishWorkout() : startWorkout()
    }

    private func startWorkout() {
        activeWorkoutSamples.removeAll()
        activeWorkoutMovement.removeAll()
        workoutActive = true
        recordLiveSample()
    }

    private func finishWorkout() {
        guard workoutActive else { return }
        workoutActive = false
        let detected = WorkoutDetector.detect(
            samples: activeWorkoutSamples,
            movement: activeWorkoutMovement,
            restingHR: restingHR,
            maxHR: maxHR,
            sex: biologicalSex,
            minDuration: 60
        )
        if let session = detected.last {
            completedWorkouts.append(session)
        } else if let first = activeWorkoutSamples.first, let last = activeWorkoutSamples.last, activeWorkoutSamples.count >= 2 {
            let averageHR = activeWorkoutSamples.map(\.bpm).reduce(0, +) / Double(activeWorkoutSamples.count)
            let trimp = StrainScorer.trimp(samples: activeWorkoutSamples, restingHR: restingHR, maxHR: maxHR, sex: biologicalSex)
            completedWorkouts.append(WorkoutSession(start: first.timestamp, end: last.timestamp, averageHR: averageHR, strain: StrainScorer.strainScore(fromTRIMP: trimp)))
        }
        activeWorkoutSamples.removeAll()
        activeWorkoutMovement.removeAll()
    }

    private func handleConnectionChange(_ newState: BLEConnectionState) {
        guard newState != previousConnectionState else { return }
        let oldState = previousConnectionState
        previousConnectionState = newState
        if newState == .live || newState == .connected {
            ConnectionAlertManager.notify(title: "Banda conectada", body: "MyWhoop esta recibiendo datos de la banda.")
        } else if oldState == .live || oldState == .connected {
            ConnectionAlertManager.notify(title: "Banda desconectada", body: "Se perdio la conexion Bluetooth con la banda.")
        }
    }

    private func addMoodEntry() {
        var entries = moodEntries
        entries.append(MoodEntry(moodScore: selectedMoodScore))
        if entries.count > 60 {
            entries.removeFirst(entries.count - 60)
        }
        moodEntriesRaw = EmotionalJournalCodec.encode(entries)
    }

    private var vo2Text: String {
        healthStore.vo2Max.map { String(format: "%.1f", $0) } ?? "--"
    }

    private var caloriesText: String {
        if let activeCalories = healthStore.activeCaloriesKcal {
            return "\(Int(round(activeCalories))) kcal"
        }
        let fallback = Double(healthStore.healthStepsToday ?? stepCounter.steps) * 0.04
        return fallback > 0 ? "\(Int(round(fallback))) kcal*" : "--"
    }

    private var strengthText: String {
        healthStore.strengthMinutes.map { "\(Int(round($0))) min" } ?? "--"
    }

    private var cycleDayText: String {
        healthStore.cycleSummary.currentDay.map { "\($0)" } ?? "--"
    }

    private var nextPeriodText: String {
        guard let next = healthStore.cycleSummary.nextPeriod else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: next)
    }

    private var daysUntilPeriodText: String {
        guard let days = healthStore.cycleSummary.daysUntilNextPeriod else {
            return "Apple Health"
        }
        if days == 0 { return "posible inicio hoy" }
        return "\(days) dias"
    }

    private var cyclePhaseStrip: some View {
        HStack(spacing: 5) {
            phaseSegment("Menstrual", color: .red, active: healthStore.cycleSummary.phase == "Menstrual")
            phaseSegment("Folicular", color: .purple, active: healthStore.cycleSummary.phase == "Folicular")
            phaseSegment("Ovulatoria", color: .cyan, active: healthStore.cycleSummary.phase == "Ovulatoria")
            phaseSegment("Lutea", color: .pink, active: healthStore.cycleSummary.phase == "Lutea")
        }
    }

    private func phaseSegment(_ title: String, color: Color, active: Bool) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(active ? 0.95 : 0.35))
                .frame(height: active ? 14 : 8)
            Text(title)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(active ? .white : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
    }

    private func updateECGPoints(heartRate: Int) {
        let normalized = min(max((Double(heartRate) - 45.0) / 120.0, 0), 1)
        let next: [Double] = [0.50, 0.48, 0.55 + normalized * 0.08, 0.18, 0.88, 0.42, 0.50, 0.53, 0.50]
        ecgPoints.append(contentsOf: next)
        if ecgPoints.count > 72 {
            ecgPoints.removeFirst(ecgPoints.count - 72)
        }
    }

    private func moodLabel(_ score: Int) -> String {
        switch score {
        case 1: return "Bajo"
        case 2: return "Tenso"
        case 3: return "Normal"
        case 4: return "Bien"
        default: return "Optimo"
        }
    }

    private func moodColor(_ score: Int) -> Color {
        switch score {
        case 1...2: return .orange
        case 3: return .yellow
        default: return .mint
        }
    }

    private func stageColor(_ stage: SleepStage) -> Color {
        switch stage {
        case .awake: return .orange
        case .light: return .cyan
        case .deep: return .blue
        case .rem: return .purple
        }
    }

    private func workoutTimeRange(_ session: WorkoutSession) -> String {
        "\(timeFormatter.string(from: session.start))-\(timeFormatter.string(from: session.end))"
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
}

private struct ECGWaveform: Shape {
    let points: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }
        let step = rect.width / CGFloat(points.count - 1)
        for index in points.indices {
            let x = CGFloat(index) * step
            let y = rect.height * CGFloat(1 - min(max(points[index], 0), 1))
            if index == points.startIndex {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}
