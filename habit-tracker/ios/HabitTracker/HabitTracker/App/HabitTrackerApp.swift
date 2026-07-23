// [review:need-review] PHASE-01/10-ios-dashboard
// summary: app entry point — TabView (Dashboard start tab) with programmatic tab switching for quick jumps
import SwiftUI

/// Tabs of the root `TabView`. Tags let the Dashboard jump to another tab programmatically.
enum AppTab: Hashable {
    case dashboard
    case today
    case table
    case history
    case journal
    case categories
    case settings
}

@main
struct HabitTrackerApp: App {
    @State private var selectedTab: AppTab = .dashboard

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                DashboardView(viewModel: .live()) { selectedTab = $0 }
                    .tabItem {
                        Label("Dashboard", systemImage: "square.grid.2x2")
                    }
                    .tag(AppTab.dashboard)
                TodayView(viewModel: .live())
                    .tabItem {
                        Label("Today", systemImage: "checkmark.circle")
                    }
                    .tag(AppTab.today)
                TableView(viewModel: .live())
                    .tabItem {
                        Label("Table", systemImage: "tablecells")
                    }
                    .tag(AppTab.table)
                EntriesView(viewModel: .live())
                    .tabItem {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }
                    .tag(AppTab.history)
                JournalView(viewModel: .live())
                    .tabItem {
                        Label("Journal", systemImage: "book")
                    }
                    .tag(AppTab.journal)
                CategoriesView(viewModel: .live())
                    .tabItem {
                        Label("Categories", systemImage: "folder")
                    }
                    .tag(AppTab.categories)
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(AppTab.settings)
            }
        }
    }
}
