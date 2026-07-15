import SwiftUI
import SwiftData

// MARK: - Time Range

enum ChartTimeRange: String, CaseIterable, Identifiable {
    case sevenDays = "7d"
    case thirtyDays = "30d"
    case ninetyDays = "90d"
    case sixMonths = "6m"
    case oneYear = "1y"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sevenDays: return "7 Tage"
        case .thirtyDays: return "30 Tage"
        case .ninetyDays: return "90 Tage"
        case .sixMonths: return "6 Monate"
        case .oneYear: return "1 Jahr"
        case .custom: return "Zeitraum"
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
        case .custom: return Date()  // Placeholder — view uses effectiveStartDate
        }
    }
}

// MARK: - Sensor Detail View (thin wrapper)

struct SensorDetailView: View {
    let dataType: HealthDataType
    var isBloodPressure: Bool = false

    @Environment(\.modelContext) private var modelContext
    @StateObject private var healthKitManager = HealthKitManager.shared

    @State private var selectedRange: ChartTimeRange = .thirtyDays
    @State private var isRefreshing = false
    @State private var lastRefreshedDate: Date?
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var previousRange: ChartTimeRange = .thirtyDays
    @State private var showMonthYearPicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Time Range Picker
                VStack(spacing: 8) {
                    Picker("Zeitraum", selection: $selectedRange) {
                        ForEach(ChartTimeRange.allCases) { range in
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
                .padding(.horizontal)

                // Progress bar — shown while HealthKit is being queried
                if isRefreshing, let progress = healthKitManager.fetchProgress {
                    FetchProgressBar(progress: progress)
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: progress.completed)
                } else if isRefreshing {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Lade Daten...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // Inner content view — re-created when range key changes so
                // @Query rebuilds its predicate against the new window.
                SensorDetailContent(
                    dataType: dataType,
                    isBloodPressure: isBloodPressure,
                    startDate: effectiveStartDate,
                    endDate: effectiveEndDate,
                    selectedRange: selectedRange
                )
                .id(effectiveRangeKey)
            }
            .padding(.vertical)
        }
        .refreshBanner(isRefreshing: isRefreshing, lastRefreshed: lastRefreshedDate)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(isBloodPressure ? "Blutdruck" : dataType.displayName)
        .navigationBarTitleDisplayMode(.large)
        .task(id: selectedRange) {
            await loadHistoricalData()
        }
        .onChange(of: selectedRange) { old, new in
            if new == .custom {
                previousRange = old
                showMonthYearPicker = true
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
                    Task { await loadHistoricalData(force: true) }
                }
            }
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
            Task { await loadHistoricalData(force: true) }
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

    // MARK: - Data Loading

    private func loadHistoricalData(force: Bool = false) async {
        let rangeKey = effectiveRangeKey
        let cacheType = isBloodPressure ? HealthDataType.bloodPressureSystolic : dataType
        guard force || CacheMetadataStore.isStale(
            CacheMetadataStore.lastRefreshDate(for: cacheType, range: rangeKey)
        ) else { return }

        isRefreshing = true

        let types: [HealthDataType] = isBloodPressure
            ? [.bloodPressureSystolic, .bloodPressureDiastolic]
            : [dataType]

        let items = await healthKitManager.fetchData(
            for: types,
            from: effectiveStartDate,
            to: effectiveEndDate
        )

        // O(n) duplicate detection — scoped to this date window only
        let start = effectiveStartDate
        let end = effectiveEndDate
        let rangeDescriptor = FetchDescriptor<HealthDataItem>(
            predicate: #Predicate<HealthDataItem> { $0.startDate >= start && $0.startDate < end }
        )
        let existingIDs = Set((try? modelContext.fetch(rangeDescriptor))?.map(\.id) ?? [])
        for item in items where !existingIDs.contains(item.id) {
            modelContext.insert(item)
        }

        // Persist aggregates for chart performance
        let aggService = AggregationService(modelContext: modelContext)
        for type in types {
            let typeItems = items.filter { $0.type == type }
            aggService.persistAggregates(for: typeItems, dataType: type)
        }

        // Prefetch neighbors in background
        if !isBloodPressure && selectedRange != .custom {
            aggService.prefetchNeighbors(
                currentRange: selectedRange,
                dataType: dataType,
                healthKitManager: healthKitManager
            )
        }

        CacheMetadataStore.markRefreshed(for: cacheType, range: rangeKey)
        lastRefreshedDate = Date()
        isRefreshing = false
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

// MARK: - Preview

#Preview {
    NavigationStack {
        SensorDetailView(dataType: .heartRate)
    }
    .modelContainer(for: [HealthDataItem.self, AggregatedDataPoint.self])
}
