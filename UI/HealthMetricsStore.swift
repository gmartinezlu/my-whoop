import Combine
import Foundation

#if os(iOS) && canImport(HealthKit)
import HealthKit
#endif

public struct CycleSummary: Equatable, Sendable {
    public let status: String
    public let currentDay: Int?
    public let phase: String
    public let nextPeriod: Date?
    public let daysUntilNextPeriod: Int?
    public let detail: String

    public static let unavailable = CycleSummary(
        status: "Sin permiso",
        currentDay: nil,
        phase: "No disponible",
        nextPeriod: nil,
        daysUntilNextPeriod: nil,
        detail: "Autoriza Apple Health para leer registros menstruales y estimar la fase."
    )
}

public final class HealthMetricsStore: ObservableObject {
    @Published public private(set) var status: String = "No iniciado"
    @Published public private(set) var healthStepsToday: Int?
    @Published public private(set) var activeCaloriesKcal: Double?
    @Published public private(set) var vo2Max: Double?
    @Published public private(set) var strengthMinutes: Double?
    @Published public private(set) var healthSleepHours: Double?
    @Published public private(set) var healthSleepAwakenings: Int?
    @Published public private(set) var cycleSummary: CycleSummary = .unavailable

    #if os(iOS) && canImport(HealthKit)
    private let store = HKHealthStore()
    #endif

    public init() {}

    public func start() {
        #if os(iOS) && canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            status = "Health no disponible"
            return
        }

        let readTypes = Set([
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .vo2Max),
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            HKObjectType.categoryType(forIdentifier: .menstrualFlow),
            HKObjectType.workoutType()
        ].compactMap { $0 })

        store.requestAuthorization(toShare: [], read: readTypes) { [weak self] success, error in
            DispatchQueue.main.async {
                if let error {
                    self?.status = error.localizedDescription
                    return
                }
                guard success else {
                    self?.status = "Health sin permiso"
                    return
                }
                self?.status = "Apple Health activo"
                self?.refresh()
            }
        }
        #else
        status = "Solo disponible en iPhone"
        #endif
    }

    public func refresh() {
        #if os(iOS) && canImport(HealthKit)
        queryTodayQuantity(.stepCount, unit: .count()) { [weak self] value in
            self?.healthStepsToday = value.map { Int($0.rounded()) }
        }
        queryTodayQuantity(.activeEnergyBurned, unit: .kilocalorie()) { [weak self] value in
            self?.activeCaloriesKcal = value
        }
        queryLatestQuantity(.vo2Max, unit: HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo)).unitDivided(by: .minute())) { [weak self] value in
            self?.vo2Max = value
        }
        queryStrengthWorkouts()
        querySleep()
        queryCycle()
        #endif
    }
}

#if os(iOS) && canImport(HealthKit)
private extension HealthMetricsStore {
    func queryTodayQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping (Double?) -> Void) {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            completion(nil)
            return
        }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
            let value = stats?.sumQuantity()?.doubleValue(for: unit)
            DispatchQueue.main.async { completion(value) }
        }
        store.execute(query)
    }

    func queryLatestQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping (Double?) -> Void) {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            completion(nil)
            return
        }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
            let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
            DispatchQueue.main.async { completion(value) }
        }
        store.execute(query)
    }

    func queryStrengthWorkouts() {
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, _ in
            let minutes = (samples as? [HKWorkout])?.filter {
                $0.workoutActivityType == .traditionalStrengthTraining || $0.workoutActivityType == .functionalStrengthTraining
            }.reduce(0.0) { $0 + $1.duration / 60.0 }
            DispatchQueue.main.async {
                self?.strengthMinutes = minutes
            }
        }
        store.execute(query)
    }

    func querySleep() {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let start = Calendar.current.date(byAdding: .hour, value: -18, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, _ in
            let sleepSamples = (samples as? [HKCategorySample]) ?? []
            let asleepValues: Set<Int> = [
                HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                HKCategoryValueSleepAnalysis.asleepREM.rawValue
            ]
            let hours = sleepSamples
                .filter { asleepValues.contains($0.value) }
                .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 3600.0 }
            let awakeCount = sleepSamples.filter { $0.value == HKCategoryValueSleepAnalysis.awake.rawValue }.count
            DispatchQueue.main.async {
                self?.healthSleepHours = hours > 0 ? hours : nil
                self?.healthSleepAwakenings = awakeCount
            }
        }
        store.execute(query)
    }

    func queryCycle() {
        guard let type = HKObjectType.categoryType(forIdentifier: .menstrualFlow) else { return }
        let start = Calendar.current.date(byAdding: .month, value: -12, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { [weak self] _, samples, _ in
            let flowSamples = (samples as? [HKCategorySample]) ?? []
            let periodDays = Set(flowSamples
                .filter { $0.value != HKCategoryValueMenstrualFlow.unspecified.rawValue }
                .map { Calendar.current.startOfDay(for: $0.startDate) })
            guard let lastPeriodStart = periodDays.sorted(by: >).first else {
                DispatchQueue.main.async {
                    self?.cycleSummary = .unavailable
                }
                return
            }

            let now = Calendar.current.startOfDay(for: Date())
            let cycleLength = 28
            let daysSince = max(Calendar.current.dateComponents([.day], from: lastPeriodStart, to: now).day ?? 0, 0)
            let currentDay = (daysSince % cycleLength) + 1
            let cyclesElapsed = daysSince / cycleLength + 1
            let next = Calendar.current.date(byAdding: .day, value: cyclesElapsed * cycleLength, to: lastPeriodStart)
            let daysUntil = next.flatMap { Calendar.current.dateComponents([.day], from: now, to: $0).day }
            let phase = Self.phase(forCycleDay: currentDay)
            let summary = CycleSummary(
                status: "Apple Health",
                currentDay: currentDay,
                phase: phase.name,
                nextPeriod: next,
                daysUntilNextPeriod: daysUntil,
                detail: phase.detail
            )
            DispatchQueue.main.async {
                self?.cycleSummary = summary
            }
        }
        store.execute(query)
    }

    static func phase(forCycleDay day: Int) -> (name: String, detail: String) {
        switch day {
        case 1...5:
            return ("Menstrual", "Bajan estrogeno y progesterona; es comun sentir menos energia. Prioriza recuperacion, movilidad y entrenamiento suave si lo necesitas.")
        case 6...13:
            return ("Folicular", "El estrogeno suele subir y muchas personas toleran mejor fuerza, tecnica e intensidad progresiva.")
        case 14...16:
            return ("Ovulatoria", "La ventana ovulatoria puede traer mejor energia, pero tambien mas sensibilidad articular en algunas personas.")
        default:
            return ("Lutea", "La progesterona sube; puede aumentar temperatura, retencion y fatiga. Ajusta intensidad segun HRV, sueno y sintomas.")
        }
    }
}
#endif
