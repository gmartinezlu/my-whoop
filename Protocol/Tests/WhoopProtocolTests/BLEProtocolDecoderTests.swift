import XCTest
@testable import WhoopProtocol

final class BLEProtocolDecoderTests: XCTestCase {
    func testDecoderRemainsExplicitStubUntilCaptureIsDocumented() {
        XCTAssertThrowsError(try BLEProtocolDecoder().decode(Data([0x00]), characteristic: "placeholder")) { error in
            XCTAssertEqual(error as? BLEProtocolDecoderError, .unsupportedUntilCaptureIsDocumented)
        }
    }
}
