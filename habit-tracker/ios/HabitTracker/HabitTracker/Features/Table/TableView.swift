// [review:need-review] PHASE-01/06-ios-table-view
// summary: Table screen — days×habits grid with horizontal column scroll; tap cell opens source-entries sheet
import SwiftUI

struct TableView: View {
    @StateObject private var viewModel: TableViewModel
    @State private var selectedCell: TableCellSelection?

    init(viewModel: TableViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private enum Metrics {
        static let dateColumnWidth: CGFloat = 96
        static let valueColumnWidth: CGFloat = 88
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Table")
        }
        .task {
            if case .idle = viewModel.state {
                await viewModel.load()
            }
        }
        .sheet(item: $selectedCell) { selection in
            TableCellDetailSheet(selection: selection, viewModel: viewModel)
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
            grid
        }
    }

    private var grid: some View {
        ScrollView(.vertical) {
            ScrollView(.horizontal, showsIndicators: true) {
                Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                    headerRow
                    Divider()
                    ForEach(viewModel.grid.rows) { row in
                        dataRow(row)
                        Divider()
                    }
                }
                .padding(.horizontal)
            }
            loadOlderFooter
        }
        .refreshable {
            await viewModel.load()
        }
    }

    private var headerRow: some View {
        GridRow {
            Text("Day")
                .font(.caption.bold())
                .frame(width: Metrics.dateColumnWidth, alignment: .leading)
            ForEach(viewModel.grid.columns) { column in
                Text(column.title)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .frame(width: Metrics.valueColumnWidth, alignment: .center)
            }
        }
        .padding(.vertical, 6)
    }

    private func dataRow(_ row: TableGridRow) -> some View {
        GridRow {
            Text(row.date)
                .font(.caption.monospaced())
                .frame(width: Metrics.dateColumnWidth, alignment: .leading)
            ForEach(Array(viewModel.grid.columns.enumerated()), id: \.element.id) { index, column in
                cellButton(row: row, column: column, cell: row.cells[index])
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func cellButton(
        row: TableGridRow, column: TableGridColumn, cell: TableGridCell
    ) -> some View {
        if cell.isEmpty {
            Text("—")
                .foregroundStyle(.tertiary)
                .frame(width: Metrics.valueColumnWidth, alignment: .center)
        } else {
            Button {
                selectedCell = TableCellSelection(
                    date: row.date,
                    categoryId: column.categoryId,
                    fieldId: column.fieldId,
                    title: column.title
                )
            } label: {
                Text(cell.value ?? "—")
                    .lineLimit(1)
                    .frame(width: Metrics.valueColumnWidth, alignment: .center)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var loadOlderFooter: some View {
        if viewModel.isLoadingOlder {
            ProgressView()
                .padding()
        } else {
            VStack(spacing: 8) {
                if let message = viewModel.loadOlderErrorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Button("Load older days") {
                    Task { await viewModel.loadOlder() }
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }
}

/// Identifies the tapped cell so the sheet can fetch the day's source entries.
struct TableCellSelection: Identifiable, Equatable {
    let date: String
    let categoryId: Int
    let fieldId: Int
    let title: String

    var id: String { "\(categoryId)-\(date)" }
}

/// Sheet listing the raw entries a cell's aggregated value was composed from.
struct TableCellDetailSheet: View {
    let selection: TableCellSelection
    let viewModel: TableViewModel

    @Environment(\.dismiss) private var dismiss

    private enum LoadState: Equatable {
        case loading
        case loaded([EntryDTO])
        case failure(String)
    }

    @State private var state: LoadState = .loading

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(selection.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView("Loading…")
        case .failure(let message):
            Text(message)
                .foregroundStyle(.red)
                .padding()
        case .loaded(let entries) where entries.isEmpty:
            Text("No records for \(selection.date)")
                .foregroundStyle(.secondary)
                .padding()
        case .loaded(let entries):
            List {
                Section(selection.date) {
                    ForEach(entries) { entry in
                        entryRow(entry)
                    }
                }
            }
        }
    }

    private func entryRow(_ entry: EntryDTO) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(entry.values, id: \.fieldId) { value in
                HStack {
                    Text("Field \(value.fieldId)")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(value.value ?? "—")
                }
                .font(.callout)
            }
        }
        .padding(.vertical, 2)
    }

    private func load() async {
        state = .loading
        do {
            let entries = try await viewModel.fetchCellEntries(
                categoryId: selection.categoryId, date: selection.date
            )
            state = .loaded(entries)
        } catch let error as APIClientError {
            state = .failure(error.userMessage)
        } catch {
            state = .failure("Unexpected error")
        }
    }
}
