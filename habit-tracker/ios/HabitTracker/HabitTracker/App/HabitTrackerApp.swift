// [review:need-review] PHASE-01/06-ios-table-view
// summary: app entry point — TabView with Today, Table and Settings tabs
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
                TableView(viewModel: .live())
                    .tabItem {
                        Label("Table", systemImage: "tablecells")
                    }
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
        }
    }
}
