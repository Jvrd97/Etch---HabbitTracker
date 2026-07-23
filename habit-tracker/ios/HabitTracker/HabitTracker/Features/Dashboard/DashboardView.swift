// [review:need-review] PHASE-01/10-ios-dashboard
// summary: Dashboard screen — counter cards + recent-activity feed + quick jumps to Today/Journal
import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel

    /// Switches the hosting `TabView` to another tab (quick jumps to Today/Journal).
    private let onNavigate: (AppTab) -> Void

    init(viewModel: DashboardViewModel, onNavigate: @escaping (AppTab) -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onNavigate = onNavigate
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Dashboard")
        }
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("Loading…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failure(let message):
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(message)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    Task { await viewModel.load() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded:
            dashboard
        }
    }

    private var dashboard: some View {
        List {
            Section("Overview") {
                counterRow(
                    label: "Categories",
                    value: viewModel.stats.categoriesCount,
                    systemImage: "folder"
                )
                counterRow(
                    label: "Entries",
                    value: viewModel.stats.entriesCount,
                    systemImage: "calendar"
                )
                counterRow(
                    label: "Journal",
                    value: viewModel.stats.journalCount,
                    systemImage: "book"
                )
            }

            Section("Recent activity") {
                if viewModel.stats.recentEntries.isEmpty {
                    Text("Nothing here yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.stats.recentEntries) { entry in
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Entry #\(entry.id)")
                                Text(entry.entryDate)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(entry.values.count) values")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Quick actions") {
                Button {
                    onNavigate(.today)
                } label: {
                    Label("Open Today", systemImage: "checkmark.circle")
                }
                Button {
                    onNavigate(.journal)
                } label: {
                    Label("Open Journal", systemImage: "book")
                }
            }
        }
        .refreshable {
            await viewModel.load()
        }
    }

    private func counterRow(label: String, value: Int, systemImage: String) -> some View {
        HStack {
            Label(label, systemImage: systemImage)
            Spacer()
            Text("\(value)")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
    }
}
