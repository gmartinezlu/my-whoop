import Foundation

public struct HeartRateRecord: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let bpm: Int
}

public struct RRIntervalRecord: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let milliseconds: Double
}

public struct SpO2Record: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let percent: Double
}

public struct SkinTemperatureRecord: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let celsius: Double
}

public struct RespiratoryRateRecord: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let breathsPerMinute: Double
}

public struct AccelerometerRecord: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let x: Double
    public let y: Double
    public let z: Double
}

public enum DecodedBLERecord: Codable, Equatable, Sendable {
    case heartRate(HeartRateRecord)
    case rrInterval(RRIntervalRecord)
    case spo2(SpO2Record)
    case skinTemperature(SkinTemperatureRecord)
    case respiratoryRate(RespiratoryRateRecord)
    case accelerometer(AccelerometerRecord)
}

public enum BLEProtocolDecoderError: Error, Equatable {
    case unsupportedUntilCaptureIsDocumented
}

public struct BLEProtocolDecoder: Sendable {
    public init() {}

    public func decode(_ frame: Data, characteristic: String) throws -> [DecodedBLERecord] {
        // TODO: Implement from the user's own btsnoop_hci.log/Wireshark findings.
        // Protocol source of truth: BLE_CAPTURE_GUIDE.md.
        // Known unknowns intentionally left blank:
        // - GATT service and characteristic UUIDs
        // - frame header format
        // - opcode mapping
        // - payload offsets, scale factors, signedness, and endianness
        // - whether frames include CRC16-Modbus and which bytes are covered
        _ = frame
        _ = characteristic
        throw BLEProtocolDecoderError.unsupportedUntilCaptureIsDocumented
    }
}
