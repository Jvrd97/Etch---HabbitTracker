// [review:need-review] PHASE-01/03-ios-scaffold-settings
// summary: app entry point, shows the Settings screen
import SwiftUI

@main
struct HabitTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            SettingsView()
        }
    }
}
