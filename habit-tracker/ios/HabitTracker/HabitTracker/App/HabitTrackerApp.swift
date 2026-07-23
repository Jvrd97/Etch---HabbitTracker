// [review:need-review] PHASE-01/05-ios-today-quick-entry
// summary: app entry point — TabView with Today and Settings tabs
import SwiftUI

@main
struct HabitTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                TodayView(viewModel: .live())
                    .tabItem {
                        Label("Today", systemImage: "checkmark.circle")
                    }
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
        }
    }
}
