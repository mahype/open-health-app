import Foundation
import SwiftData

// MARK: - Aggregation Granularity

enum AggregationGranularity: String {
    case daily = "daily"
    case weekly = "weekly"
}

// MARK: - Aggregated Data Point Model

@Model
final class AggregatedDataPoint {
    var dataTypeRaw: String
    var granularityRaw: String  // "daily" or "weekly"
    var periodStart: Date
    var avg: Double
    var sum: Double
    var min: Double
    var max: Double
    var count: Int
    var computedAt: Date
    @Attribute(.unique) var rangeKey: String

    init(
        dataTypeRaw: String,
        granularityRaw: String,
        periodStart: Date,
        avg: Double,
        sum: Double,
        min: Double,
        max: Double,
        count: Int,
        rangeKey: String
    ) {
        self.dataTypeRaw = dataTypeRaw
        self.granularityRaw = granularityRaw
        self.periodStart = periodStart
        self.avg = avg
        self.sum = sum
        self.min = min
        self.max = max
        self.count = count
        self.computedAt = Date()
        self.rangeKey = rangeKey
    }
}
