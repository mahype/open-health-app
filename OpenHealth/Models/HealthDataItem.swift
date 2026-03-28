import Foundation
import SwiftData
import SwiftUI

// MARK: - Sleep Stage

enum SleepStage: String, Codable, CaseIterable, Identifiable {
    case deep = "deep"
    case core = "core"
    case rem = "rem"
    case awake = "awake"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .deep: return "Tiefschlaf"
        case .core: return "Leichtschlaf"
        case .rem: return "REM"
        case .awake: return "Wach"
        }
    }

    var color: Color {
        switch self {
        case .deep: return .indigo
        case .core: return .blue
        case .rem: return .teal
        case .awake: return .orange
        }
    }

    /// Sort order for stacking: deep at bottom (0), awake at top (3)
    var sortOrder: Int {
        switch self {
        case .deep: return 0
        case .core: return 1
        case .rem: return 2
        case .awake: return 3
        }
    }
}

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
    var sleepStage: String?

    var sleepStageEnum: SleepStage? {
        guard let sleepStage else { return nil }
        return SleepStage(rawValue: sleepStage)
    }

    init(
        id: UUID = UUID(),
        type: HealthDataType,
        value: Double,
        unit: String,
        startDate: Date,
        endDate: Date,
        source: String,
        synced: Bool = false,
        lastSyncAttempt: Date? = nil,
        sleepStage: SleepStage? = nil
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
        self.sleepStage = sleepStage?.rawValue
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

    var color: Color {
        switch self {
        case .stepCount: return .blue
        case .bodyMass: return .purple
        case .heartRate: return .red
        case .restingHeartRate: return .pink
        case .bloodPressureSystolic: return .red
        case .bloodPressureDiastolic: return .blue
        case .oxygenSaturation: return .cyan
        case .activeEnergyBurned: return .orange
        case .sleepAnalysis: return .indigo
        case .respiratoryRate: return .teal
        }
    }

    var usesBarChart: Bool {
        switch self {
        case .stepCount, .activeEnergyBurned, .sleepAnalysis: return true
        default: return false
        }
    }

    func formattedValue(_ value: Double) -> String {
        switch self {
        case .stepCount: return String(format: "%.0f", value)
        case .bodyMass: return String(format: "%.1f kg", value)
        case .heartRate, .restingHeartRate: return String(format: "%.0f bpm", value)
        case .bloodPressureSystolic, .bloodPressureDiastolic: return String(format: "%.0f mmHg", value)
        case .oxygenSaturation: return String(format: "%.1f%%", value)
        case .activeEnergyBurned: return String(format: "%.0f kcal", value)
        case .sleepAnalysis: return String(format: "%.1f Std", value)
        case .respiratoryRate: return String(format: "%.0f /min", value)
        }
    }
}

// MARK: - Enabled Types Persistence

enum EnabledTypesStore {
    private static let key = "enabledHealthDataTypes"
    private static let defaultTypes: Set<HealthDataType> = [.stepCount, .heartRate, .bodyMass]

    static func load() -> Set<HealthDataType> {
        guard let data = UserDefaults.standard.data(forKey: key),
              let rawValues = try? JSONDecoder().decode([String].self, from: data) else {
            return defaultTypes
        }
        return Set(rawValues.compactMap { HealthDataType(rawValue: $0) })
    }

    static func save(_ types: Set<HealthDataType>) {
        let rawValues = types.map { $0.rawValue }
        if let data = try? JSONEncoder().encode(rawValues) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Export Model

struct HealthDataExportItem: Codable {
    let id: String
    let type: String
    let value: Double
    let unit: String
    let startDate: Date
    let endDate: Date
    let source: String
    let sleepStage: String?

    init(from item: HealthDataItem) {
        self.id = item.id.uuidString
        self.type = item.type.rawValue
        self.value = item.value
        self.unit = item.unit
        self.startDate = item.startDate
        self.endDate = item.endDate
        self.source = item.source
        self.sleepStage = item.sleepStage
    }
}
