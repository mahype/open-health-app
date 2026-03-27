import Foundation
import HealthKit

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
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!
        ].compactMap { $0 as HKObjectType? }
        
        try await healthStore.requestAuthorization(toShare: nil, read: typesToRead)
        
        await MainActor.run {
            self.isAuthorized = true
        }
    }
    
    // MARK: - Fetch All Data Types
    
    func fetchAllData(for date: Date) async throws -> [HealthDataItem] {
        var allItems: [HealthDataItem] = []
        
        // Fetch all data types
        async let steps = fetchSteps(for: date)
        async let weight = fetchWeight(for: date)
        async let heartRate = fetchHeartRate(for: date)
        async let bloodPressure = fetchBloodPressure(for: date)
        async let oxygenSaturation = fetchOxygenSaturation(for: date)
        async let activeEnergy = fetchActiveEnergy(for: date)
        async let sleep = fetchSleep(for: date)
        async let respiratoryRate = fetchRespiratoryRate(for: date)
        
        // Combine results
        allItems += (try? await steps) ?? []
        allItems += (try? await weight) ?? []
        allItems += (try? await heartRate) ?? []
        allItems += (try? await bloodPressure) ?? []
        allItems += (try? await oxygenSaturation) ?? []
        allItems += (try? await activeEnergy) ?? []
        allItems += (try? await sleep) ?? []
        allItems += (try? await respiratoryRate) ?? []
        
        return allItems
    }
    
    // MARK: - Individual Fetch Methods
    
    func fetchSteps(for date: Date) async throws -> [HealthDataItem] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return []
        }
        
        let predicate = createDayPredicate(for: date)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let items = (samples as? [HKQuantitySample])?.map { sample in
                    HealthDataItem(
                        type: .stepCount,
                        value: sample.quantity.doubleValue(for: .count()),
                        unit: "count",
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        source: sample.sourceRevision.source.name
                    )
                } ?? []
                
                continuation.resume(returning: items)
            }
            
            self.healthStore.execute(query)
        }
    }
    
    func fetchWeight(for date: Date) async throws -> [HealthDataItem] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            return []
        }
        
        let predicate = createDayPredicate(for: date)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let items = (samples as? [HKQuantitySample])?.map { sample in
                    HealthDataItem(
                        type: .bodyMass,
                        value: sample.quantity.doubleValue(for: .gramUnit(with: .kilo)),
                        unit: "kg",
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        source: sample.sourceRevision.source.name
                    )
                } ?? []
                
                continuation.resume(returning: items)
            }
            
            self.healthStore.execute(query)
        }
    }
    
    func fetchHeartRate(for date: Date) async throws -> [HealthDataItem] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return []
        }
        
        let predicate = createDayPredicate(for: date)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let items = (samples as? [HKQuantitySample])?.map { sample in
                    HealthDataItem(
                        type: .heartRate,
                        value: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
                        unit: "bpm",
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        source: sample.sourceRevision.source.name
                    )
                } ?? []
                
                continuation.resume(returning: items)
            }
            
            self.healthStore.execute(query)
        }
    }
    
    func fetchBloodPressure(for date: Date) async throws -> [HealthDataItem] {
        var items: [HealthDataItem] = []
        
        // Fetch systolic
        if let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic) {
            let predicate = createDayPredicate(for: date)
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let query = HKSampleQuery(
                    sampleType: systolicType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { _, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    let systolicItems = (samples as? [HKQuantitySample])?.map { sample in
                        HealthDataItem(
                            type: .bloodPressureSystolic,
                            value: sample.quantity.doubleValue(for: .millimeterOfMercury()),
                            unit: "mmHg",
                            startDate: sample.startDate,
                            endDate: sample.endDate,
                            source: sample.sourceRevision.source.name
                        )
                    } ?? []
                    items += systolicItems
                    continuation.resume()
                }
                
                self.healthStore.execute(query)
            }
        }
        
        // Fetch diastolic
        if let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) {
            let predicate = createDayPredicate(for: date)
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let query = HKSampleQuery(
                    sampleType: diastolicType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { _, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    let diastolicItems = (samples as? [HKQuantitySample])?.map { sample in
                        HealthDataItem(
                            type: .bloodPressureDiastolic,
                            value: sample.quantity.doubleValue(for: .millimeterOfMercury()),
                            unit: "mmHg",
                            startDate: sample.startDate,
                            endDate: sample.endDate,
                            source: sample.sourceRevision.source.name
                        )
                    } ?? []
                    items += diastolicItems
                    continuation.resume()
                }
                
                self.healthStore.execute(query)
            }
        }
        
        return items
    }
    
    func fetchOxygenSaturation(for date: Date) async throws -> [HealthDataItem] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else {
            return []
        }
        
        let predicate = createDayPredicate(for: date)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let items = (samples as? [HKQuantitySample])?.map { sample in
                    HealthDataItem(
                        type: .oxygenSaturation,
                        value: sample.quantity.doubleValue(for: .percent()) * 100,
                        unit: "%",
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        source: sample.sourceRevision.source.name
                    )
                } ?? []
                
                continuation.resume(returning: items)
            }
            
            self.healthStore.execute(query)
        }
    }
    
    func fetchActiveEnergy(for date: Date) async throws -> [HealthDataItem] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return []
        }
        
        let predicate = createDayPredicate(for: date)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let items = (samples as? [HKQuantitySample])?.map { sample in
                    HealthDataItem(
                        type: .activeEnergyBurned,
                        value: sample.quantity.doubleValue(for: .kilocalorie()),
                        unit: "kcal",
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        source: sample.sourceRevision.source.name
                    )
                } ?? []
                
                continuation.resume(returning: items)
            }
            
            self.healthStore.execute(query)
        }
    }
    
    func fetchSleep(for date: Date) async throws -> [HealthDataItem] {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return []
        }
        
        let predicate = createDayPredicate(for: date)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let items = (samples as? [HKCategorySample])?.map { sample in
                    let hours = sample.endDate.timeIntervalSince(sample.startDate) / 3600
                    return HealthDataItem(
                        type: .sleepAnalysis,
                        value: hours,
                        unit: "hours",
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        source: sample.sourceRevision.source.name
                    )
                } ?? []
                
                continuation.resume(returning: items)
            }
            
            self.healthStore.execute(query)
        }
    }
    
    func fetchRespiratoryRate(for date: Date) async throws -> [HealthDataItem] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else {
            return []
        }
        
        let predicate = createDayPredicate(for: date)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let items = (samples as? [HKQuantitySample])?.map { sample in
                    HealthDataItem(
                        type: .respiratoryRate,
                        value: sample.quantity.doubleValue(for: .count().unitDivided(by: .minute())),
                        unit: "breaths/min",
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        source: sample.sourceRevision.source.name
                    )
                } ?? []
                
                continuation.resume(returning: items)
            }
            
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createDayPredicate(for date: Date) -> NSPredicate {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        
        return HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
    }
    
    // MARK: - Statistics (Aggregated Data)
    
    func fetchStepCount(for date: Date) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return 0
        }
        
        let predicate = createDayPredicate(for: date)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let sum = statistics?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                continuation.resume(returning: sum)
            }
            
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - Helper
    
    func checkAuthorizationStatus() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        let status = healthStore.authorizationStatus(for: stepType)
        self.authorizationStatus = status
        self.isAuthorized = status == .sharingAuthorized
    }
    
    // MARK: - Background Delivery (Observer Queries)
    
    func setupBackgroundDelivery(for type: HealthDataType, completion: @escaping () -> Void) {
        let hkType: HKSampleType?
        
        switch type {
        case .stepCount:
            hkType = HKQuantityType.quantityType(forIdentifier: .stepCount)
        case .bodyMass:
            hkType = HKQuantityType.quantityType(forIdentifier: .bodyMass)
        case .heartRate, .restingHeartRate:
            hkType = HKQuantityType.quantityType(forIdentifier: .heartRate)
        case .bloodPressureSystolic, .bloodPressureDiastolic:
            hkType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)
        case .oxygenSaturation:
            hkType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)
        case .activeEnergyBurned:
            hkType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        case .sleepAnalysis:
            hkType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)
        case .respiratoryRate:
            hkType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate)
        }
        
        guard let sampleType = hkType else { return }
        
        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completionHandler, error in
            if let error = error {
                print("Observer query error: \(error)")
                completionHandler()
                return
            }
            
            completion()
            completionHandler()
        }
        
        healthStore.execute(query)
        
        healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate) { success, error in
            if let error = error {
                print("Background delivery error: \(error)")
            }
        }
    }
}

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
