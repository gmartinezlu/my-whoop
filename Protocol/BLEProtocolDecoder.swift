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
    case malformedHeartRateMeasurement
    case unsupportedUntilCaptureIsDocumented
}

public struct BLEProtocolDecoder: Sendable {
    public init() {}

    public func decode(_ frame: Data, characteristic: String) throws -> [DecodedBLERecord] {
        if normalizedUUID(characteristic) == "2A37" {
            return try decodeHeartRateMeasurement(frame)
        }

        // TODO: Implement from the user's own btsnoop_hci.log/Wireshark findings.
        // Protocol source of truth: BLE_CAPTURE_GUIDE.md.
        // Known unknowns intentionally left blank:
        // - GATT service and characteristic UUIDs
        // - frame header format
        // - opcode mapping
        // - payload offsets, scale factors, signedness, and endianness
        // - whether frames include CRC16-Modbus and which bytes are covered
        _ = frame
        throw BLEProtocolDecoderError.unsupportedUntilCaptureIsDocumented
    }

    private func decodeHeartRateMeasurement(_ frame: Data) throws -> [DecodedBLERecord] {
        guard frame.count >= 2 else {
            throw BLEProtocolDecoderError.malformedHeartRateMeasurement
        }

        let bytes = [UInt8](frame)
        let flags = bytes[0]
        let isUInt16HeartRate = (flags & 0x01) != 0
        let energyExpendedPresent = (flags & 0x08) != 0
        let rrIntervalsPresent = (flags & 0x10) != 0
        var offset = 1

        let bpm: Int
        if isUInt16HeartRate {
            guard bytes.count >= offset + 2 else {
                throw BLEProtocolDecoderError.malformedHeartRateMeasurement
            }
            bpm = Int(UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8))
            offset += 2
        } else {
            bpm = Int(bytes[offset])
            offset += 1
        }

        if energyExpendedPresent {
            guard bytes.count >= offset + 2 else {
                throw BLEProtocolDecoderError.malformedHeartRateMeasurement
            }
            offset += 2
        }

        let timestamp = Date()
        var records: [DecodedBLERecord] = [
            .heartRate(HeartRateRecord(timestamp: timestamp, bpm: bpm))
        ]

        if rrIntervalsPresent {
            while offset + 1 < bytes.count {
                let raw = UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
                let milliseconds = Double(raw) / 1024.0 * 1000.0
                records.append(.rrInterval(RRIntervalRecord(timestamp: timestamp, milliseconds: milliseconds)))
                offset += 2
            }
            if offset != bytes.count {
                throw BLEProtocolDecoderError.malformedHeartRateMeasurement
            }
        }

        return records
    }

    private func normalizedUUID(_ uuid: String) -> String {
        uuid
            .uppercased()
            .replacingOccurrences(of: "0000", with: "", options: [.anchored])
            .replacingOccurrences(of: "-0000-1000-8000-00805F9B34FB", with: "")
    }
}
