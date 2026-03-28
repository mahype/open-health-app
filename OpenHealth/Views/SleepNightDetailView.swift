import SwiftUI
import Charts

struct SleepNightDetailView: View {
    let date: Date
    let sleepItems: [HealthDataItem]

    private var sortedItems: [HealthDataItem] {
        sleepItems.sorted { $0.startDate < $1.startDate }
    }

    private var totalHours: Double {
        sleepItems.map(\.value).reduce(0, +)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Total sleep summary
                sleepSummaryCard
                    .padding(.horizontal)

                // Hypnogram
                hypnogramSection
                    .padding(.horizontal)

                // Stage breakdown
                stageBreakdownCard
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(date.formatted(.dateTime.day().month(.wide).weekday(.wide)))
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Summary

    private var sleepSummaryCard: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Gesamtschlaf")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f Std", totalHours))
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Spacer()

            if let first = sortedItems.first, let last = sortedItems.last {
                VStack(spacing: 4) {
                    Text("Schlafzeit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(first.startDate.formatted(.dateTime.hour().minute())) – \(last.endDate.formatted(.dateTime.hour().minute()))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - Hypnogram

    private var hypnogramSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Schlafverlauf")
                .font(.subheadline)
                .fontWeight(.semibold)

            if sortedItems.isEmpty {
                Text("Keine Daten")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
            } else {
                hypnogramChart
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private var hypnogramChart: some View {
        Chart {
            ForEach(sortedItems, id: \.id) { item in
                let stage = item.sleepStageEnum ?? .core
                // Use RectangleMark spanning from startDate to endDate at the stage's y-level
                RectangleMark(
                    xStart: .value("Start", item.startDate),
                    xEnd: .value("Ende", item.endDate),
                    yStart: .value("PhaseStart", stageYPosition(stage) - 0.4),
                    yEnd: .value("PhaseEnd", stageYPosition(stage) + 0.4)
                )
                .foregroundStyle(stage.color)
            }
        }
        .chartYScale(domain: -0.5...3.5)
        .chartYAxis {
            AxisMarks(values: [0, 1, 2, 3]) { value in
                AxisValueLabel {
                    if let intVal = value.as(Int.self) {
                        Text(stageLabelForY(intVal))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                AxisGridLine()
            }
        }
        .frame(height: 200)
    }

    /// Maps a sleep stage to a Y position (awake at top = 3, deep at bottom = 0)
    private func stageYPosition(_ stage: SleepStage) -> Double {
        switch stage {
        case .deep: return 0
        case .core: return 1
        case .rem: return 2
        case .awake: return 3
        }
    }

    private func stageLabelForY(_ y: Int) -> String {
        switch y {
        case 0: return "Tief"
        case 1: return "Leicht"
        case 2: return "REM"
        case 3: return "Wach"
        default: return ""
        }
    }

    // MARK: - Stage Breakdown

    private var stageBreakdownCard: some View {
        let byStage = Dictionary(grouping: sleepItems) { $0.sleepStageEnum ?? .core }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Schlafphasen")
                .font(.subheadline)
                .fontWeight(.semibold)

            // Stacked bar
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(SleepStage.allCases) { stage in
                        let hours = byStage[stage]?.map(\.value).reduce(0, +) ?? 0
                        let fraction = totalHours > 0 ? CGFloat(hours / totalHours) : 0
                        if fraction > 0 {
                            Rectangle()
                                .fill(stage.color)
                                .frame(width: geo.size.width * fraction)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .frame(height: 20)

            // Per-stage details
            ForEach(SleepStage.allCases) { stage in
                let hours = byStage[stage]?.map(\.value).reduce(0, +) ?? 0
                let percentage = totalHours > 0 ? (hours / totalHours) * 100 : 0

                HStack(spacing: 10) {
                    Circle()
                        .fill(stage.color)
                        .frame(width: 10, height: 10)
                    Text(stage.displayName)
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.1f Std", hours))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .monospacedDigit()
                    Text(String(format: "(%.0f%%)", percentage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        SleepNightDetailView(date: Date(), sleepItems: [])
    }
}
