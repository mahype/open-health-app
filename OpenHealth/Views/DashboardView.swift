import SwiftUI
import SwiftData
import Charts

// MARK: - Dashboard Tile Type

enum DashboardTileType: Identifiable {
    case single(HealthDataType)
    case bloodPressure

    var id: String {
        switch self {
        case .single(let type): return type.rawValue
        case .bloodPressure: return "bloodPressure"
        }
    }

    var displayName: String {
        switch self {
        case .single(let type): return type.displayName
        case .bloodPressure: return "Blutdruck"
        }
    }

    var icon: String {
        switch self {
        case .single(let type): return type.icon
        case .bloodPressure: return "waveform.path.ecg"
        }
    }

    var color: Color {
        switch self {
        case .single(let type): return type.color
        case .bloodPressure: return .red
        }
    }
}

// MARK: - Dashboard Time Range

enum DashboardTimeRange: String, CaseIterable, Identifiable {
    case today = "today"
    case sevenDays = "7d"
    case thirtyDays = "30d"
    case ninetyDays = "90d"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .today: return "Heute"
        case .sevenDays: return "7 Tage"
        case .thirtyDays: return "30 Tage"
        case .ninetyDays: return "90 Tage"
        case .custom: return "Zeitraum"
        }
    }

    var startDate: Date {
        let calendar = Calendar.current
        switch self {
        case .today: return calendar.startOfDay(for: Date())
        case .sevenDays: return calendar.date(byAdding: .day, value: -7, to: Date())!
        case .thirtyDays: return calendar.date(byAdding: .day, value: -30, to: Date())!
        case .ninetyDays: return calendar.date(byAdding: .day, value: -90, to: Date())!
        case .custom: return Date()  // Placeholder — view uses effectiveStartDate
        }
    }
}

