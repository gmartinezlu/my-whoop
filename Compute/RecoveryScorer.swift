import Foundation

public struct RecoveryInputs: Codable, Equatable, Sendable {
    public let hrvRmssdMs: Double
    public let restingHR: Double
    public let sleepHours: Double
    public let skinTempC: Double?
    public let baselineHRV: Double
    public let baselineRestingHR: Double
    public let baselineSleepHours: Double
    public let baselineSkinTempC: Double?

    public init(hrvRmssdMs: Double, restingHR: Double, sleepHours: Double, skinTempC: Double?, baselineHRV: Double, baselineRestingHR: Double, baselineSleepHours: Double, baselineSkinTempC: Double?) {
        self.hrvRmssdMs = hrvRmssdMs
        self.restingHR = restingHR
        self.sleepHours = sleepHours
        self.skinTempC = skinTempC
        self.baselineHRV = baselineHRV
        self.baselineRestingHR = baselineRestingHR
        self.baselineSleepHours = baselineSleepHours
        self.baselineSkinTempC = baselineSkinTempC
    }
}

public enum RecoveryScorer {
    public static func score(_ input: RecoveryInputs) -> Int {
        // Independent composite, not WHOOP's proprietary model.
        // Rationale: HRV-guided training literature uses deviations from personal baseline
        // (Kiviniemi et al., 2007; Plews et al., 2013). We weight HRV 60%, resting HR 25%,
        // and sleep duration 15%, then apply skin temperature deviation as a recovery penalty.
        let hrv = clamp(input.hrvRmssdMs / max(input.baselineHRV, 1), 0, 1.4) / 1.4
        let rhr = clamp(input.baselineRestingHR / max(input.restingHR, 1), 0, 1.25) / 1.25
        let sleep = clamp(input.sleepHours / max(input.baselineSleepHours, 1), 0, 1.2) / 1.2
        let tempPenalty: Double
        if let skin = input.skinTempC, let baseline = input.baselineSkinTempC {
            tempPenalty = clamp(abs(skin - baseline) / 2.0, 0, 1) * 0.10
        } else {
            tempPenalty = 0
        }
        return Int(round(clamp((0.60 * hrv + 0.25 * rhr + 0.15 * sleep - tempPenalty) * 100, 0, 100)))
    }

    private static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}
