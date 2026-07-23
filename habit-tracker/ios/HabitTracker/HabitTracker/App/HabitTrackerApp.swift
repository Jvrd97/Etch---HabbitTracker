// [review:need-review] PHASE-01/07-ios-categories-crud
// summary: app entry point — TabView with Today, Table, Categories and Settings tabs
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
                CategoriesView(viewModel: .live())
                    .tabItem {
                        Label("Categories", systemImage: "folder")
                    }
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
        }
    }
}
