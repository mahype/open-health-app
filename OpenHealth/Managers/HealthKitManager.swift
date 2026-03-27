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
    
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    @Published var isAuthorized = false
    
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
        self.isAuthorized = true
    }
    
    // MARK: - Fetch Data
    
    func fetchAllData(for date: Date) async -> [HealthDataItem] {
        var allItems: [HealthDataItem] = []
        
        await appendSteps(to: &allItems, for: date)
        await appendWeight(to: &allItems, for: date)
        await appendHeartRate(to: &allItems, for: date)
        await appendBloodPressure(to: &allItems, for: date)
        await appendOxygenSaturation(to: &allItems, for: date)
        await appendActiveEnergy(to: &allItems, for: date)
        await appendSleep(to: &allItems, for: date)
        await appendRespiratoryRate(to: &allItems, for: date)
        
        return allItems
    }
    
    // MARK: - Individual Fetch Methods
    
    private func appendSteps(to items: inout [HealthDataItem], for date: Date) async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        let predicate = createDayPredicate(for: date)
        
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
    
    private func appendWeight(to items: inout [HealthDataItem], for date: Date) async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        
        let predicate = createDayPredicate(for: date)
        
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
    
    private func appendHeartRate(to items: inout [HealthDataItem], for date: Date) async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let predicate = createDayPredicate(for: date)
        
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
    
    private func appendBloodPressure(to items: inout [HealthDataItem], for date: Date) async {
        // Fetch systolic
        if let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic) {
            let predicate = createDayPredicate(for: date)
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
            let predicate = createDayPredicate(for: date)
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
    
    private func appendOxygenSaturation(to items: inout [HealthDataItem], for date: Date) async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else { return }
        
        let predicate = createDayPredicate(for: date)
        
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
    
    private func appendActiveEnergy(to items: inout [HealthDataItem], for date: Date) async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        
        let predicate = createDayPredicate(for: date)
        
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
    
    private func appendSleep(to items: inout [HealthDataItem], for date: Date) async {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        
        let predicate = createDayPredicate(for: date)
        
        do {
            let samples = try await fetchSamples(type: type, predicate: predicate)
            let sleepItems = samples.compactMap { sample -> HealthDataItem? in
                guard let categorySample = sample as? HKCategorySample else { return nil }
                let hours = categorySample.endDate.timeIntervalSince(categorySample.startDate) / 3600
                return HealthDataItem(
                    type: .sleepAnalysis,
                    value: hours,
                    unit: "hours",
                    startDate: categorySample.startDate,
                    endDate: categorySample.endDate,
                    source: categorySample.sourceRevision.source.name
                )
            }
            items.append(contentsOf: sleepItems)
        } catch {
            print("Error fetching sleep: \(error)")
        }
    }
    
    private func appendRespiratoryRate(to items: inout [HealthDataItem], for date: Date) async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else { return }
        
        let predicate = createDayPredicate(for: date)
        
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
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        let status = healthStore.authorizationStatus(for: stepType)
        self.authorizationStatus = status
        self.isAuthorized = status == .sharingAuthorized
    }
}
