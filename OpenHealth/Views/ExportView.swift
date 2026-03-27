import SwiftUI
import SwiftData

struct ExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var healthItems: [HealthDataItem]
    
    @State private var selectedTimeRange: TimeRange = .today
    @State private var selectedFormat: ExportFormat = .json
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Zeitraum") {
                    Picker("Zeitraum", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Format") {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Label(format.displayName, systemImage: format.icon).tag(format)
                        }
                    }
                    .pickerStyle(.inline)
                }
                
                Section("Vorschau") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(filteredItems.count) Datensätze")
                            .font(.headline)
                        Text("Zeitraum: \(selectedTimeRange.displayName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    Button(action: { exportData() }) {
                        HStack {
                            Spacer()
                            if isExporting {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            } else {
                                Label("Exportieren", systemImage: "square.and.arrow.up")
                            }
                            Spacer()
                        }
                    }
                    .disabled(filteredItems.isEmpty || isExporting)
                }
                
                Section("API Upload") {
                    NavigationLink(destination: APISyncView()) {
                        Label("An Server senden", systemImage: "arrow.up.to.line.circle")
                    }
                    .disabled(filteredItems.isEmpty)
                }
            }
            .navigationTitle("Export")
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }
    
    private var filteredItems: [HealthDataItem] {
        let calendar = Calendar.current
        let now = Date()
        
        return healthItems.filter { item in
            switch selectedTimeRange {
            case .today:
                return calendar.isDate(item.startDate, inSameDayAs: now)
            case .week:
                return calendar.isDate(item.startDate, equalTo: now, toGranularity: .weekOfYear)
            case .month:
                return calendar.isDate(item.startDate, equalTo: now, toGranularity: .month)
            case .year:
                return calendar.isDate(item.startDate, equalTo: now, toGranularity: .year)
            case .all:
                return true
            }
        }
    }
    
    private func exportData() {
        isExporting = true
        
        Task {
            do {
                let url = try await createExportFile(items: filteredItems, format: selectedFormat)
                await MainActor.run {
                    exportURL = url
                    showShareSheet = true
                    isExporting = false
                }
            } catch {
                isExporting = false
            }
        }
    }
    
    private func createExportFile(items: [HealthDataItem], format: ExportFormat) async throws -> URL {
        let filename = "openhealth_export_\(Int(Date().timeIntervalSince1970))"
        
        switch format {
        case .json:
            return try await exportJSON(items: items, filename: filename)
        case .csv:
            return try await exportCSV(items: items, filename: filename)
        }
    }
    
    private func exportJSON(items: [HealthDataItem], filename: String) async throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        // Convert to exportable format
        let exportItems = items.map { HealthDataExportItem(from: $0) }
        let data = try encoder.encode(exportItems)
        
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(filename)
            .appendingPathExtension("json")
        
        try data.write(to: url)
        return url
    }
    
    private func exportCSV(items: [HealthDataItem], filename: String) async throws -> URL {
        var csv = "ID,Type,Value,Unit,StartDate,EndDate,Source\n"
        
        for item in items {
            csv += "\(item.id.uuidString),\(item.type.rawValue),\(item.value),\(item.unit),\(item.startDate),\(item.endDate),\(item.source)\n"
        }
        
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(filename)
            .appendingPathExtension("csv")
        
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

// MARK: - Supporting Types

enum TimeRange: String, CaseIterable, Identifiable {
    case today, week, month, year, all
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .today: return "Heute"
        case .week: return "Woche"
        case .month: return "Monat"
        case .year: return "Jahr"
        case .all: return "Alle"
        }
    }
}

enum ExportFormat: String, CaseIterable, Identifiable, Hashable {
    case json, csv
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV"
        }
    }
    
    var icon: String {
        switch self {
        case .json: return "curlybraces"
        case .csv: return "tablecells"
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - API Sync View

struct APISyncView: View {
    @State private var serverURL = ""
    @State private var apiKey = ""
    @State private var isSyncing = false
    @State private var syncResult: String?
    
    var body: some View {
        Form {
            Section("Server") {
                TextField("Server-URL", text: $serverURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }
            
            Section("API Key") {
                SecureField("API Key", text: $apiKey)
            }
            
            Section {
                Button(action: { syncToServer() }) {
                    HStack {
                        Spacer()
                        if isSyncing {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Label("Synchronisieren", systemImage: "arrow.up.arrow.down")
                        }
                        Spacer()
                    }
                }
                .disabled(serverURL.isEmpty || apiKey.isEmpty || isSyncing)
                
                if let result = syncResult {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("API Sync")
    }
    
    private func syncToServer() {
        isSyncing = true
        // TODO: Implement actual API sync
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isSyncing = false
            syncResult = "Sync erfolgreich (Demo)"
        }
    }
}

#Preview {
    ExportView()
        .modelContainer(for: HealthDataItem.self)
}
