import XCTest
@testable import Compute

final class RecoveryScorerTests: XCTestCase {
    func testBaselineDayScoresInReadableRange() {
        let input = RecoveryInputs(
            hrvRmssdMs: 60,
            restingHR: 50,
            sleepHours: 8,
            skinTempC: 33.2,
            baselineHRV: 60,
            baselineRestingHR: 50,
            baselineSleepHours: 8,
            baselineSkinTempC: 33.2
        )
        XCTAssertEqual(RecoveryScorer.score(input), 75)
    }
}
