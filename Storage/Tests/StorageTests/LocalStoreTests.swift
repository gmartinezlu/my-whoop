import XCTest
@testable import Storage

final class LocalStoreTests: XCTestCase {
    func testSaveAndReadDailyMetrics() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = try LocalStore(directory: directory)
        try store.saveDailyMetrics(date: "2026-08-01", json: #"{"recovery_score":80}"#)
        XCTAssertEqual(try store.dailyMetrics(date: "2026-08-01")?.json, #"{"recovery_score":80}"#)
    }
}
