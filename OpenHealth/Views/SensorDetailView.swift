import SwiftUI
import SwiftData
import Charts

// MARK: - Time Range

enum ChartTimeRange: String, CaseIterable, Identifiable {
    case sevenDays = "7d"
    case thirtyDays = "30d"
    case ninetyDays = "90d"
    case sixMonths = "6m"
    case oneYear = "1y"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sevenDays: return "7 Tage"
        case .thirtyDays: return "30 Tage"
        case .ninetyDays: return "90 Tage"
        case .sixMonths: return "6 Monate"
        case .oneYear: return "1 Jahr"
        }
    }

    var startDate: Date {
        let calendar = Calendar.current
        switch self {
        case .sevenDays: return calendar.date(byAdding: .day, value: -7, to: Date())!
        case .thirtyDays: return calendar.date(byAdding: .day, value: -30, to: Date())!
        case .ninetyDays: return calendar.date(byAdding: .day, value: -90, to: Date())!
        case .sixMonths: return calendar.date(byAdding: .month, value: -6, to: Date())!
        case .oneYear: return calendar.date(byAdding: .year, value: -1, to: Date())!
        }
    }
}

// MARK: - Sensor Detail View

struct SensorDetailView: View {
    let dataType: HealthDataType
    var isBloodPressure: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HealthDataItem.startDate, order: .reverse) private var allItems: [HealthDataItem]

    @StateObject private var healthKitManager = HealthKitManager.shared
    @State private var selectedRange: ChartTimeRange = .thirtyDays
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Time Range Picker
                Picker("Zeitraum", selection: $selectedRange) {
                    ForEach(ChartTimeRange.allCases) { range in
                        Text(range.displayName).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Summary Card
                summaryCard
                    .padding(.horizontal)

                // Chart
                chartSection
                    .padding(.horizontal)

                // Blood Pressure Extras
                if isBloodPressure {
                    bpClassificationCard
                        .padding(.horizontal)

                    pulsePressureCard
                        .padding(.horizontal)
                }

                // Recent Values
                recentValuesSection
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(isBloodPressure ? "Blutdruck" : dataType.displayName)
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .task(id: selectedRange) {
            await loadHistoricalData()
        }
    }

    // MARK: - Filtered Data

    private var filteredItems: [HealthDataItem] {
        let start = selectedRange.startDate
        if isBloodPressure {
            return allItems.filter {
                ($0.type == .bloodPressureSystolic || $0.type == .bloodPressureDiastolic)
                && $0.startDate >= start
            }.sorted { $0.startDate < $1.startDate }
        }
        return allItems.filter {
            $0.type == dataType && $0.startDate >= start
        }.sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        HStack(spacing: 16) {
            if isBloodPressure {
                summaryItem(title: "Aktuell", value: latestBPText)
                Divider().frame(height: 40)
                summaryItem(title: "Ø Systolisch", value: avgText(for: .bloodPressureSystolic))
                Divider().frame(height: 40)
                summaryItem(title: "Ø Diastolisch", value: avgText(for: .bloodPressureDiastolic))
            } else {
                summaryItem(title: "Aktuell", value: latestValueText)
                Divider().frame(height: 40)
                summaryItem(title: "Durchschnitt", value: avgText(for: dataType))
                Divider().frame(height: 40)
                summaryItem(title: "Einträge", value: "\(filteredItems.count)")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func summaryItem(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var latestValueText: String {
        guard let latest = filteredItems.last else { return "--" }
        return dataType.formattedValue(latest.value)
    }

    private var latestBPText: String {
        let sys = allItems.first(where: { $0.type == .bloodPressureSystolic })
        let dia = allItems.first(where: { $0.type == .bloodPressureDiastolic })
        if let s = sys, let d = dia {
            return "\(Int(s.value))/\(Int(d.value))"
        }
        return "--/--"
    }

    private func avgText(for type: HealthDataType) -> String {
        let items = filteredItems.filter { $0.type == type }
        guard !items.isEmpty else { return "--" }
        let avg = items.map(\.value).reduce(0, +) / Double(items.count)
        return type.formattedValue(avg)
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if filteredItems.isEmpty {
                noDataView
            } else if isBloodPressure {
                bloodPressureChart
            } else if dataType.usesBarChart {
                barChart
            } else {
                lineChart
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private var noDataView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Keine Daten für diesen Zeitraum")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }

    // MARK: - Line Chart

    private var lineChart: some View {
        Chart {
            ForEach(filteredItems, id: \.startDate) { item in
                LineMark(
                    x: .value("Datum", item.startDate),
                    y: .value(dataType.displayName, item.value)
                )
                .foregroundStyle(dataType.color)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value("Datum", item.startDate),
                    y: .value(dataType.displayName, item.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [dataType.color.opacity(0.15), dataType.color.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Datum", item.startDate),
                    y: .value(dataType.displayName, item.value)
                )
                .foregroundStyle(dataType.color)
                .symbolSize(filteredItems.count > 50 ? 0 : 16)
            }

            if dataType == .oxygenSaturation {
                RuleMark(y: .value("Referenz", 95))
                    .foregroundStyle(.red.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("95%")
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.7))
                    }
            }
        }
        .chartYAxisLabel(dataType.unit)
        .frame(height: 220)
    }

    // MARK: - Bar Chart

    private var barChart: some View {
        let aggregates = dailyAggregates
        return Chart(aggregates, id: \.date) { agg in
            BarMark(
                x: .value("Datum", agg.date, unit: .day),
                y: .value(dataType.displayName, agg.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [dataType.color, dataType.color.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(4)
        }
        .chartYAxisLabel(dataType.unit)
        .frame(height: 220)
    }

    private var dailyAggregates: [(date: Date, value: Double)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredItems) { item in
            calendar.startOfDay(for: item.startDate)
        }
        return grouped.map { (date: $0.key, value: $0.value.map(\.value).reduce(0, +)) }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Blood Pressure Chart

    private var bloodPressureChart: some View {
        let sysItems = filteredItems.filter { $0.type == .bloodPressureSystolic }
        let diaItems = filteredItems.filter { $0.type == .bloodPressureDiastolic }
        let ppData = pulsePressureData

        return Chart {
            ForEach(sysItems, id: \.startDate) { item in
                LineMark(
                    x: .value("Datum", item.startDate),
                    y: .value("mmHg", item.value)
                )
                .foregroundStyle(by: .value("Typ", "Systolisch"))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            ForEach(diaItems, id: \.startDate) { item in
                LineMark(
                    x: .value("Datum", item.startDate),
                    y: .value("mmHg", item.value)
                )
                .foregroundStyle(by: .value("Typ", "Diastolisch"))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            ForEach(ppData, id: \.date) { pp in
                LineMark(
                    x: .value("Datum", pp.date),
                    y: .value("mmHg", pp.value)
                )
                .foregroundStyle(by: .value("Typ", "Pulsdruck"))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
            }
        }
        .chartForegroundStyleScale([
            "Systolisch": Color.red,
            "Diastolisch": Color.blue,
            "Pulsdruck": Color.green
        ])
        .chartYAxisLabel("mmHg")
        .chartLegend(position: .bottom, spacing: 12)
        .frame(height: 250)
    }

    // MARK: - Pulse Pressure

    private var pulsePressureData: [(date: Date, value: Double)] {
        let sysItems = filteredItems.filter { $0.type == .bloodPressureSystolic }
        let diaItems = filteredItems.filter { $0.type == .bloodPressureDiastolic }

        return sysItems.compactMap { sys in
            guard let dia = diaItems.first(where: {
                abs($0.startDate.timeIntervalSince(sys.startDate)) < 60
            }) else { return nil as (date: Date, value: Double)? }
            return (date: sys.startDate, value: sys.value - dia.value)
        }
    }

    private var pulsePressureCard: some View {
        let ppData = pulsePressureData
        guard let latest = ppData.last else {
            return AnyView(EmptyView())
        }
        let avg = ppData.map(\.value).reduce(0, +) / Double(ppData.count)

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Label("Pulsdruck", systemImage: "arrow.up.arrow.down")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("Aktuell")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(latest.value)) mmHg")
                            .font(.headline)
                            .foregroundStyle(.green)
                    }

                    VStack(spacing: 4) {
                        Text("Durchschnitt")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(avg)) mmHg")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(spacing: 4) {
                        Text("Normal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("30–40 mmHg")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        )
    }

    // MARK: - BP Classification

    private var bpClassificationCard: some View {
        let latestSys = allItems.first(where: { $0.type == .bloodPressureSystolic })?.value ?? 0
        let latestDia = allItems.first(where: { $0.type == .bloodPressureDiastolic })?.value ?? 0
        let (label, color) = classifyBP(systolic: latestSys, diastolic: latestDia)

        return HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)

            Spacer()

            if latestSys > 0 {
                Text("\(Int(latestSys))/\(Int(latestDia)) mmHg")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }

    private func classifyBP(systolic: Double, diastolic: Double) -> (String, Color) {
        guard systolic > 0 else { return ("Keine Daten", .gray) }
        if systolic < 120 && diastolic < 80 { return ("Normal", .green) }
        if systolic < 130 && diastolic < 80 { return ("Erhöht", .yellow) }
        if systolic < 140 || diastolic < 90 { return ("Hoch (Stufe 1)", .orange) }
        return ("Hoch (Stufe 2)", .red)
    }

    // MARK: - Recent Values

    private var recentValuesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Letzte Werte")
                .font(.headline)

            if isBloodPressure {
                recentBPList
            } else {
                recentSingleList
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private var recentSingleList: some View {
        let items = Array(filteredItems.suffix(20).reversed())
        return ForEach(items, id: \.id) { item in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.startDate, format: .dateTime.day().month(.abbreviated))
                        .font(.subheadline)
                    Text(item.startDate, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(dataType.formattedValue(item.value))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
            .padding(.vertical, 4)

            if item.id != items.last?.id {
                Divider()
            }
        }
    }

    private var recentBPList: some View {
        let readings = recentBPReadings
        return ForEach(readings.indices, id: \.self) { index in
            let reading = readings[index]
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(reading.date, format: .dateTime.day().month(.abbreviated))
                        .font(.subheadline)
                    Text(reading.date, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(reading.systolic))/\(Int(reading.diastolic)) mmHg")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .monospacedDigit()
                    Text("PP: \(Int(reading.systolic - reading.diastolic))")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            .padding(.vertical, 4)

            if index < readings.count - 1 {
                Divider()
            }
        }
    }

    private var recentBPReadings: [(date: Date, systolic: Double, diastolic: Double)] {
        let sysItems = filteredItems.filter { $0.type == .bloodPressureSystolic }.suffix(20).reversed()
        return sysItems.compactMap { sys in
            guard let dia = filteredItems.first(where: {
                $0.type == .bloodPressureDiastolic
                && abs($0.startDate.timeIntervalSince(sys.startDate)) < 60
            }) else { return nil }
            return (date: sys.startDate, systolic: sys.value, diastolic: dia.value)
        }
    }

    // MARK: - Data Loading

    private func loadHistoricalData() async {
        isLoading = true
        let types: [HealthDataType] = isBloodPressure
            ? [.bloodPressureSystolic, .bloodPressureDiastolic]
            : [dataType]

        let items = await healthKitManager.fetchData(
            for: types,
            from: selectedRange.startDate,
            to: Date()
        )

        for item in items {
            let exists = allItems.contains { $0.id == item.id }
            if !exists {
                modelContext.insert(item)
            }
        }
        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SensorDetailView(dataType: .heartRate)
    }
    .modelContainer(for: HealthDataItem.self)
}
