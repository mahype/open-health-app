import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HealthDataItem.startDate, order: .reverse) private var healthItems: [HealthDataItem]
    
    @StateObject private var healthKitManager = HealthKitManager.shared
    @State private var selectedDate = Date()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var todaySteps: Double = 0
    @State private var todayHeartRate: Double = 0
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // HealthKit Status
                    healthKitStatusCard
                    
                    // Quick Stats
                    quickStatsGrid
                    
                    // Recent Data
                    recentDataSection
                }
                .padding()
            }
            .navigationTitle("OpenHealth")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { loadTodayData() }) {
                        Image(systemName: "arrow.clockwise")
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
    
    private var healthKitStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: healthKitManager.isAuthorized ? "checkmark.shield.fill" : "exclamationmark.shield")
                    .foregroundStyle(healthKitManager.isAuthorized ? .green : .orange)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text("HealthKit")
                        .font(.headline)
                    Text(healthKitManager.isAuthorized ? "Verbunden" : "Zugriff erforderlich")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            if !healthKitManager.isAuthorized {
                Button("Zugriff erlauben") {
                    Task {
                        do {
                            try await healthKitManager.requestAuthorization()
                            await loadTodayData()
                        } catch {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var quickStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: "Heutige Schritte",
                value: String(format: "%.0f", todaySteps),
                icon: "figure.walk",
                color: .blue
            )
            
            StatCard(
                title: "Ø Herzfrequenz",
                value: todayHeartRate > 0 ? String(format: "%.0f", todayHeartRate) : "--",
                icon: "heart.fill",
                color: .red
            )
        }
    }
    
    private var recentDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Letzte Daten")
                .font(.headline)
            
            let todayItems = healthItems.filter { item in
                Calendar.current.isDateInToday(item.startDate)
            }
            
            if todayItems.isEmpty {
                ContentUnavailableView(
                    "Keine Daten",
                    systemImage: "heart.text.square",
                    description: Text("Lade deine Gesundheitsdaten von HealthKit")
                )
            } else {
                ForEach(todayItems.prefix(5)) { item in
                    HealthDataRow(item: item)
                }
            }
        }
    }
    
    private func loadTodayData() {
        guard healthKitManager.isAuthorized else { return }
        
        isLoading = true
        
        Task {
            do {
                // Fetch all data for today
                let items = try await healthKitManager.fetchAllData(for: Date())
                
                // Save to SwiftData
                for item in items {
                    // Check if item already exists
                    let existing = healthItems.first { $0.id == item.id }
                    if existing == nil {
                        modelContext.insert(item)
                    }
                }
                
                // Fetch aggregated stats
                let steps = try await healthKitManager.fetchStepCount(for: Date())
                
                // Calculate average heart rate from fetched items
                let heartRateItems = items.filter { $0.type == .heartRate }
                let avgHeartRate = heartRateItems.isEmpty ? 0 : heartRateItems.map { $0.value }.reduce(0, +) / Double(heartRateItems.count)
                
                await MainActor.run {
                    self.todaySteps = steps
                    self.todayHeartRate = avgHeartRate
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct HealthDataRow: View {
    let item: HealthDataItem
    
    var body: some View {
        HStack {
            Image(systemName: item.type.icon)
                .foregroundStyle(.accent)
                .frame(width: 32)
            
            VStack(alignment: .leading) {
                Text(item.type.displayName)
                    .font(.subheadline)
                Text(item.startDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(String(format: "%.1f", item.value))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(item.unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: HealthDataItem.self)
}
