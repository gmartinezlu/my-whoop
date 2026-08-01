import Foundation

public struct HRVTimeDomainMetrics: Codable, Equatable, Sendable {
    public let meanRRMs: Double
    public let sdnnMs: Double
    public let rmssdMs: Double
}

public enum HRVAnalyzer {
    public static func metrics(rrIntervalsMs: [Double]) -> HRVTimeDomainMetrics? {
        guard rrIntervalsMs.count >= 2 else { return nil }
        let mean = rrIntervalsMs.reduce(0, +) / Double(rrIntervalsMs.count)
        let variance = rrIntervalsMs.map { pow($0 - mean, 2) }.reduce(0, +) / Double(rrIntervalsMs.count - 1)
        let successiveSquares = zip(rrIntervalsMs, rrIntervalsMs.dropFirst()).map { pow($1 - $0, 2) }
        // Task Force of the ESC/NASPE, 1996: RMSSD = sqrt(mean squared differences of successive NN intervals).
        let rmssd = sqrt(successiveSquares.reduce(0, +) / Double(successiveSquares.count))
        return HRVTimeDomainMetrics(meanRRMs: mean, sdnnMs: sqrt(variance), rmssdMs: rmssd)
    }
}
