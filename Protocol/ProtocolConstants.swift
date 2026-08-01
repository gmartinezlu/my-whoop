import CoreBluetooth
import Foundation

public enum ProtocolConstants {
    public enum StandardBLE {
        public static let heartRateService = CBUUID(string: "180D")
        public static let heartRateMeasurementCharacteristic = CBUUID(string: "2A37")
    }

    // Keep scanning unfiltered until the user's WHOOP advertisement is confirmed.
    public static let serviceUUIDs: [CBUUID] = []

    // Keep discovery unfiltered. The decoder handles public standard characteristics
    // and leaves private WHOOP frames as raw capture until documented.
    public static let characteristicUUIDs: [CBUUID] = []
    public static let notifyCharacteristicUUIDs: [CBUUID] = []

    // TODO: Add observed opcodes, payload offsets, byte order, and any CRC16-Modbus settings.
    public enum Opcode {
        public static let heartRate: UInt8? = nil
        public static let rrInterval: UInt8? = nil
        public static let spo2: UInt8? = nil
        public static let skinTemperature: UInt8? = nil
        public static let respiratoryRate: UInt8? = nil
        public static let accelerometer: UInt8? = nil
    }
}
