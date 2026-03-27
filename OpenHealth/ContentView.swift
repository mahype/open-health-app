import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar")
                }
                .tag(0)
            
            ExportView()
                .tabItem {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Label("Einstellungen", systemImage: "gear")
                }
                .tag(2)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: HealthDataItem.self)
}
