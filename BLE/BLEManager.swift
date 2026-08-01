import Combine
import CoreBluetooth
import Foundation
import WhoopProtocol

public final class BLEManager: NSObject, ObservableObject {
    @Published public private(set) var state: BLEConnectionState = .disconnected
    @Published public private(set) var discoveredPeripherals: [CBPeripheral] = []
    @Published public private(set) var latestRecords: [DecodedBLERecord] = []
    @Published public private(set) var lastError: String?

    private let decoder: BLEProtocolDecoder
    private var central: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
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
            self.central.scanForPeripherals(withServices: ProtocolConstants.serviceUUIDs, options: [
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

    public func connect(to peripheral: CBPeripheral) {
        runExclusively { [weak self] in
            guard let self else { return }
            self.central.stopScan()
            self.state = .connecting
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
            for characteristic in service.characteristics ?? [] where ProtocolConstants.notifyCharacteristicUUIDs.contains(characteristic.uuid) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        state = .live
    }
}

extension BLEManager: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            state = .disconnected
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        state = .connected
        peripheral.discoverServices(ProtocolConstants.serviceUUIDs)
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
            peripheral.discoverCharacteristics(ProtocolConstants.characteristicUUIDs, for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            lastError = error.localizedDescription
            return
        }
        subscribeToKnownCharacteristics(on: peripheral)
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            lastError = error.localizedDescription
            return
        }
        guard let data = characteristic.value else { return }

        do {
            let records = try decoder.decode(data, characteristic: characteristic.uuid.uuidString)
            latestRecords.append(contentsOf: records)
        } catch {
            lastError = error.localizedDescription
        }
    }
}
