// [review:need-review] PHASE-01/08-ios-entries-crud
// summary: Entries history screen — date-sectioned list, category filter menu, swipe-delete with confirmation, edit form (values + notes)
import SwiftUI

struct EntriesView: View {
    @StateObject private var viewModel: EntriesViewModel
    @State private var pendingDeletion: EntryDTO?

    init(viewModel: EntriesViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("History")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        filterMenu
                    }
                }
        }
        .task { await viewModel.load() }
        .sheet(item: editingBinding) { draft in
            EntryEditView(viewModel: viewModel, initialDraft: draft)
        }
        .confirmationDialog(
            "Delete this entry?",
            isPresented: deletionBinding,
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { entry in
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteEntry(id: entry.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This permanently removes the entry and its values.")
        }
    }

    private var filterMenu: some View {
        Menu {
            Button {
                viewModel.selectedCategoryId = nil
            } label: {
                Label("All categories", systemImage: viewModel.selectedCategoryId == nil ? "checkmark" : "")
            }
            ForEach(viewModel.categories) { category in
                Button {
                    viewModel.selectedCategoryId = category.id
                } label: {
                    Label(
                        category.name,
                        systemImage: viewModel.selectedCategoryId == category.id ? "checkmark" : ""
                    )
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .accessibilityLabel("Filter by category")
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
                Text(message).multilineTextAlignment(.center)
                Button("Retry") { Task { await viewModel.load() } }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded:
            entryList
        }
    }

    @ViewBuilder
    private var entryList: some View {
        if viewModel.groupedByDate.isEmpty {
            ContentUnavailableView(
                "No entries",
                systemImage: "tray",
                description: Text("Logged entries will appear here.")
            )
        } else {
            List {
                ForEach(viewModel.groupedByDate, id: \.date) { group in
                    Section(group.date) {
                        ForEach(group.entries) { entry in
                            entryRow(entry)
                        }
                    }
                }
            }
            .refreshable { await viewModel.load() }
        }
    }

    private func entryRow(_ entry: EntryDTO) -> some View {
        let category = viewModel.category(for: entry)
        return Button {
            viewModel.beginEditing(entry)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(category?.name ?? "Category \(entry.categoryId)")
                    .foregroundStyle(.primary)
                Text(EntrySummary.line(for: entry, category: category))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                pendingDeletion = entry
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

/// Builds a human-readable "field: value" summary of an entry's values, using the
/// category's field names when known. Kept separate so it is easy to reason about.
enum EntrySummary {
    static func line(for entry: EntryDTO, category: CategoryDTO?) -> String {
        let names = Dictionary(
            uniqueKeysWithValues: (category?.fields ?? []).map { ($0.id, $0.name) }
        )
        let parts = entry.values.compactMap { value -> String? in
            guard let raw = value.value, !raw.isEmpty else { return nil }
            let label = names[value.fieldId] ?? "Field \(value.fieldId)"
            return "\(label): \(raw)"
        }
        if parts.isEmpty {
            return entry.notes ?? "—"
        }
        return parts.joined(separator: ", ")
    }
}

/// Edit form for a single entry: one text field per category field plus a notes box.
/// The draft lives in the view model, so a failed save keeps the typed values.
struct EntryEditView: View {
    @ObservedObject var viewModel: EntriesViewModel
    @State private var isSaving = false

    private let categoryID: Int

    init(viewModel: EntriesViewModel, initialDraft: EntryEditDraft) {
        self.viewModel = viewModel
        self.categoryID = initialDraft.categoryId
    }

    private var category: CategoryDTO? {
        viewModel.categories.first { $0.id == categoryID }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let fields = category?.fields, !fields.isEmpty {
                    Section("Values") {
                        ForEach(fields.sorted { $0.order < $1.order }) { field in
                            LabeledContent(field.name) {
                                TextField("Value", text: valueBinding(fieldID: field.id))
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(field.fieldType == .number ? .decimalPad : .default)
                            }
                        }
                    }
                }
                Section("Notes") {
                    TextField("Notes", text: notesBinding, axis: .vertical)
                        .lineLimit(1...4)
                }
                if let message = viewModel.saveErrorMessage {
                    Section {
                        Text(message).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.cancelEditing() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(isSaving)
                }
            }
        }
    }

    private func valueBinding(fieldID: Int) -> Binding<String> {
        Binding(
            get: { viewModel.editDraft?.values[fieldID] ?? "" },
            set: { viewModel.editDraft?.values[fieldID] = $0 }
        )
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { viewModel.editDraft?.notes ?? "" },
            set: { viewModel.editDraft?.notes = $0 }
        )
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        _ = await viewModel.saveEdit()
    }
}
