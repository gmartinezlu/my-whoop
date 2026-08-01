import XCTest
@testable import BLE

final class BLEConnectionStateTests: XCTestCase {
    func testRawValuesAreStableForUIAndPersistence() {
        XCTAssertEqual(BLEConnectionState.disconnected.rawValue, "disconnected")
        XCTAssertEqual(BLEConnectionState.live.rawValue, "live")
    }
}
