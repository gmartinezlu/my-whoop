import Foundation

public struct StressWindow: Codable, Equatable, Sendable {
    public let start: Date
    public let end: Date
    public let rmssdMs: Double
    public let stressScore: Double
}

public enum StressAnalyzer {
    public static func windows(rrIntervals: [(timestamp: Date, rrMs: Double)], windowSeconds: TimeInterval = 300, baselineRmssdMs: Double) -> [StressWindow] {
        guard rrIntervals.count >= 2, baselineRmssdMs > 0 else { return [] }
        let sorted = rrIntervals.sorted { $0.timestamp < $1.timestamp }
        var result: [StressWindow] = []
        var startIndex = 0

        while startIndex < sorted.count {
            let start = sorted[startIndex].timestamp
            let end = start.addingTimeInterval(windowSeconds)
            let window = sorted.dropFirst(startIndex).prefix { $0.timestamp < end }
            if window.count >= 2 {
                let values = window.map(\.rrMs)
                if let metrics = HRVAnalyzer.metrics(rrIntervalsMs: values) {
                    // Short-term HRV literature commonly uses 5-minute RMSSD as a parasympathetic
                    // marker (Task Force 1996; Shaffer and Ginsberg 2017). Lower RMSSD is mapped
                    // here to higher stress relative to personal baseline; this is not a diagnosis.
                    let ratio = min(max(metrics.rmssdMs / baselineRmssdMs, 0.05), 2.0)
                    let stress = min(max((1.0 - ratio / 2.0) * 100.0, 0), 100)
                    result.append(StressWindow(start: start, end: window.last?.timestamp ?? end, rmssdMs: metrics.rmssdMs, stressScore: stress))
                }
            }
            startIndex += max(1, window.count)
        }
        return result
    }
}
