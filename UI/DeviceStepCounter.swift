import Combine
import Foundation

#if os(iOS) && canImport(CoreMotion)
import CoreMotion
#endif

public final class DeviceStepCounter: ObservableObject {
    @Published public private(set) var steps: Int = 0
    @Published public private(set) var status: String = "No iniciado"

    #if os(iOS) && canImport(CoreMotion)
    private let pedometer = CMPedometer()
    #endif

    public init() {}

    public func start() {
        #if os(iOS) && canImport(CoreMotion)
        guard CMPedometer.isStepCountingAvailable() else {
            status = "Pasos no disponibles"
            return
        }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        status = "Leyendo pasos"

        pedometer.queryPedometerData(from: startOfDay, to: Date()) { [weak self] data, error in
            DispatchQueue.main.async {
                if let error {
                    self?.status = error.localizedDescription
                    return
                }
                self?.steps = data?.numberOfSteps.intValue ?? 0
                self?.status = "Pasos del iPhone"
            }
        }

        pedometer.startUpdates(from: startOfDay) { [weak self] data, error in
            DispatchQueue.main.async {
                if let error {
                    self?.status = error.localizedDescription
                    return
                }
                self?.steps = data?.numberOfSteps.intValue ?? self?.steps ?? 0
                self?.status = "Pasos del iPhone"
            }
        }
        #else
        status = "Solo disponible en iPhone"
        #endif
    }
}
