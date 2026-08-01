import Foundation

public struct HeartRateSample: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let bpm: Double

    public init(timestamp: Date, bpm: Double) {
        self.timestamp = timestamp
        self.bpm = bpm
    }
}

public enum BiologicalSex: String, Codable, Sendable {
    case female
    case male
}

public enum StrainScorer {
    public static func trimp(samples: [HeartRateSample], restingHR: Double, maxHR: Double, sex: BiologicalSex) -> Double {
        guard samples.count >= 2, maxHR > restingHR else { return 0 }
        let factorA = sex == .male ? 0.64 : 0.86
        let factorB = sex == .male ? 1.92 : 1.67

        var total = 0.0
        for pair in zip(samples, samples.dropFirst()) {
            let minutes = max(pair.1.timestamp.timeIntervalSince(pair.0.timestamp) / 60.0, 0)
            let averageHR = (pair.0.bpm + pair.1.bpm) / 2.0
            let hrReserve = min(max((averageHR - restingHR) / (maxHR - restingHR), 0), 1)
            // Banister TRIMP: duration * HR reserve * A * exp(B * HR reserve).
            total += minutes * hrReserve * factorA * exp(factorB * hrReserve)
        }
        return total
    }

    public static func strainScore(fromTRIMP trimp: Double) -> Double {
        // Log compression maps open-ended TRIMP to a 0...21 daily strain scale.
        min(21.0, max(0.0, log1p(max(trimp, 0)) / log(301.0) * 21.0))
    }
}
