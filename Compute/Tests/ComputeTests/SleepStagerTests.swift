import XCTest
@testable import Compute

final class SleepStagerTests: XCTestCase {
    func testMovementDominatesAwakeClassification() {
        let start = Date(timeIntervalSince1970: 0)
        let samples = [
            HeartRateSample(timestamp: start, bpm: 52),
            HeartRateSample(timestamp: start.addingTimeInterval(30), bpm: 52),
            HeartRateSample(timestamp: start.addingTimeInterval(60), bpm: 70),
            HeartRateSample(timestamp: start.addingTimeInterval(90), bpm: 55)
        ]
        let summary = SleepStager.stage(samples: samples, movement: [0.1, 0.1, 0.1, 0.8], restingHR: 50)
        XCTAssertEqual(summary.epochs.map(\.stage), [.deep, .deep, .rem, .awake])
        XCTAssertEqual(summary.efficiencyPercent, 75, accuracy: 0.001)
    }
}
