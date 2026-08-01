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
    @Published public private(set) var lastError: String?

    private let decoder: BLEProtocolDecoder
    private var central: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var peripheralsByID: [UUID: CBPeripheral] = [:]
    private var rrWindowMs: [Double] = []
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
            self.rrWindowMs.removeAll()
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
            self.rrWindowMs.removeAll()
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
            for characteristic in service.characteristics ?? [] where shouldSubscribe(to: characteristic) {
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
        return ProtocolConstants.notifyCharacteristicUUIDs.isEmpty || ProtocolConstants.notifyCharacteristicUUIDs.contains(characteristic.uuid)
    }

    private func hexString(_ data: Data) -> String {
        data.map { String(format: "%02X", $0) }.joined(separator: " ")
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
        let serviceFilter = ProtocolConstants.serviceUUIDs.isEmpty ? nil : ProtocolConstants.serviceUUIDs
        peripheral.discoverServices(serviceFilter)
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
            let characteristicFilter = ProtocolConstants.characteristicUUIDs.isEmpty ? nil : ProtocolConstants.characteristicUUIDs
            peripheral.discoverCharacteristics(characteristicFilter, for: service)
        }
        refreshGATTSnapshot(for: peripheral)
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            lastError = error.localizedDescription
            return
        }
        refreshGATTSnapshot(for: peripheral)
        subscribeToKnownCharacteristics(on: peripheral)
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            lastError = error.localizedDescription
        }
        refreshGATTSnapshot(for: peripheral)
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            lastError = error.localizedDescription
            return
        }
        guard let data = characteristic.value else { return }
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
            lastError = error.localizedDescription
        }
    }
}
