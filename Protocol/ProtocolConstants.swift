import CoreBluetooth
import Foundation

public enum ProtocolConstants {
    // TODO: Fill these from your own BLE capture notes in BLE_CAPTURE_GUIDE.md.
    // Do not use guessed WHOOP UUIDs. Add only observed service UUIDs here.
    public static let serviceUUIDs: [CBUUID] = []

    // TODO: Add observed readable/writable/notify characteristic UUIDs.
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
