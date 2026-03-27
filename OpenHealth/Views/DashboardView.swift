import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var healthItems: [HealthDataItem]
    
    @StateObject private var healthKitManager = HealthKitManager.shared
    @State private var selectedDate = Date()
    @State private var isLoading = false
    @State private var errorMessage: String?
    
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
                    Button(action: { loadData() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
        }
        .onAppear {
            healthKitManager.checkAuthorizationStatus()
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
                        } catch {
                            errorMessage = error.localizedDescription
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
                value: "0",
                icon: "figure.walk",
                color: .blue
            )
            
            StatCard(
                title: "Herzfrequenz",
                value: "--",
                icon: "heart.fill",
                color: .red
            )
        }
    }
    
    private var recentDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Letzte Daten")
                .font(.headline)
            
            if healthItems.isEmpty {
                ContentUnavailableView(
                    "Keine Daten",
                    systemImage: "heart.text.square",
                    description: Text("Lade deine Gesundheitsdaten von HealthKit")
                )
            } else {
                ForEach(healthItems.prefix(5)) { item in
                    HealthDataRow(item: item)
                }
            }
        }
    }
    
    private func loadData() {
        guard healthKitManager.isAuthorized else { return }
        
        isLoading = true
        Task {
            do {
                let steps = try await healthKitManager.fetchSteps(for: selectedDate)
                for item in steps {
                    modelContext.insert(item)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
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
