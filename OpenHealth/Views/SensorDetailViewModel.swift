import Foundation

// MARK: - Sensor Detail View Model
// Pure static helpers — no state, no side effects.

enum SensorDetailViewModel {

    // MARK: - Chart Points

    /// Returns chart points for the given items and range.
    /// Prefers persisted aggregates when available; falls back to computing from raw items.
    static func chartPoints(
        rawItems: [HealthDataItem],
        aggregates: [AggregatedDataPoint],
        dataType: HealthDataType,
        selectedRange: ChartTimeRange
    ) -> [(date: Date, value: Double)] {
        let useLong = selectedRange == .sixMonths || selectedRange == .oneYear
        let targetGranularity = useLong ? AggregationGranularity.weekly : .daily

        // Prefer pre-computed aggregates when present
        let matching = aggregates.filter { $0.granularityRaw == targetGranularity.rawValue }
        if !matching.isEmpty {
            return matching.sorted { $0.periodStart < $1.periodStart }.map { agg in
                (date: agg.periodStart, value: dataType.usesBarChart ? agg.sum : agg.avg)
            }
        }

        // Compute from raw items
        return useLong
            ? weeklyAggregates(from: rawItems, summing: dataType.usesBarChart)
            : dailyAggregates(from: rawItems, summing: dataType.usesBarChart)
    }

    // MARK: - Aggregate Helpers (also used by AggregationService via SensorDetailContent)

    static func dailyAggregates(
        from items: [HealthDataItem],
        summing: Bool
    ) -> [(date: Date, value: Double)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: items) { calendar.startOfDay(for: $0.startDate) }
        return grouped.map { date, group in
            let values = group.map(\.value)
            let sum = values.reduce(0, +)
            let value = summing ? sum : sum / Double(values.count)
            return (date: date, value: value)
        }.sorted { $0.date < $1.date }
    }

    static func weeklyAggregates(
        from items: [HealthDataItem],
        summing: Bool
    ) -> [(date: Date, value: Double)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: items) { item -> Date in
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: item.startDate)
            return calendar.date(from: comps) ?? item.startDate
        }
        return grouped.map { date, group in
            let values = group.map(\.value)
            let sum = values.reduce(0, +)
            let value = summing ? sum : sum / Double(values.count)
            return (date: date, value: value)
        }.sorted { $0.date < $1.date }
    }
}
