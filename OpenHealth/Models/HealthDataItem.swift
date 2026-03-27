import Foundation
import SwiftData

@Model
class HealthDataItem {
    var id: UUID
    var type: HealthDataType
    var value: Double
    var unit: String
    var startDate: Date
    var endDate: Date
    var source: String
    var synced: Bool
    var lastSyncAttempt: Date?
    
    init(
        id: UUID = UUID(),
        type: HealthDataType,
        value: Double,
        unit: String,
        startDate: Date,
        endDate: Date,
        source: String,
        synced: Bool = false,
        lastSyncAttempt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.unit = unit
        self.startDate = startDate
        self.endDate = endDate
        self.source = source
        self.synced = synced
        self.lastSyncAttempt = lastSyncAttempt
    }
}

enum HealthDataType: String, Codable, CaseIterable, Identifiable {
    case stepCount = "stepCount"
    case bodyMass = "bodyMass"
    case heartRate = "heartRate"
    case restingHeartRate = "restingHeartRate"
    case bloodPressureSystolic = "bloodPressureSystolic"
    case bloodPressureDiastolic = "bloodPressureDiastolic"
    case oxygenSaturation = "oxygenSaturation"
    case activeEnergyBurned = "activeEnergyBurned"
    case sleepAnalysis = "sleepAnalysis"
    case respiratoryRate = "respiratoryRate"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .stepCount: return "Schritte"
        case .bodyMass: return "Gewicht"
        case .heartRate: return "Herzfrequenz"
        case .restingHeartRate: return "Ruheherzfrequenz"
        case .bloodPressureSystolic: return "Blutdruck (sys)"
        case .bloodPressureDiastolic: return "Blutdruck (dia)"
        case .oxygenSaturation: return "Blutsauerstoff"
        case .activeEnergyBurned: return "Aktive Energie"
        case .sleepAnalysis: return "Schlaf"
        case .respiratoryRate: return "Atemfrequenz"
        }
    }
    
    var unit: String {
        switch self {
        case .stepCount: return "count"
        case .bodyMass: return "kg"
        case .heartRate, .restingHeartRate: return "bpm"
        case .bloodPressureSystolic, .bloodPressureDiastolic: return "mmHg"
        case .oxygenSaturation: return "%"
        case .activeEnergyBurned: return "kcal"
        case .sleepAnalysis: return "hours"
        case .respiratoryRate: return "breaths/min"
        }
    }
    
    var icon: String {
        switch self {
        case .stepCount: return "figure.walk"
        case .bodyMass: return "scalemass"
        case .heartRate, .restingHeartRate: return "heart.fill"
        case .bloodPressureSystolic, .bloodPressureDiastolic: return "waveform.path.ecg"
        case .oxygenSaturation: return "lungs.fill"
        case .activeEnergyBurned: return "flame.fill"
        case .sleepAnalysis: return "bed.double.fill"
        case .respiratoryRate: return "wind"
        }
    }
}
