import BLE
import SwiftUI

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
            ScrollView {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.18), lineWidth: 18)
                        Circle()
                            .trim(from: 0, to: CGFloat(min(max(recoveryScore, 0), 100)) / 100)
                            .stroke(recoveryColor, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 4) {
                            Text("\(recoveryScore)")
                                .font(.system(size: 56, weight: .semibold, design: .rounded))
                            Text("Recovery")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 220, height: 220)

                    summaryPanel
                    controls
                    discoveryPanel
                    gattPanel
                    rawCapturePanel
                }
                .padding()
            }
            .navigationTitle("Today")
            .toolbar {
                NavigationLink("Settings") {
                    SettingsView()
                }
            }
        }
    }

    private var summaryPanel: some View {
        VStack(spacing: 14) {
            metricRow(title: "Live HR", value: (bleManager.liveHeartRate ?? liveHeartRate).map { "\($0) bpm" } ?? "--")
            metricRow(title: "Live HRV", value: bleManager.latestRMSSD.map { "\(Int(round($0))) ms RMSSD" } ?? "--")
            metricRow(title: "Band", value: bleManager.state.rawValue)
            metricRow(title: "Last Vento sync", value: lastSyncDescription)
            metricRow(title: "Pending queue", value: "\(pendingOutboxCount)")
            if let lastError = bleManager.lastError {
                metricRow(title: "BLE note", value: lastError)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var controls: some View {
        HStack {
            Button("Scan") {
                bleManager.scan()
            }
            .buttonStyle(.borderedProminent)

            Button("Disconnect") {
                bleManager.disconnect()
            }
            .buttonStyle(.bordered)
        }
    }

    private var discoveryPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nearby bands")
                .font(.headline)
            if bleManager.discoveredPeripherals.isEmpty {
                Text("Tap Scan, then choose the WHOOP entry when it appears.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(bleManager.discoveredPeripherals) { peripheral in
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
                                if !peripheral.serviceUUIDs.isEmpty {
                                    Text(peripheral.serviceUUIDs.joined(separator: ", "))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            Spacer()
                            Text("\(peripheral.rssi) dBm")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var gattPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GATT report")
                .font(.headline)
            if bleManager.gattServices.isEmpty {
                Text("Services and characteristics will appear after connection.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(bleManager.gattServices) { service in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(service.uuid)
                            .font(.caption.weight(.semibold))
                        ForEach(service.characteristics) { characteristic in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(characteristic.uuid)
                                    .font(.caption2)
                                Text(characteristic.properties.joined(separator: ", "))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if characteristic.isNotifying {
                                    Text("notifying")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var rawCapturePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Raw notifications")
                .font(.headline)
            if bleManager.rawNotifications.isEmpty {
                Text("Subscribed notify/indicate payloads will be captured here as hex.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(bleManager.rawNotifications.prefix(20)) { notification in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(notification.characteristicUUID)
                            .font(.caption2.weight(.semibold))
                        Text(notification.hexPayload)
                            .font(.system(.caption2, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var recoveryColor: Color {
        switch recoveryScore {
        case 67...100: return .green
        case 34...66: return .yellow
        default: return .red
        }
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}
