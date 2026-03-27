import SwiftUI

struct SettingsView: View {
    @AppStorage("syncIntervalSteps") private var syncIntervalSteps = 15 // minutes
    @AppStorage("syncIntervalHeartRate") private var syncIntervalHeartRate = 15
    @AppStorage("syncIntervalSleep") private var syncIntervalSleep = 1440 // daily
    @AppStorage("wifiOnly") private var wifiOnly = true
    @AppStorage("batteryOptimization") private var batteryOptimization = false
    
    @State private var showHealthKitInfo = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("HealthKit") {
                    NavigationLink(destination: HealthKitSettingsView()) {
                        Label("Datentypen", systemImage: "heart.text.square")
                    }
                    
                    Button(action: { showHealthKitInfo = true }) {
                        Label("Berechtigungen", systemImage: "lock.shield")
                    }
                    .foregroundStyle(.primary)
                }
                
                Section("Synchronisierung") {
                    Picker("Schritte", selection: $syncIntervalSteps) {
                        Text("15 Min").tag(15)
                        Text("30 Min").tag(30)
                        Text("1 Std").tag(60)
                        Text("2 Std").tag(120)
                    }
                    .pickerStyle(.navigationLink)
                    
                    Picker("Herzfrequenz", selection: $syncIntervalHeartRate) {
                        Text("15 Min").tag(15)
                        Text("30 Min").tag(30)
                        Text("1 Std").tag(60)
                    }
                    .pickerStyle(.navigationLink)
                    
                    Picker("Schlaf", selection: $syncIntervalSleep) {
                        Text("Täglich").tag(1440)
                        Text("Stündlich").tag(60)
                    }
                    .pickerStyle(.navigationLink)
                }
                
                Section("Netzwerk") {
                    Toggle("Nur über WLAN", isOn: $wifiOnly)
                    Toggle("Batterie-Optimierung", isOn: $batteryOptimization)
                }
                
                Section("API Verbindung") {
                    NavigationLink(destination: APISettingsView()) {
                        Label("Server konfigurieren", systemImage: "server.rack")
                    }
                }
                
                Section("Über") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://github.com/openhealth/ios")!) {
                        Label("GitHub", systemImage: "link")
                    }
                    
                    Link(destination: URL(string: "https://openhealth.svenwagener.net")!) {
                        Label("Website", systemImage: "globe")
                    }
                }
            }
            .navigationTitle("Einstellungen")
            .sheet(isPresented: $showHealthKitInfo) {
                HealthKitInfoView()
            }
        }
    }
}

// MARK: - Sub-Views

struct HealthKitSettingsView: View {
    @State private var enabledTypes: Set<HealthDataType> = [.stepCount, .heartRate, .bodyMass]
    
    var body: some View {
        List {
            ForEach(HealthDataType.allCases) { type in
                Toggle(type.displayName, isOn: Binding(
                    get: { enabledTypes.contains(type) },
                    set: { isEnabled in
                        if isEnabled {
                            enabledTypes.insert(type)
                        } else {
                            enabledTypes.remove(type)
                        }
                    }
                ))
            }
        }
        .navigationTitle("Datentypen")
    }
}

struct APISettingsView: View {
    @AppStorage("serverURL") private var serverURL = ""
    @AppStorage("apiKey") private var apiKey = ""
    @State private var showAPIKey = false
    
    var body: some View {
        Form {
            Section("Server") {
                TextField("https://api.example.com", text: $serverURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }
            
            Section("API Key") {
                HStack {
                    if showAPIKey {
                        TextField("API Key", text: $apiKey)
                    } else {
                        SecureField("API Key", text: $apiKey)
                    }
                    
                    Button(action: { showAPIKey.toggle() }) {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                    }
                }
                
                Button("In Keychain speichern") {
                    // TODO: Save to Keychain
                }
                .disabled(apiKey.isEmpty)
            }
            
            Section {
                Button("Verbindung testen") {
                    // TODO: Test API connection
                }
                .disabled(serverURL.isEmpty || apiKey.isEmpty)
            }
        }
        .navigationTitle("API")
    }
}

struct HealthKitInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("HealthKit Berechtigungen")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("OpenHealth benötigt Zugriff auf deine Gesundheitsdaten, um sie anzuzeigen und zu exportieren.")
                        .font(.body)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Deine Daten verlassen dein Gerät nur, wenn du sie exportierst", systemImage: "lock.shield")
                        Label("Du kannst den Zugriff jederzeit in den iOS-Einstellungen widerrufen", systemImage: "gear")
                        Label("Alle Daten werden lokal auf deinem Gerät gespeichert", systemImage: "iphone")
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
