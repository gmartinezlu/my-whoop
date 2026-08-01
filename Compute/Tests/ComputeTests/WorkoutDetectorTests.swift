import XCTest
@testable import Compute

final class WorkoutDetectorTests: XCTestCase {
    func testDetectsSustainedHighHRAndMovementWorkout() {
        let start = Date(timeIntervalSince1970: 0)
        let samples = stride(from: 0, through: 12, by: 2).map {
            HeartRateSample(timestamp: start.addingTimeInterval(TimeInterval($0 * 60)), bpm: 145)
        }
        let workouts = WorkoutDetector.detect(
            samples: samples,
            movement: Array(repeating: 0.7, count: samples.count),
            restingHR: 55,
            maxHR: 190,
            sex: .female,
            minDuration: 10 * 60
        )
        XCTAssertEqual(workouts.count, 1)
        XCTAssertEqual(workouts[0].averageHR, 145, accuracy: 0.001)
        XCTAssertGreaterThan(workouts[0].strain, 0)
    }
}
