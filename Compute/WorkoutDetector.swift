import Foundation

public struct WorkoutSession: Codable, Equatable, Sendable {
    public let start: Date
    public let end: Date
    public let averageHR: Double
    public let strain: Double

    public init(start: Date, end: Date, averageHR: Double, strain: Double) {
        self.start = start
        self.end = end
        self.averageHR = averageHR
        self.strain = strain
    }
}

public enum WorkoutDetector {
    public static func detect(samples: [HeartRateSample], movement: [Double], restingHR: Double, maxHR: Double, sex: BiologicalSex, minDuration: TimeInterval = 10 * 60) -> [WorkoutSession] {
        guard samples.count >= 2 else { return [] }
        let movementByIndex = movement.isEmpty ? Array(repeating: 1.0, count: samples.count) : movement
        let threshold = restingHR + 0.50 * (maxHR - restingHR)
        var sessions: [WorkoutSession] = []
        var current: [HeartRateSample] = []

        for (index, sample) in samples.enumerated() {
            let motion = index < movementByIndex.count ? movementByIndex[index] : 0
            let active = sample.bpm >= threshold && motion >= 0.20
            if active {
                current.append(sample)
            } else {
                appendSessionIfNeeded(current, to: &sessions, restingHR: restingHR, maxHR: maxHR, sex: sex, minDuration: minDuration)
                current.removeAll()
            }
        }
        appendSessionIfNeeded(current, to: &sessions, restingHR: restingHR, maxHR: maxHR, sex: sex, minDuration: minDuration)
        return sessions
    }

    private static func appendSessionIfNeeded(_ samples: [HeartRateSample], to sessions: inout [WorkoutSession], restingHR: Double, maxHR: Double, sex: BiologicalSex, minDuration: TimeInterval) {
        guard let first = samples.first, let last = samples.last else { return }
        guard last.timestamp.timeIntervalSince(first.timestamp) >= minDuration else { return }
        let avg = samples.map(\.bpm).reduce(0, +) / Double(samples.count)
        let trimp = StrainScorer.trimp(samples: samples, restingHR: restingHR, maxHR: maxHR, sex: sex)
        sessions.append(WorkoutSession(start: first.timestamp, end: last.timestamp, averageHR: avg, strain: StrainScorer.strainScore(fromTRIMP: trimp)))
    }
}