// MARK: - Dashboard View

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HealthDataItem.startDate, order: .reverse) private var healthItems: [HealthDataItem]

    @StateObject private var healthKitManager = HealthKitManager.shared
    @State private var isRefreshing = false
    @State private var lastRefreshedDate: Date?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var selectedRange: DashboardTimeRange = .today
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var previousRange: DashboardTimeRange = .sevenDays
    @State private var showMonthYearPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // HealthKit Status - only when not authorized
                    if !healthKitManager.isAuthorized {
                        healthKitSetupCard
                    }

                    // Time Range Picker
                    if healthKitManager.isAuthorized {
                        timeRangePicker
                    }

                    // Inline fetch progress bar
                    if isRefreshing, let progress = healthKitManager.fetchProgress {
                        FetchProgressBar(progress: progress)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .animation(.easeInOut(duration: 0.3), value: progress.completed)
                    }

                    // Tiles
                    if filteredItems.isEmpty && isRefreshing {
                        ProgressView("Hole Daten von HealthKit...")
                            .padding(.top, 40)
                    } else if dashboardTiles.isEmpty && healthKitManager.isAuthorized {
                        ContentUnavailableView(
                            "Keine Sensoren aktiv",
                            systemImage: "heart.text.square",
                            description: Text("Aktiviere Datentypen in den Einstellungen")
                        )
                    } else if healthKitManager.isAuthorized {
                        tileGrid
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .refreshBanner(isRefreshing: isRefreshing, lastRefreshed: lastRefreshedDate)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("OpenHealth")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if healthKitManager.isAuthorized {
                        Button(action: { loadData(force: true) }) {
                            Image(systemName: "arrow.clockwise")
                                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                                .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                        }
                        .disabled(isRefreshing)
                    }
                }
            }
            .alert("Fehler", isPresented: $showError, presenting: errorMessage) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
        }
        .task {
            await healthKitManager.ensureAuthorization()
            loadData()
        }
        .onChange(of: selectedRange) { old, new in
            if new == .custom {
                previousRange = old
                showMonthYearPicker = true
            } else {
                loadData()
            }
        }
        .sheet(isPresented: $showMonthYearPicker) {
            MonthYearPickerSheet(
                selectedMonth: $selectedMonth,
                selectedYear: $selectedYear,
                onCancel: { selectedRange = previousRange }
            )
            .onDisappear {
                if selectedRange == .custom {
                    loadData()
                }
            }
        }
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        VStack(spacing: 8) {
            Picker("Zeitraum", selection: $selectedRange) {
                ForEach(DashboardTimeRange.allCases) { range in
                    if range == .custom {
                        Image(systemName: "calendar").tag(range)
                    } else {
                        Text(range.displayName).tag(range)
                    }
                }
            }
            .pickerStyle(.segmented)

            if selectedRange == .custom {
                monthNavigationRow
            }
        }
    }

    // MARK: - Month Navigation

    private var monthNavigationRow: some View {
        HStack {
            Button {
                navigateMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 36, height: 36)
            }

            Spacer()

            Button {
                showMonthYearPicker = true
            } label: {
                Text(currentMonthLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }

            Spacer()

            Button {
                navigateMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .foregroundStyle(isCurrentMonth ? Color(.tertiaryLabel) : .primary)
            }
            .disabled(isCurrentMonth)
        }
    }

    private func navigateMonth(by offset: Int) {
        let currentDate = Calendar.current.date(
            from: DateComponents(year: selectedYear, month: selectedMonth)
        )!
        if let newDate = Calendar.current.date(byAdding: .month, value: offset, to: currentDate) {
            selectedMonth = Calendar.current.component(.month, from: newDate)
            selectedYear = Calendar.current.component(.year, from: newDate)
            loadData(force: true)
        }
    }

    private var currentMonthDate: Date {
        Calendar.current.date(from: DateComponents(year: selectedYear, month: selectedMonth))!
    }

    private var currentMonthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: currentMonthDate)
    }

    private var isCurrentMonth: Bool {
        let now = Date()
        return selectedYear == Calendar.current.component(.year, from: now)
            && selectedMonth == Calendar.current.component(.month, from: now)
    }

    // MARK: - Tile Grid

    private var tileGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(dashboardTiles) { tile in
                NavigationLink(destination: destinationView(for: tile)) {
                    DashboardTileView(tile: tile, healthItems: filteredItems)
                }
                .buttonStyle(TilePressButtonStyle())
            }
        }
    }

    // MARK: - Filtered Data

    private var filteredItems: [HealthDataItem] {
        let start = effectiveStartDate
        let end = effectiveEndDate
        return healthItems.filter { $0.startDate >= start && $0.startDate < end }
    }

    // MARK: - Tile Generation

    private var dashboardTiles: [DashboardTileType] {
        let enabled = EnabledTypesStore.load()
        var tiles: [DashboardTileType] = []
        var addedBP = false

        for type in HealthDataType.allCases {
            guard enabled.contains(type) else { continue }

            if type == .bloodPressureSystolic || type == .bloodPressureDiastolic {
                if !addedBP {
                    tiles.append(.bloodPressure)
                    addedBP = true
                }
                continue
            }

            tiles.append(.single(type))
        }
        return tiles
    }

    // MARK: - Navigation

    @ViewBuilder
    private func destinationView(for tile: DashboardTileType) -> some View {
        switch tile {
        case .single(let type):
            SensorDetailView(dataType: type)
        case .bloodPressure:
            SensorDetailView(dataType: .bloodPressureSystolic, isBloodPressure: true)
        }
    }

    // MARK: - HealthKit Setup Card

    private var healthKitSetupCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 40))
                .foregroundStyle(.red)

            Text("Gesundheitsdaten freigeben")
                .font(.headline)

            Text("OpenHealth benoetigt einmalig Zugriff auf deine Gesundheitsdaten, um sie anzuzeigen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    do {
                        try await healthKitManager.requestAuthorization()
                        loadData()
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            } label: {
                Text("Zugriff erlauben")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Data Loading

    private func loadData(force: Bool = false) {
        guard healthKitManager.isAuthorized else { return }

        let rangeKey = effectiveRangeKey
        guard force || CacheMetadataStore.isStale(
            CacheMetadataStore.lastRefreshDate(forDashboardRange: rangeKey)
        ) else { return }

        isRefreshing = true

        Task {
            let enabledTypes = EnabledTypesStore.load()
            let items = await healthKitManager.fetchData(
                for: Array(enabledTypes),
                from: effectiveStartDate,
                to: effectiveEndDate
            )

            let existingIDs = Set(healthItems.map(\.id))
            for item in items where !existingIDs.contains(item.id) {
                modelContext.insert(item)
            }

            CacheMetadataStore.markDashboardRefreshed(range: rangeKey)
            lastRefreshedDate = Date()
            isRefreshing = false
            // Mark that we have loaded data at least once (dismisses splash screen)
            UserDefaults.standard.set(true, forKey: "hasSeenData")
        }
    }

    // MARK: - Effective Date Range

    private var effectiveStartDate: Date {
        guard selectedRange == .custom else { return selectedRange.startDate }
        return Calendar.current.date(
            from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)
        ) ?? selectedRange.startDate
    }

    private var effectiveEndDate: Date {
        guard selectedRange == .custom else { return Date() }
        return Calendar.current.date(byAdding: .month, value: 1, to: effectiveStartDate) ?? Date()
    }

    private var effectiveRangeKey: String {
        selectedRange == .custom ? "custom_\(selectedYear)_\(selectedMonth)" : selectedRange.rawValue
    }
}

