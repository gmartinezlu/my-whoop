import Foundation

public enum SleepStage: String, Codable, Equatable, Sendable {
    case awake
    case light
    case deep
    case rem
}

public struct SleepEpoch: Codable, Equatable, Sendable {
    public let start: Date
    public let durationSeconds: TimeInterval
    public let stage: SleepStage

    public init(start: Date, durationSeconds: TimeInterval, stage: SleepStage) {
        self.start = start
        self.durationSeconds = durationSeconds
        self.stage = stage
    }
}

public struct SleepSummary: Codable, Equatable, Sendable {
    public let sleepHours: Double
    public let efficiencyPercent: Double
    public let epochs: [SleepEpoch]
}

public enum SleepStager {
    public static func stage(samples: [HeartRateSample], movement: [Double], restingHR: Double, epochSeconds: TimeInterval = 30) -> SleepSummary {
        guard !samples.isEmpty else {
            return SleepSummary(sleepHours: 0, efficiencyPercent: 0, epochs: [])
        }

        let movementByIndex = movement.isEmpty ? Array(repeating: 0.0, count: samples.count) : movement
        let epochs = samples.enumerated().map { index, sample in
            let motion = index < movementByIndex.count ? movementByIndex[index] : 0
            let stage: SleepStage
            // Public actigraphy tradition: movement strongly identifies wake; HR near/below
            // resting supports deeper sleep, while quiet sleep with mildly elevated HR is REM-like.
            // See Cole et al., 1992 for movement-based sleep/wake scoring; this is a simple heuristic.
            if motion > 0.35 {
                stage = .awake
            } else if sample.bpm <= restingHR + 3 {
                stage = .deep
            } else if sample.bpm >= restingHR + 12 {
                stage = .rem
            } else {
                stage = .light
            }
            return SleepEpoch(start: sample.timestamp, durationSeconds: epochSeconds, stage: stage)
        }

        let asleepSeconds = epochs.filter { $0.stage != .awake }.reduce(0) { $0 + $1.durationSeconds }
        let totalSeconds = epochs.reduce(0) { $0 + $1.durationSeconds }
        let efficiency = totalSeconds > 0 ? asleepSeconds / totalSeconds * 100.0 : 0
        return SleepSummary(sleepHours: asleepSeconds / 3600.0, efficiencyPercent: efficiency, epochs: epochs)
    }
}
