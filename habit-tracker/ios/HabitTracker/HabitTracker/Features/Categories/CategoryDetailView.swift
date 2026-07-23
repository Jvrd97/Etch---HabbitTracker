// [review:need-review] PHASE-01/36-ios-category-charts
// summary: Category detail screen — header, quick-add, Swift Charts section (CategoryChartView), date-sectioned history; edit form reuses the shared generic EntryEditView
import SwiftUI

struct CategoryDetailView: View {
    @StateObject private var viewModel: CategoryDetailViewModel
    @State private var pendingDeletion: EntryDTO?

    init(viewModel: CategoryDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle(viewModel.category.name)
            .navigationBarTitleDisplayMode(.inline)
            .dsScreenBackground()
            .task { await viewModel.load() }
            .sheet(item: editingBinding) { _ in
                EntryEditView(viewModel: viewModel, fields: viewModel.category.fields)
            }
            .confirmationDialog(
                "Delete this entry?",
                isPresented: deletionBinding,
                titleVisibility: .visible,
                presenting: pendingDeletion
            ) { entry in
                Button("Delete", role: .destructive) {
                    Task { await viewModel.deleteEditEntry(id: entry.id) }
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("This permanently removes the entry and its values.")
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            NeonLoader(label: "Loading")
        case .failure(let message):
            DSErrorState(message: message) {
                Task { await viewModel.load() }
            }
        case .loaded:
            loadedBody
        }
    }

    private var loadedBody: some View {
        List {
            Section {
                header
                quickAddRow
            }
            .listRowBackground(DS.Palette.card)

            Section("Chart") {
                CategoryChartView(viewModel: viewModel)
            }
            .listRowBackground(DS.Palette.card)

            ForEach(viewModel.groupedByDate, id: \.date) { group in
                Section(group.date) {
                    ForEach(group.entries) { entry in
                        entryRow(entry)
                    }
                    .listRowBackground(DS.Palette.card)
                }
            }

            if viewModel.groupedByDate.isEmpty {
                Section {
                    Text("No entries yet. Add the first value above.")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Palette.textSecondary)
                }
                .listRowBackground(DS.Palette.card)
            }
        }
        .refreshable { await viewModel.load() }
    }

    private var header: some View {
        HStack(spacing: DS.Spacing.md) {
            ColorSwatch(hex: viewModel.category.color)
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(viewModel.category.name)
                    .font(DS.Typography.section)
                    .foregroundStyle(DS.Palette.textPrimary)
                Text("\(viewModel.category.fields.count) fields")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Palette.textSecondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var quickAddRow: some View {
        if let field = viewModel.quickAddField {
            HStack(spacing: DS.Spacing.md) {
                TextField(field.name, text: $viewModel.quickAddValue)
                    .keyboardType(field.fieldType == .number ? .decimalPad : .default)
                    .foregroundStyle(DS.Palette.textPrimary)
                Button {
                    Task { await viewModel.quickAdd() }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(DS.Palette.lime)
                }
                .accessibilityLabel("Add \(field.name)")
                .disabled(
                    viewModel.quickAddValue
                        .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
            if let message = viewModel.saveErrorMessage {
                Text(message)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Palette.danger)
            }
        }
    }

    private func entryRow(_ entry: EntryDTO) -> some View {
        Button {
            viewModel.beginEditing(entry)
        } label: {
            Text(EntrySummary.line(for: entry, category: viewModel.category))
                .font(DS.Typography.card)
                .foregroundStyle(DS.Palette.textPrimary)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                pendingDeletion = entry
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var editingBinding: Binding<EntryEditDraft?> {
        Binding(
            get: { viewModel.editDraft },
            set: { if $0 == nil { viewModel.cancelEditing() } }
        )
    }

    private var deletionBinding: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )
    }
}
