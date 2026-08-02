import Combine
import Compute
import CoreBluetooth
import Foundation
import WhoopProtocol

public struct BLEDiscoveredPeripheral: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let rssi: Int
    public let serviceUUIDs: [String]

    public init(id: UUID, name: String, rssi: Int, serviceUUIDs: [String]) {
        self.id = id
        self.name = name
        self.rssi = rssi
        self.serviceUUIDs = serviceUUIDs
    }
}

public struct GATTCharacteristicSnapshot: Identifiable, Equatable, Sendable {
    public let id: String
    public let uuid: String
    public let properties: [String]
    public let isNotifying: Bool

    public init(id: String, uuid: String, properties: [String], isNotifying: Bool) {
        self.id = id
        self.uuid = uuid
        self.properties = properties
        self.isNotifying = isNotifying
    }
}

public struct GATTServiceSnapshot: Identifiable, Equatable, Sendable {
    public let id: String
    public let uuid: String
    public let characteristics: [GATTCharacteristicSnapshot]

    public init(id: String, uuid: String, characteristics: [GATTCharacteristicSnapshot]) {
        self.id = id
        self.uuid = uuid
        self.characteristics = characteristics
    }
}

public struct RawBLENotification: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let characteristicUUID: String
    public let hexPayload: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), characteristicUUID: String, hexPayload: String) {
        self.id = id
        self.timestamp = timestamp
        self.characteristicUUID = characteristicUUID
        self.hexPayload = hexPayload
    }
}

public final class BLEManager: NSObject, ObservableObject {
    @Published public private(set) var state: BLEConnectionState = .disconnected
    @Published public private(set) var discoveredPeripherals: [BLEDiscoveredPeripheral] = []
    @Published public private(set) var gattServices: [GATTServiceSnapshot] = []
    @Published public private(set) var rawNotifications: [RawBLENotification] = []
    @Published public private(set) var latestRecords: [DecodedBLERecord] = []
    @Published public private(set) var liveHeartRate: Int?
    @Published public private(set) var latestRMSSD: Double?
    @Published public private(set) var batteryPercent: Int?
    @Published public private(set) var stepCount: Int = 0
    @Published public private(set) var activeWHOOPFamily: ProtocolConstants.WHOOPFamily?
    @Published public private(set) var lastError: String?
    @Published public private(set) var authenticationNotice: String?

    private let decoder: BLEProtocolDecoder
    private var central: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var peripheralsByID: [UUID: CBPeripheral] = [:]
    private var rrWindowMs: [Double] = []
    private var lastStepAt: Date?
    private var operationInFlight = false
    private var pendingOperation: (() -> Void)?

    public init(decoder: BLEProtocolDecoder = BLEProtocolDecoder()) {
        self.decoder = decoder
        super.init()
        self.central = CBCentralManager(delegate: self, queue: nil)
    }

