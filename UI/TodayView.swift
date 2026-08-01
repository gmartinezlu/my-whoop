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
            VStack(spacing: 28) {
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

                VStack(spacing: 14) {
                    metricRow(title: "Live HR", value: liveHeartRate.map { "\($0) bpm" } ?? "--")
                    metricRow(title: "Band", value: bleManager.state.rawValue)
                    metricRow(title: "Last Vento sync", value: lastSyncDescription)
                    metricRow(title: "Pending queue", value: "\(pendingOutboxCount)")
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

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

                Spacer()
            }
            .padding()
            .navigationTitle("Today")
            .toolbar {
                NavigationLink("Settings") {
                    SettingsView()
                }
            }
        }
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
