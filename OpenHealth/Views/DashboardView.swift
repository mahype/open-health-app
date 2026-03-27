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

// MARK: - Dashboard View

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HealthDataItem.startDate, order: .reverse) private var healthItems: [HealthDataItem]

    @StateObject private var healthKitManager = HealthKitManager.shared
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    healthKitStatusCard

                    if isLoading && healthItems.isEmpty {
                        ProgressView("Lade Daten...")
                            .padding(.top, 40)
                    } else if dashboardTiles.isEmpty {
                        ContentUnavailableView(
                            "Keine Sensoren aktiv",
                            systemImage: "heart.text.square",
                            description: Text("Aktiviere Datentypen in den Einstellungen")
                        )
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(dashboardTiles) { tile in
                                NavigationLink(destination: destinationView(for: tile)) {
                                    DashboardTileView(tile: tile, healthItems: healthItems)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("OpenHealth")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { loadTodayData() }) {
                        Image(systemName: "arrow.clockwise")
                            .rotationEffect(.degrees(isLoading ? 360 : 0))
                            .animation(isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
                    }
                    .disabled(isLoading)
                }
            }
            .alert("Fehler", isPresented: $showError, presenting: errorMessage) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
        }
        .onAppear {
            healthKitManager.checkAuthorizationStatus()
            loadTodayData()
        }
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

    // MARK: - HealthKit Status

    private var healthKitStatusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: healthKitManager.isAuthorized ? "checkmark.shield.fill" : "exclamationmark.shield")
                .foregroundStyle(healthKitManager.isAuthorized ? .green : .orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("HealthKit")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(healthKitManager.isAuthorized ? "Verbunden" : "Zugriff erforderlich")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !healthKitManager.isAuthorized {
                Button("Erlauben") {
                    Task {
                        do {
                            try await healthKitManager.requestAuthorization()
                            loadTodayData()
                        } catch {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - Data Loading

    private func loadTodayData() {
        guard healthKitManager.isAuthorized else { return }

        isLoading = true

        Task {
            let enabledTypes = EnabledTypesStore.load()
            let items = await healthKitManager.fetchAllData(for: Date(), types: enabledTypes)

            for item in items {
                let existing = healthItems.first { $0.id == item.id }
                if existing == nil {
                    modelContext.insert(item)
                }
            }

            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Dashboard Tile View

struct DashboardTileView: View {
    let tile: DashboardTileType
    let healthItems: [HealthDataItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: Icon + Name
            HStack {
                Image(systemName: tile.icon)
                    .font(.caption)
                    .foregroundStyle(tile.color)
                    .frame(width: 24, height: 24)
                    .background(tile.color.opacity(0.12))
                    .cornerRadius(6)

                Text(tile.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()
            }

            // Latest Value
            Text(latestValueText)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // Sparkline
            sparklineChart
                .frame(height: 40)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
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
            if type.usesBarChart {
                barSparkline(for: type)
            } else {
                lineSparkline(for: type)
            }
        case .bloodPressure:
            bloodPressureSparkline
        }
    }

    private func lineSparkline(for type: HealthDataType) -> some View {
        let data = recentItems(for: type, count: 15)
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
                    colors: [type.color.opacity(0.2), type.color.opacity(0.02)],
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
            .foregroundStyle(type.color.opacity(0.7))
            .cornerRadius(2)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }

    private var bloodPressureSparkline: some View {
        let sysData = recentItems(for: .bloodPressureSystolic, count: 15)
        let diaData = recentItems(for: .bloodPressureDiastolic, count: 15)

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

// MARK: - Preview

#Preview {
    DashboardView()
        .modelContainer(for: HealthDataItem.self)
}