    public func scan() {
        runExclusively { [weak self] in
            guard let self else { return }
            guard self.central.state == .poweredOn else {
                self.lastError = "Bluetooth is not powered on."
                self.finishOperation()
                return
            }

            self.state = .connecting
            self.discoveredPeripherals.removeAll()
            self.gattServices.removeAll()
            self.rawNotifications.removeAll()
            self.latestRecords.removeAll()
            self.liveHeartRate = nil
            self.latestRMSSD = nil
            self.batteryPercent = nil
            self.stepCount = 0
            self.activeWHOOPFamily = nil
            self.lastError = nil
            self.authenticationNotice = nil
            self.rrWindowMs.removeAll()
            self.lastStepAt = nil
            let serviceFilter = ProtocolConstants.serviceUUIDs.isEmpty ? nil : ProtocolConstants.serviceUUIDs
            self.central.scanForPeripherals(withServices: serviceFilter, options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: false
            ])
            self.finishOperation(after: 3.0) { [weak self] in
                self?.central.stopScan()
                if self?.connectedPeripheral == nil {
                    self?.state = .disconnected
                }
            }
        }
    }

    public func connect(to peripheralID: UUID) {
        runExclusively { [weak self] in
            guard let self, let peripheral = self.peripheralsByID[peripheralID] else {
                self?.lastError = "Peripheral is no longer available. Scan again."
                self?.finishOperation()
                return
            }
            self.central.stopScan()
            self.state = .connecting
            self.gattServices.removeAll()
            self.rawNotifications.removeAll()
            self.latestRecords.removeAll()
            self.liveHeartRate = nil
            self.latestRMSSD = nil
            self.batteryPercent = nil
            self.stepCount = 0
            self.activeWHOOPFamily = nil
            self.lastError = nil
            self.authenticationNotice = nil
            self.rrWindowMs.removeAll()
            self.lastStepAt = nil
            self.connectedPeripheral = peripheral
            peripheral.delegate = self
            self.central.connect(peripheral, options: nil)
        }
    }

    public func reconnect() {
        runExclusively { [weak self] in
            guard let self, let peripheral = self.connectedPeripheral else {
                self?.finishOperation()
                return
            }
            self.state = .connecting
            self.central.connect(peripheral, options: nil)
        }
    }

    public func disconnect() {
        runExclusively { [weak self] in
            guard let self, let peripheral = self.connectedPeripheral else {
                self?.state = .disconnected
                self?.finishOperation()
                return
            }
            self.central.cancelPeripheralConnection(peripheral)
        }
    }

    private func runExclusively(_ operation: @escaping () -> Void) {
        guard !operationInFlight else {
            pendingOperation = operation
            return
        }
        operationInFlight = true
        operation()
    }

    private func finishOperation(after delay: TimeInterval = 0, completion: (() -> Void)? = nil) {
        let finish = { [weak self] in
            completion?()
            self?.operationInFlight = false
            if let next = self?.pendingOperation {
                self?.pendingOperation = nil
                self?.runExclusively(next)
            }
        }

        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: finish)
        } else {
            finish()
        }
    }

    private func subscribeToKnownCharacteristics(on peripheral: CBPeripheral) {
        for service in peripheral.services ?? [] {
            if let family = ProtocolConstants.family(for: service.uuid) {
                activeWHOOPFamily = family
            }
            for characteristic in service.characteristics ?? [] where shouldSubscribe(to: characteristic) {
                if shouldSkipEncryptedUnknownCharacteristic(characteristic) {
                    authenticationNotice = "La banda protege \(characteristic.uuid.uuidString). iOS no permite leer esa notificación sin autenticación/pairing compatible."
                    continue
                }
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        state = .live
    }

    private func refreshGATTSnapshot(for peripheral: CBPeripheral) {
        gattServices = (peripheral.services ?? []).map { service in
            let characteristics = (service.characteristics ?? []).map { characteristic in
                GATTCharacteristicSnapshot(
                    id: "\(service.uuid.uuidString)-\(characteristic.uuid.uuidString)",
                    uuid: characteristic.uuid.uuidString,
                    properties: describe(characteristic.properties),
                    isNotifying: characteristic.isNotifying
                )
            }
            return GATTServiceSnapshot(
                id: service.uuid.uuidString,
                uuid: service.uuid.uuidString,
                characteristics: characteristics
            )
        }
    }

    private func describe(_ properties: CBCharacteristicProperties) -> [String] {
        var result: [String] = []
        if properties.contains(.broadcast) { result.append("broadcast") }
        if properties.contains(.read) { result.append("read") }
        if properties.contains(.writeWithoutResponse) { result.append("writeWithoutResponse") }
        if properties.contains(.write) { result.append("write") }
        if properties.contains(.notify) { result.append("notify") }
        if properties.contains(.indicate) { result.append("indicate") }
        if properties.contains(.authenticatedSignedWrites) { result.append("authenticatedSignedWrites") }
        if properties.contains(.extendedProperties) { result.append("extendedProperties") }
        if properties.contains(.notifyEncryptionRequired) { result.append("notifyEncryptionRequired") }
        if properties.contains(.indicateEncryptionRequired) { result.append("indicateEncryptionRequired") }
        return result
    }

    private func shouldSubscribe(to characteristic: CBCharacteristic) -> Bool {
        guard characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) else {
            return false
        }
        if !ProtocolConstants.notifyCharacteristicUUIDs.isEmpty {
            return ProtocolConstants.notifyCharacteristicUUIDs.contains(characteristic.uuid)
        }
        return normalizedUUID(characteristic.uuid.uuidString) == "2A37"
            || ProtocolConstants.isWhoopDataCharacteristic(characteristic.uuid.uuidString)
    }

    private func shouldSkipEncryptedUnknownCharacteristic(_ characteristic: CBCharacteristic) -> Bool {
        let requiresEncryption = characteristic.properties.contains(.notifyEncryptionRequired)
            || characteristic.properties.contains(.indicateEncryptionRequired)
        let isStandardHeartRate = normalizedUUID(characteristic.uuid.uuidString) == "2A37"
        let isWHOOPData = ProtocolConstants.isWhoopDataCharacteristic(characteristic.uuid.uuidString)
        let isExplicitlyConfigured = ProtocolConstants.notifyCharacteristicUUIDs.contains(characteristic.uuid)
        return requiresEncryption && !isStandardHeartRate && !isWHOOPData && !isExplicitlyConfigured
    }

    private func hexString(_ data: Data) -> String {
        data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    private func normalizedUUID(_ uuid: String) -> String {
        uuid
            .uppercased()
            .replacingOccurrences(of: "0000", with: "", options: [.anchored])
            .replacingOccurrences(of: "-0000-1000-8000-00805F9B34FB", with: "")
    }

    private func readStandardValueIfAvailable(_ characteristic: CBCharacteristic, on peripheral: CBPeripheral) {
        let uuid = normalizedUUID(characteristic.uuid.uuidString)
        if uuid == "2A19", characteristic.properties.contains(.read) {
            peripheral.readValue(for: characteristic)
        }
    }

    private func applyStandardValue(_ data: Data, characteristic: CBCharacteristic) -> Bool {
        guard normalizedUUID(characteristic.uuid.uuidString) == "2A19", let first = data.first else {
            return false
        }
        batteryPercent = min(max(Int(first), 0), 100)
        return true
    }

    private func applyDecodedRecords(_ records: [DecodedBLERecord]) {
        for record in records {
            switch record {
            case .heartRate(let heartRate):
                liveHeartRate = heartRate.bpm
            case .rrInterval(let interval):
                rrWindowMs.append(interval.milliseconds)
                if rrWindowMs.count > 120 {
                    rrWindowMs.removeFirst(rrWindowMs.count - 120)
                }
            case .accelerometer(let sample):
                let magnitude = sqrt(sample.x * sample.x + sample.y * sample.y + sample.z * sample.z)
                if magnitude > 1.25, lastStepAt.map({ sample.timestamp.timeIntervalSince($0) > 0.28 }) ?? true {
                    stepCount += 1
                    lastStepAt = sample.timestamp
                }
            default:
                break
            }
        }

        if let metrics = HRVAnalyzer.metrics(rrIntervalsMs: rrWindowMs) {
            latestRMSSD = metrics.rmssdMs
        }
    }
}

extension BLEManager: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            state = .disconnected
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        peripheralsByID[peripheral.identifier] = peripheral
        let advertisedServices = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.map(\.uuidString) ?? []
        let displayName = peripheral.name
            ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
            ?? "Unknown peripheral"
        let snapshot = BLEDiscoveredPeripheral(
            id: peripheral.identifier,
            name: displayName,
            rssi: RSSI.intValue,
            serviceUUIDs: advertisedServices
        )
        discoveredPeripherals.removeAll { $0.id == snapshot.id }
        discoveredPeripherals.append(snapshot)
        discoveredPeripherals.sort { $0.rssi > $1.rssi }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        state = .connected
        peripheral.discoverServices(nil)
        finishOperation()
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        lastError = error?.localizedDescription
        state = .disconnected
        connectedPeripheral = nil
        finishOperation()
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        lastError = error?.localizedDescription
        state = .disconnected
        connectedPeripheral = nil
        finishOperation()
    }
}

