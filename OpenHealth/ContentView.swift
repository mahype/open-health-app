import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    // True once DashboardView has completed its first successful data load.
    @AppStorage("hasSeenData") private var hasSeenData = false

    var body: some View {
        ZStack {
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

            // Cold-start splash: shown until the first HealthKit data load completes.
            if !hasSeenData {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeOut(duration: 0.5), value: hasSeenData)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [HealthDataItem.self, AggregatedDataPoint.self])
}
