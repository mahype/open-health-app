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
    
    // MARK: - Fetch Data
    
    func fetchSteps(for date: Date) async throws -> [HealthDataItem] {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthError.quantityTypeNotAvailable
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: date),
            end: Calendar.current.date(byAdding: .day, value: 1, to: date),
            options: .strictStartDate
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: stepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
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
        // TODO: Implement
        return []
    }
    
    func fetchHeartRate(for date: Date) async throws -> [HealthDataItem] {
        // TODO: Implement
        return []
    }
    
    // MARK: - Helper
    
    func checkAuthorizationStatus() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        authorizationStatus = healthStore.authorizationStatus(for: stepType)
        isAuthorized = authorizationStatus == .sharingAuthorized
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
