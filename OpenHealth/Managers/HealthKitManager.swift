import Foundation
import HealthKit

// MARK: - Errors

enum HealthError: Error, LocalizedError {
    case healthDataNotAvailable
    case quantityTypeNotAvailable
    case authorizationDenied
    
    var errorDescription: String? {
        switch self {
        case .healthDataNotAvailable:
            return "HealthKit ist auf diesem Gerät nicht verfügbar."
        case .quantityTypeNotAvailable:
            return "Der angeforderte Datentyp ist nicht verfügbar."
        case .authorizationDenied:
            return "Zugriff auf Gesundheitsdaten wurde verweigert."
        }
    }
}

// MARK: - HealthKit Manager

@MainActor
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    let healthStore = HKHealthStore()

    @Published var isAuthorized = false

    private static let authKey = "healthKitAuthorizationRequested"

    init() {
        self.isAuthorized = UserDefaults.standard.bool(forKey: Self.authKey)
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthError.healthDataNotAvailable
        }

        let typesToRead: Set<HKSampleType> = [
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
            HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!
        ]

        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
        UserDefaults.standard.set(true, forKey: Self.authKey)
        self.isAuthorized = true
    }

    func ensureAuthorization() async {
        if isAuthorized { return }
        do {
            try await requestAuthorization()
        } catch {
            print("Authorization error: \(error)")
        }
    }
    
    // MARK: - Fetch Data
    
    func fetchAllData(for date: Date) async -> [HealthDataItem] {
        let predicate = createDayPredicate(for: date)
        return await fetchAllData(predicate: predicate)
    }

    func fetchAllData(for date: Date, types: Set<HealthDataType>) async -> [HealthDataItem] {
        let predicate = createDayPredicate(for: date)
        return await fetchAllData(predicate: predicate, types: types)
    }

    func fetchData(for types: [HealthDataType], from startDate: Date, to endDate: Date) async -> [HealthDataItem] {
        let predicate = createRangePredicate(from: startDate, to: endDate)
        return await fetchAllData(predicate: predicate, types: Set(types))
    }

    private func fetchAllData(predicate: NSPredicate, types: Set<HealthDataType>? = nil) async -> [HealthDataItem] {
        var allItems: [HealthDataItem] = []
        let enabledTypes = types ?? Set(HealthDataType.allCases)

        if enabledTypes.contains(.stepCount) { await appendSteps(to: &allItems, predicate: predicate) }
        if enabledTypes.contains(.bodyMass) { await appendWeight(to: &allItems, predicate: predicate) }
        if enabledTypes.contains(.heartRate) { await appendHeartRate(to: &allItems, predicate: predicate) }
        if enabledTypes.contains(.bloodPressureSystolic) || enabledTypes.contains(.bloodPressureDiastolic) {
            await appendBloodPressure(to: &allItems, predicate: predicate)
        }
        if enabledTypes.contains(.oxygenSaturation) { await appendOxygenSaturation(to: &allItems, predicate: predicate) }
        if enabledTypes.contains(.activeEnergyBurned) { await appendActiveEnergy(to: &allItems, predicate: predicate) }
        if enabledTypes.contains(.sleepAnalysis) { await appendSleep(to: &allItems, predicate: predicate) }
        if enabledTypes.contains(.respiratoryRate) { await appendRespiratoryRate(to: &allItems, predicate: predicate) }

        return allItems
    }
    
    // MARK: - Individual Fetch Methods
    
    private func appendSteps(to items: inout [HealthDataItem], predicate: NSPredicate) async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        do {
            let samples = try await fetchSamples(type: type, predicate: predicate)
            let stepItems = samples.compactMap { sample -> HealthDataItem? in
                guard let quantitySample = sample as? HKQuantitySample else { return nil }
                return HealthDataItem(
                    type: .stepCount,
                    value: quantitySample.quantity.doubleValue(for: .count()),
                    unit: "count",
                    startDate: quantitySample.startDate,
                    endDate: quantitySample.endDate,
                    source: quantitySample.sourceRevision.source.name
                )
            }
            items.append(contentsOf: stepItems)
        } catch {
            print("Error fetching steps: \(error)")
        }
    }
    
    private func appendWeight(to items: inout [HealthDataItem], predicate: NSPredicate) async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }

        do {
            let samples = try await fetchSamples(type: type, predicate: predicate)
            let weightItems = samples.compactMap { sample -> HealthDataItem? in
                guard let quantitySample = sample as? HKQuantitySample else { return nil }
                return HealthDataItem(
                    type: .bodyMass,
                    value: quantitySample.quantity.doubleValue(for: .gramUnit(with: .kilo)),
                    unit: "kg",
                    startDate: quantitySample.startDate,
                    endDate: quantitySample.endDate,
                    source: quantitySample.sourceRevision.source.name
                )
            }
            items.append(contentsOf: weightItems)
        } catch {
            print("Error fetching weight: \(error)")
        }
    }
    
    private func appendHeartRate(to items: inout [HealthDataItem], predicate: NSPredicate) async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        do {
            let samples = try await fetchSamples(type: type, predicate: predicate)
            let heartRateItems = samples.compactMap { sample -> HealthDataItem? in
                guard let quantitySample = sample as? HKQuantitySample else { return nil }
                return HealthDataItem(
                    type: .heartRate,
                    value: quantitySample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
                    unit: "bpm",
                    startDate: quantitySample.startDate,
                    endDate: quantitySample.endDate,
                    source: quantitySample.sourceRevision.source.name
                )
            }
            items.append(contentsOf: heartRateItems)
        } catch {
            print("Error fetching heart rate: \(error)")
        }
    }
    
    private func appendBloodPressure(to items: inout [HealthDataItem], predicate: NSPredicate) async {
        // Fetch systolic
        if let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic) {
            do {
                let samples = try await fetchSamples(type: systolicType, predicate: predicate)
                let bpItems = samples.compactMap { sample -> HealthDataItem? in
                    guard let quantitySample = sample as? HKQuantitySample else { return nil }
                    return HealthDataItem(
                        type: .bloodPressureSystolic,
                        value: quantitySample.quantity.doubleValue(for: .millimeterOfMercury()),
                        unit: "mmHg",
                        startDate: quantitySample.startDate,
                        endDate: quantitySample.endDate,
                        source: quantitySample.sourceRevision.source.name
                    )
                }
                items.append(contentsOf: bpItems)
            } catch {}
        }
        
        // Fetch diastolic
        if let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) {
            do {
                let samples = try await fetchSamples(type: diastolicType, predicate: predicate)
                let bpItems = samples.compactMap { sample -> HealthDataItem? in
                    guard let quantitySample = sample as? HKQuantitySample else { return nil }
                    return HealthDataItem(
                        type: .bloodPressureDiastolic,
                        value: quantitySample.quantity.doubleValue(for: .millimeterOfMercury()),
                        unit: "mmHg",
                        startDate: quantitySample.startDate,
                        endDate: quantitySample.endDate,
                        source: quantitySample.sourceRevision.source.name
                    )
                }
                items.append(contentsOf: bpItems)
            } catch {}
        }
    }
    
    private func appendOxygenSaturation(to items: inout [HealthDataItem], predicate: NSPredicate) async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else { return }

        do {
            let samples = try await fetchSamples(type: type, predicate: predicate)
            let o2Items = samples.compactMap { sample -> HealthDataItem? in
                guard let quantitySample = sample as? HKQuantitySample else { return nil }
                return HealthDataItem(
                    type: .oxygenSaturation,
                    value: quantitySample.quantity.doubleValue(for: .percent()) * 100,
                    unit: "%",
                    startDate: quantitySample.startDate,
                    endDate: quantitySample.endDate,
                    source: quantitySample.sourceRevision.source.name
                )
            }
            items.append(contentsOf: o2Items)
        } catch {
            print("Error fetching oxygen saturation: \(error)")
        }
    }
    
    private func appendActiveEnergy(to items: inout [HealthDataItem], predicate: NSPredicate) async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }

        do {
            let samples = try await fetchSamples(type: type, predicate: predicate)
            let energyItems = samples.compactMap { sample -> HealthDataItem? in
                guard let quantitySample = sample as? HKQuantitySample else { return nil }
                return HealthDataItem(
                    type: .activeEnergyBurned,
                    value: quantitySample.quantity.doubleValue(for: .kilocalorie()),
                    unit: "kcal",
                    startDate: quantitySample.startDate,
                    endDate: quantitySample.endDate,
                    source: quantitySample.sourceRevision.source.name
                )
            }
            items.append(contentsOf: energyItems)
        } catch {
            print("Error fetching active energy: \(error)")
        }
    }
    
    private func appendSleep(to items: inout [HealthDataItem], predicate: NSPredicate) async {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        do {
            let samples = try await fetchSamples(type: type, predicate: predicate)
            let sleepItems = samples.compactMap { sample -> HealthDataItem? in
                guard let categorySample = sample as? HKCategorySample else { return nil }

                let stage: SleepStage
                switch categorySample.value {
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                    stage = .core
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    stage = .deep
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    stage = .rem
                case HKCategoryValueSleepAnalysis.awake.rawValue:
                    stage = .awake
                case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                    stage = .core // Fallback for devices without stage tracking
                case HKCategoryValueSleepAnalysis.inBed.rawValue:
                    return nil // Skip inBed to avoid double-counting
                default:
                    return nil
                }

                let hours = categorySample.endDate.timeIntervalSince(categorySample.startDate) / 3600
                return HealthDataItem(
                    type: .sleepAnalysis,
                    value: hours,
                    unit: "hours",
                    startDate: categorySample.startDate,
                    endDate: categorySample.endDate,
                    source: categorySample.sourceRevision.source.name,
                    sleepStage: stage
                )
            }
            items.append(contentsOf: sleepItems)
        } catch {
            print("Error fetching sleep: \(error)")
        }
    }
    
    private func appendRespiratoryRate(to items: inout [HealthDataItem], predicate: NSPredicate) async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else { return }

        do {
            let samples = try await fetchSamples(type: type, predicate: predicate)
            let rateItems = samples.compactMap { sample -> HealthDataItem? in
                guard let quantitySample = sample as? HKQuantitySample else { return nil }
                return HealthDataItem(
                    type: .respiratoryRate,
                    value: quantitySample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
                    unit: "breaths/min",
                    startDate: quantitySample.startDate,
                    endDate: quantitySample.endDate,
                    source: quantitySample.sourceRevision.source.name
                )
            }
            items.append(contentsOf: rateItems)
        } catch {
            print("Error fetching respiratory rate: \(error)")
        }
    }
    
    // MARK: - Generic Fetch
    
    nonisolated private func fetchSamples(type: HKSampleType, predicate: NSPredicate) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - Statistics
    
    func fetchStepCount(for date: Date) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return 0
        }
        
        let predicate = createDayPredicate(for: date)
        
        do {
            return try await withCheckedThrowingContinuation { continuation in
                let query = HKStatisticsQuery(
                    quantityType: type,
                    quantitySamplePredicate: predicate,
                    options: .cumulativeSum
                ) { _, statistics, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        let sum = statistics?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                        continuation.resume(returning: sum)
                    }
                }
                self.healthStore.execute(query)
            }
        } catch {
            print("Error fetching step count: \(error)")
            return 0
        }
    }
    
    // MARK: - Helpers
    
    nonisolated func createRangePredicate(from startDate: Date, to endDate: Date) -> NSPredicate {
        HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
    }

    nonisolated private func createDayPredicate(for date: Date) -> NSPredicate {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        
        return HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
    }
    
    func checkAuthorizationStatus() {
        self.isAuthorized = UserDefaults.standard.bool(forKey: Self.authKey)
    }
}
