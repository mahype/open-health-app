import SwiftUI
import SwiftData

@main
struct OpenHealthApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: HealthDataItem.self)
    }
}
