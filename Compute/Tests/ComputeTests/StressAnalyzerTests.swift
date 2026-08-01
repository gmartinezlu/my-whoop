import XCTest
@testable import Compute

final class StressAnalyzerTests: XCTestCase {
    func testShortRMSSDWindowMapsLowerHRVToHigherStress() {
        let start = Date(timeIntervalSince1970: 0)
        let intervals: [(timestamp: Date, rrMs: Double)] = [
            (timestamp: start, rrMs: 800.0),
            (timestamp: start.addingTimeInterval(60), rrMs: 810.0),
            (timestamp: start.addingTimeInterval(120), rrMs: 815.0),
            (timestamp: start.addingTimeInterval(180), rrMs: 830.0)
        ]
        let windows = StressAnalyzer.windows(rrIntervals: intervals, windowSeconds: 300, baselineRmssdMs: 60)
        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(windows[0].rmssdMs, 10.801, accuracy: 0.001)
        XCTAssertEqual(windows[0].stressScore, 91.0, accuracy: 0.1)
    }
}
