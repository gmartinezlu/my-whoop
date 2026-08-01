import XCTest
@testable import Storage

final class SyncOutboxTests: XCTestCase {
    func testQueueLifecycle() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let outbox = try SyncOutbox(directory: directory)
        try outbox.enqueue(payloadJSON: #"{"date":"2026-08-01"}"#)
        let pending = try outbox.pending()
        XCTAssertEqual(pending.count, 1)
        try outbox.remove(id: pending[0].id)
        XCTAssertTrue(try outbox.pending().isEmpty)
    }
}
