import XCTest
@testable import WhoopProtocol

final class BLEProtocolDecoderTests: XCTestCase {
    func testDecodesStandardHeartRateMeasurementUInt8() throws {
        let records = try BLEProtocolDecoder().decode(Data([0x00, 72]), characteristic: "2A37")
        XCTAssertEqual(records.count, 1)
        guard case .heartRate(let heartRate) = records[0] else {
            XCTFail("Expected heart rate record")
            return
        }
        XCTAssertEqual(heartRate.bpm, 72)
    }

    func testDecodesStandardHeartRateMeasurementWithRRIntervals() throws {
        let records = try BLEProtocolDecoder().decode(
            Data([0x10, 60, 0x00, 0x04, 0x00, 0x05]),
            characteristic: "00002A37-0000-1000-8000-00805F9B34FB"
        )
        XCTAssertEqual(records.count, 3)
        guard case .heartRate(let heartRate) = records[0],
              case .rrInterval(let firstRR) = records[1],
              case .rrInterval(let secondRR) = records[2] else {
            XCTFail("Expected heart rate plus RR interval records")
            return
        }
        XCTAssertEqual(heartRate.bpm, 60)
        XCTAssertEqual(firstRR.milliseconds, 1000, accuracy: 0.001)
        XCTAssertEqual(secondRR.milliseconds, 1250, accuracy: 0.001)
    }

    func testPrivateDecoderRemainsExplicitStubUntilCaptureIsDocumented() {
        XCTAssertThrowsError(try BLEProtocolDecoder().decode(Data([0x00]), characteristic: "placeholder")) { error in
            XCTAssertEqual(error as? BLEProtocolDecoderError, .unsupportedUntilCaptureIsDocumented)
        }
    }
}