extension BLEManager: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            lastError = error.localizedDescription
            return
        }

        for service in peripheral.services ?? [] {
            if let family = ProtocolConstants.family(for: service.uuid) {
                activeWHOOPFamily = family
            }
            peripheral.discoverCharacteristics(nil, for: service)
        }
        refreshGATTSnapshot(for: peripheral)
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            lastError = error.localizedDescription
            return
        }
        refreshGATTSnapshot(for: peripheral)
        for characteristic in service.characteristics ?? [] {
            readStandardValueIfAvailable(characteristic, on: peripheral)
        }
        subscribeToKnownCharacteristics(on: peripheral)
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            let nsError = error as NSError
            if nsError.domain == CBATTErrorDomain {
                authenticationNotice = "Autenticación insuficiente en \(characteristic.uuid.uuidString). Esa característica requiere pairing/handshake privado; se mantienen HR y batería estándar si existen."
            } else {
                lastError = error.localizedDescription
            }
        }
        refreshGATTSnapshot(for: peripheral)
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            lastError = error.localizedDescription
            return
        }
        guard let data = characteristic.value else { return }
        if applyStandardValue(data, characteristic: characteristic) {
            return
        }
        rawNotifications.insert(
            RawBLENotification(characteristicUUID: characteristic.uuid.uuidString, hexPayload: hexString(data)),
            at: 0
        )
        if rawNotifications.count > 100 {
            rawNotifications.removeLast(rawNotifications.count - 100)
        }

        do {
            let records = try decoder.decode(data, characteristic: characteristic.uuid.uuidString)
            latestRecords.append(contentsOf: records)
            applyDecodedRecords(records)
        } catch {
            RawBLELogStore.append(
                characteristicUUID: characteristic.uuid.uuidString,
                payloadHex: hexString(data),
                reason: String(describing: error)
            )
            if case BLEProtocolDecoderError.unsupportedCharacteristic = error {
                return
            }
            if case BLEProtocolDecoderError.unrecognizedWHOOPFrame = error {
                authenticationNotice = "Frame WHOOP no reconocido. Quedo guardado en el log BLE crudo para ajustar el decoder."
                return
            }
            if case BLEProtocolDecoderError.malformedWHOOPFrame = error {
                authenticationNotice = "Frame WHOOP mal formado o incompleto. Quedo guardado en el log BLE crudo."
                return
            }
            lastError = error.localizedDescription
        }
    }
}
