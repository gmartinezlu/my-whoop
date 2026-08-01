import XCTest
@testable import Compute

final class HRVAnalyzerTests: XCTestCase {
    func testRMSSDMatchesTaskForceFormula() {
        let metrics = HRVAnalyzer.metrics(rrIntervalsMs: [800, 810, 815, 830])
        XCTAssertEqual(metrics?.meanRRMs ?? 0, 813.75, accuracy: 0.001)
        XCTAssertEqual(metrics?.rmssdMs ?? 0, 10.801, accuracy: 0.001)
    }
}
