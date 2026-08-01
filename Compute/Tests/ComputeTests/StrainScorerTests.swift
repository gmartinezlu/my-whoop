import XCTest
@testable import Compute

final class StrainScorerTests: XCTestCase {
    func testBanisterTRIMPExample() {
        let start = Date(timeIntervalSince1970: 0)
        let samples = stride(from: 0, through: 30, by: 10).map {
            HeartRateSample(timestamp: start.addingTimeInterval(TimeInterval($0 * 60)), bpm: 150)
        }
        let trimp = StrainScorer.trimp(samples: samples, restingHR: 50, maxHR: 200, sex: .male)
        XCTAssertEqual(trimp, 51.96, accuracy: 0.05)
        XCTAssertEqual(StrainScorer.strainScore(fromTRIMP: trimp), 14.56, accuracy: 0.05)
    }
}