// MARK: - Month Year Picker Sheet

private struct MonthYearPickerSheet: View {
    @Binding var selectedMonth: Int
    @Binding var selectedYear: Int
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss

    private let years = Array((2015...Calendar.current.component(.year, from: Date())).reversed())

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("Monat", selection: $selectedMonth) {
                    ForEach(1...12, id: \.self) { m in
                        Text(DateFormatter().monthSymbols[m - 1]).tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                Picker("Jahr", selection: $selectedYear) {
                    ForEach(years, id: \.self) { y in
                        Text(String(y)).tag(y)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Zeitraum wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { onCancel(); dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(280)])
    }
}

// MARK: - Dashboard Tile View

struct DashboardTileView: View {
    let tile: DashboardTileType
    let healthItems: [HealthDataItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: tile.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tile.color)
                    .frame(width: 28, height: 28)
                    .background(tile.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                Text(tile.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }

            // Value
            Text(latestValueText)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            // Unit subtitle for blood pressure
            if case .bloodPressure = tile {
                Text("mmHg")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, -8)
            }

            // Sparkline
            sparklineChart
                .frame(height: 44)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Latest Value

    private var latestValueText: String {
        switch tile {
        case .single(let type):
            if type == .stepCount {
                let todayItems = healthItems.filter {
                    $0.type == .stepCount && Calendar.current.isDateInToday($0.startDate)
                }
                let total = todayItems.map(\.value).reduce(0, +)
                return total > 0 ? type.formattedValue(total) : "--"
            }
            if type == .sleepAnalysis {
                let calendar = Calendar.current
                let sleepItems = healthItems.filter { $0.type == .sleepAnalysis }
                guard !sleepItems.isEmpty else { return "--" }
                // Group by wake-up day (endDate) and find the most recent day
                let grouped = Dictionary(grouping: sleepItems) { calendar.startOfDay(for: $0.endDate) }
                guard let latestDay = grouped.keys.max(),
                      let items = grouped[latestDay] else { return "--" }
                let total = items.map(\.value).reduce(0, +)
                return type.formattedValue(total)
            }
            guard let latest = healthItems.first(where: { $0.type == type }) else {
                return "--"
            }
            return type.formattedValue(latest.value)

        case .bloodPressure:
            let sys = healthItems.first(where: { $0.type == .bloodPressureSystolic })
            let dia = healthItems.first(where: { $0.type == .bloodPressureDiastolic })
            if let s = sys, let d = dia {
                return "\(Int(s.value))/\(Int(d.value))"
            }
            return "--/--"
        }
    }

    // MARK: - Sparkline

    @ViewBuilder
    private var sparklineChart: some View {
        switch tile {
        case .single(let type):
            if type == .sleepAnalysis {
                sleepBarSparkline
            } else if type.usesBarChart {
                barSparkline(for: type)
            } else {
                lineSparkline(for: type)
            }
        case .bloodPressure:
            bloodPressureSparkline
        }
    }

    private func lineSparkline(for type: HealthDataType) -> some View {
        let data = recentItems(for: type, count: 20)
        return Chart(data, id: \.startDate) { item in
            LineMark(
                x: .value("D", item.startDate),
                y: .value("V", item.value)
            )
            .foregroundStyle(type.color.opacity(0.8))
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("D", item.startDate),
                y: .value("V", item.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [type.color.opacity(0.2), type.color.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }

    private func barSparkline(for type: HealthDataType) -> some View {
        let aggregates = dailyAggregates(for: type, days: 7)
        return Chart(aggregates, id: \.date) { agg in
            BarMark(
                x: .value("D", agg.date, unit: .day),
                y: .value("V", agg.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [type.color.opacity(0.8), type.color.opacity(0.4)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }

    private var sleepBarSparkline: some View {
        let aggregates = dailySleepStageAggregates(days: 7)
        return Chart(aggregates, id: \.id) { agg in
            BarMark(
                x: .value("D", agg.date, unit: .day),
                y: .value("V", agg.value)
            )
            .foregroundStyle(by: .value("Phase", agg.stage.displayName))
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        }
        .chartForegroundStyleScale([
            SleepStage.deep.displayName: SleepStage.deep.color,
            SleepStage.core.displayName: SleepStage.core.color,
            SleepStage.rem.displayName: SleepStage.rem.color,
            SleepStage.awake.displayName: SleepStage.awake.color,
        ])
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }

    private func dailySleepStageAggregates(days: Int) -> [(id: String, date: Date, stage: SleepStage, value: Double)] {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let items = healthItems.filter { $0.type == .sleepAnalysis && $0.endDate >= startDate }

        var result: [(id: String, date: Date, stage: SleepStage, value: Double)] = []
        let grouped = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.endDate)
        }
        for (date, dayItems) in grouped {
            let byStage = Dictionary(grouping: dayItems) { $0.sleepStageEnum ?? .core }
            for (stage, stageItems) in byStage {
                let total = stageItems.map(\.value).reduce(0, +)
                let id = "\(date.timeIntervalSince1970)-\(stage.rawValue)"
                result.append((id: id, date: date, stage: stage, value: total))
            }
        }
        return result.sorted { a, b in
            if a.date != b.date { return a.date < b.date }
            return a.stage.sortOrder < b.stage.sortOrder
        }
    }

    private var bloodPressureSparkline: some View {
        let sysData = recentItems(for: .bloodPressureSystolic, count: 20)
        let diaData = recentItems(for: .bloodPressureDiastolic, count: 20)

        return Chart {
            ForEach(sysData, id: \.startDate) { item in
                LineMark(
                    x: .value("D", item.startDate),
                    y: .value("V", item.value)
                )
                .foregroundStyle(Color.red.opacity(0.8))
                .interpolationMethod(.catmullRom)
            }

            ForEach(diaData, id: \.startDate) { item in
                LineMark(
                    x: .value("D", item.startDate),
                    y: .value("V", item.value)
                )
                .foregroundStyle(Color.blue.opacity(0.8))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }

    // MARK: - Data Helpers

    private func recentItems(for type: HealthDataType, count: Int) -> [HealthDataItem] {
        let items = healthItems.filter { $0.type == type }
        return Array(items.prefix(count).reversed())
    }

    private func dailyAggregates(for type: HealthDataType, days: Int) -> [(date: Date, value: Double)] {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let items = healthItems.filter { $0.type == type && $0.startDate >= startDate }
        let grouped = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.startDate)
        }
        return grouped.map { (date: $0.key, value: $0.value.map(\.value).reduce(0, +)) }
            .sorted { $0.date < $1.date }
    }
}

// MARK: - Fetch Progress Bar

struct FetchProgressBar: View {
    let progress: FetchProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text(progress.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(progress.fraction * 100)) %")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress.fraction)
                .tint(.blue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Tile Press Button Style

struct TilePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.82 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .modelContainer(for: HealthDataItem.self)
}
