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
    case emptyFrame
    case unsupportedCharacteristic(String)
    case unrecognizedWHOOPFrame(String)
    case malformedWHOOPFrame(String)
}

public struct BLEProtocolDecoder: Sendable {
    public init() {}

    public func decode(_ frame: Data, characteristic: String) throws -> [DecodedBLERecord] {
        if normalizedUUID(characteristic) == "2A37" {
            return try decodeHeartRateMeasurement(frame)
        }

        if ProtocolConstants.isWhoopDataCharacteristic(characteristic) {
            return try decodeWHOOPDataFrame(frame)
        }

        throw BLEProtocolDecoderError.unsupportedCharacteristic(characteristic)
    }

    private func decodeWHOOPDataFrame(_ frame: Data) throws -> [DecodedBLERecord] {
        guard !frame.isEmpty else { throw BLEProtocolDecoderError.emptyFrame }
        let bytes = [UInt8](frame)

        if let records = try decodeTLVRecords(bytes), !records.isEmpty {
            return records
        }
        if let records = try decodeSingleRecord(bytes), !records.isEmpty {
            return records
        }
        throw BLEProtocolDecoderError.unrecognizedWHOOPFrame(hexString(frame))
    }

    private func decodeTLVRecords(_ bytes: [UInt8]) throws -> [DecodedBLERecord]? {
        var offset = 0
        var records: [DecodedBLERecord] = []

        while offset < bytes.count {
            guard offset + 2 <= bytes.count else { return nil }
            let opcode = bytes[offset]
            let length = Int(bytes[offset + 1])
            offset += 2
            guard length > 0, offset + length <= bytes.count else { return nil }
            let payload = Array(bytes[offset..<(offset + length)])
            guard let parsed = try decodeMetricPayload(opcode: opcode, payload: payload) else {
                return nil
            }
            records.append(contentsOf: parsed)
            offset += length
        }

        return offset == bytes.count ? records : nil
    }

    private func decodeSingleRecord(_ bytes: [UInt8]) throws -> [DecodedBLERecord]? {
        guard bytes.count >= 2 else { return nil }
        return try decodeMetricPayload(opcode: bytes[0], payload: Array(bytes.dropFirst()))
    }

    private func decodeMetricPayload(opcode: UInt8, payload: [UInt8]) throws -> [DecodedBLERecord]? {
        let timestamp = Date()
        switch opcode {
        case ProtocolConstants.Opcode.heartRate:
            guard payload.count == 1 || payload.count == 2 else {
                throw BLEProtocolDecoderError.malformedWHOOPFrame("heartRate length \(payload.count)")
            }
            let bpm = payload.count == 1
                ? Int(payload[0])
                : Int(UInt16(payload[0]) | (UInt16(payload[1]) << 8))
            guard (25...240).contains(bpm) else { return nil }
            return [.heartRate(HeartRateRecord(timestamp: timestamp, bpm: bpm))]

        case ProtocolConstants.Opcode.rrInterval:
            guard payload.count >= 2, payload.count.isMultiple(of: 2) else {
                throw BLEProtocolDecoderError.malformedWHOOPFrame("rrInterval length \(payload.count)")
            }
            return stride(from: 0, to: payload.count, by: 2).map { offset in
                let raw = UInt16(payload[offset]) | (UInt16(payload[offset + 1]) << 8)
                return .rrInterval(RRIntervalRecord(timestamp: timestamp, milliseconds: Double(raw)))
            }

        case ProtocolConstants.Opcode.spo2:
            guard payload.count == 1 || payload.count == 2 else {
                throw BLEProtocolDecoderError.malformedWHOOPFrame("spo2 length \(payload.count)")
            }
            let percent = payload.count == 1
                ? Double(payload[0])
                : Double(UInt16(payload[0]) | (UInt16(payload[1]) << 8)) / 100.0
            guard (50...100).contains(percent) else { return nil }
            return [.spo2(SpO2Record(timestamp: timestamp, percent: percent))]

        case ProtocolConstants.Opcode.skinTemperature:
            guard payload.count == 2 else {
                throw BLEProtocolDecoderError.malformedWHOOPFrame("skinTemperature length \(payload.count)")
            }
            let raw = Int16(bitPattern: UInt16(payload[0]) | (UInt16(payload[1]) << 8))
            let celsius = Double(raw) / 100.0
            guard (15...45).contains(celsius) else { return nil }
            return [.skinTemperature(SkinTemperatureRecord(timestamp: timestamp, celsius: celsius))]

        case ProtocolConstants.Opcode.respiratoryRate:
            guard payload.count == 1 || payload.count == 2 else {
                throw BLEProtocolDecoderError.malformedWHOOPFrame("respiratoryRate length \(payload.count)")
            }
            let breaths = payload.count == 1
                ? Double(payload[0])
                : Double(UInt16(payload[0]) | (UInt16(payload[1]) << 8)) / 10.0
            guard (4...45).contains(breaths) else { return nil }
            return [.respiratoryRate(RespiratoryRateRecord(timestamp: timestamp, breathsPerMinute: breaths))]

        case ProtocolConstants.Opcode.accelerometer:
            guard payload.count == 6 else {
                throw BLEProtocolDecoderError.malformedWHOOPFrame("accelerometer length \(payload.count)")
            }
            func axis(_ offset: Int) -> Double {
                let raw = Int16(bitPattern: UInt16(payload[offset]) | (UInt16(payload[offset + 1]) << 8))
                return Double(raw) / 1000.0
            }
            return [.accelerometer(AccelerometerRecord(timestamp: timestamp, x: axis(0), y: axis(2), z: axis(4)))]

        default:
            return nil
        }
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
        ProtocolConstants.normalizedUUID(uuid)
    }

    private func hexString(_ data: Data) -> String {
        data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
