// [review:need-review] PHASE-01/09-ios-journal
// summary: app entry point — TabView with Today, Table, History, Journal, Categories and Settings tabs
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
                EntriesView(viewModel: .live())
                    .tabItem {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }
                JournalView(viewModel: .live())
                    .tabItem {
                        Label("Journal", systemImage: "book")
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
