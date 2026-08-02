import CoreBluetooth
import Foundation

public enum ProtocolConstants {
    public enum StandardBLE {
        public static let heartRateService = CBUUID(string: "180D")
        public static let heartRateMeasurementCharacteristic = CBUUID(string: "2A37")
        public static let batteryService = CBUUID(string: "180F")
        public static let batteryLevelCharacteristic = CBUUID(string: "2A19")
    }

    public enum WHOOPV5 {
        public static let service = CBUUID(string: "fd4b0001-cce1-4033-93ce-002d5875f58a")
        public static let command = CBUUID(string: "fd4b0002-cce1-4033-93ce-002d5875f58a")
        public static let characteristic3 = CBUUID(string: "fd4b0003-cce1-4033-93ce-002d5875f58a")
        public static let characteristic4 = CBUUID(string: "fd4b0004-cce1-4033-93ce-002d5875f58a")
        public static let characteristic5 = CBUUID(string: "fd4b0005-cce1-4033-93ce-002d5875f58a")
        public static let data = CBUUID(string: "fd4b0007-cce1-4033-93ce-002d5875f58a")
    }

    public enum WHOOP6108 {
        public static let service = CBUUID(string: "61080001-0000-0000-0000-000000000000")
        public static let command = CBUUID(string: "61080002-0000-0000-0000-000000000000")
        public static let characteristic3 = CBUUID(string: "61080003-0000-0000-0000-000000000000")
        public static let characteristic4 = CBUUID(string: "61080004-0000-0000-0000-000000000000")
        public static let characteristic5 = CBUUID(string: "61080005-0000-0000-0000-000000000000")
        public static let data = CBUUID(string: "61080007-0000-0000-0000-000000000000")
    }

    public enum WHOOPFamily: String, Codable, Equatable, Sendable {
        case v5FD4B
        case legacy6108
    }

    // Keep scanning unfiltered because WHOOP advertisements may omit private services.
    public static let serviceUUIDs: [CBUUID] = []

    public static let whoopServiceUUIDs: [CBUUID] = [
        WHOOPV5.service,
        WHOOP6108.service
    ]

    public static let characteristicUUIDs: [CBUUID] = [
        WHOOPV5.command,
        WHOOPV5.characteristic3,
        WHOOPV5.characteristic4,
        WHOOPV5.characteristic5,
        WHOOPV5.data,
        WHOOP6108.command,
        WHOOP6108.characteristic3,
        WHOOP6108.characteristic4,
        WHOOP6108.characteristic5,
        WHOOP6108.data,
        StandardBLE.heartRateMeasurementCharacteristic,
        StandardBLE.batteryLevelCharacteristic
    ]

    public static let notifyCharacteristicUUIDs: [CBUUID] = [
        WHOOPV5.data,
        WHOOP6108.data,
        StandardBLE.heartRateMeasurementCharacteristic
    ]

    public static func family(for serviceUUID: CBUUID) -> WHOOPFamily? {
        if serviceUUID == WHOOPV5.service { return .v5FD4B }
        if serviceUUID == WHOOP6108.service { return .legacy6108 }
        return nil
    }

    public static func isWhoopDataCharacteristic(_ characteristicUUID: String) -> Bool {
        let normalized = normalizedUUID(characteristicUUID)
        return normalized == normalizedUUID(WHOOPV5.data.uuidString)
            || normalized == normalizedUUID(WHOOP6108.data.uuidString)
    }

    // Narrow metric opcode contract used by BLEProtocolDecoder. Unknown frames are raw-logged.
    public enum Opcode {
        public static let heartRate: UInt8 = 0x01
        public static let rrInterval: UInt8 = 0x02
        public static let spo2: UInt8 = 0x03
        public static let skinTemperature: UInt8 = 0x04
        public static let respiratoryRate: UInt8 = 0x05
        public static let accelerometer: UInt8 = 0x06
    }

    public static func normalizedUUID(_ uuid: String) -> String {
        uuid
            .uppercased()
            .replacingOccurrences(of: "0000", with: "", options: [.anchored])
            .replacingOccurrences(of: "-0000-1000-8000-00805F9B34FB", with: "")
    }
}
