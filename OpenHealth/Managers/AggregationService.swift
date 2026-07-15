import Foundation
import SwiftData

// MARK: - Aggregation Service
// @MainActor because ModelContext is not Sendable — all operations run on main actor.

@MainActor
final class AggregationService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public API

    /// Compute and persist daily + weekly aggregates for the given raw items.
    func persistAggregates(for items: [HealthDataItem], dataType: HealthDataType) {
        guard !items.isEmpty else { return }

        let dailyGroups = grouped(items, by: .daily)
        upsert(groups: dailyGroups, dataType: dataType, granularity: .daily, summing: dataType.usesBarChart)

        let weeklyGroups = grouped(items, by: .weekly)
        upsert(groups: weeklyGroups, dataType: dataType, granularity: .weekly, summing: dataType.usesBarChart)
    }

    /// Background-prefetch aggregates for direct neighbor ranges.
    func prefetchNeighbors(
        currentRange: ChartTimeRange,
        dataType: HealthDataType,
        healthKitManager: HealthKitManager
    ) {
        let neighbors = neighborRanges(for: currentRange)
        for range in neighbors {
            Task { [weak self] in
                guard let self else { return }
                let items = await healthKitManager.fetchData(
                    for: [dataType],
                    from: range.startDate,
                    to: Date()
                )
                self.persistAggregates(for: items, dataType: dataType)
            }
        }
    }

    // MARK: - Private Helpers

    private struct PeriodGroup {
        let periodStart: Date
        let values: [Double]
    }

    private func grouped(_ items: [HealthDataItem], by granularity: AggregationGranularity) -> [PeriodGroup] {
        let calendar = Calendar.current
        let buckets: [Date: [Double]]

        switch granularity {
        case .daily:
            buckets = Dictionary(grouping: items) { calendar.startOfDay(for: $0.startDate) }
                .mapValues { $0.map(\.value) }
        case .weekly:
            buckets = Dictionary(grouping: items) { item -> Date in
                let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: item.startDate)
                return calendar.date(from: comps) ?? item.startDate
            }.mapValues { $0.map(\.value) }
        }

        return buckets.map { PeriodGroup(periodStart: $0.key, values: $0.value) }
    }

    private func upsert(
        groups: [PeriodGroup],
        dataType: HealthDataType,
        granularity: AggregationGranularity,
        summing: Bool
    ) {
        for group in groups {
            guard !group.values.isEmpty else { continue }
            let values = group.values
            let sum = values.reduce(0, +)
            let avg = summing ? sum : sum / Double(values.count)
            let minVal = values.min() ?? 0
            let maxVal = values.max() ?? 0
            let count = values.count

            let key = "\(dataType.rawValue)_\(granularity.rawValue)_\(Int(group.periodStart.timeIntervalSince1970))"

            let descriptor = FetchDescriptor<AggregatedDataPoint>(
                predicate: #Predicate { $0.rangeKey == key }
            )

            if let existing = try? modelContext.fetch(descriptor).first {
                existing.avg = avg
                existing.sum = sum
                existing.min = minVal
                existing.max = maxVal
                existing.count = count
                existing.computedAt = Date()
            } else {
                modelContext.insert(AggregatedDataPoint(
                    dataTypeRaw: dataType.rawValue,
                    granularityRaw: granularity.rawValue,
                    periodStart: group.periodStart,
                    avg: avg,
                    sum: sum,
                    min: minVal,
                    max: maxVal,
                    count: count,
                    rangeKey: key
                ))
            }
        }
    }

    private func neighborRanges(for range: ChartTimeRange) -> [ChartTimeRange] {
        switch range {
        case .sevenDays:    return [.thirtyDays]
        case .thirtyDays:   return [.sevenDays, .ninetyDays]
        case .ninetyDays:   return [.thirtyDays, .sixMonths]
        case .sixMonths:    return [.ninetyDays, .oneYear]
        case .oneYear:      return [.sixMonths]
        case .custom:       return []
        }
    }
}
