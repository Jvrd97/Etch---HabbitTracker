// [review:need-review] PHASE-01/35-ios-category-detail
// summary: Shared entry components — generic EntryEditView over any EntryMutating VM, and EntrySummary "field: value" line builder
import SwiftUI

/// Edit form for a single entry: one text field per category field plus a notes box.
/// Generic over any `EntryMutating` view model, so the Entries history and the
/// single-category detail screens share one form. The draft lives in the view model,
/// so a failed save keeps the typed values. `fields` is supplied by the caller
/// (resolved from the entry's category) so the form stays decoupled from how each
/// screen stores its categories.
struct EntryEditView<Model: EntryMutating>: View {
    @ObservedObject var viewModel: Model
    let fields: [FieldDTO]
    @State private var isSaving = false

    private var sortedFields: [FieldDTO] {
        fields.sorted { $0.order < $1.order }
    }

    var body: some View {
        NavigationStack {
            Form {
                if !sortedFields.isEmpty {
                    Section("Values") {
                        ForEach(sortedFields) { field in
                            LabeledContent(field.name) {
                                TextField("Value", text: valueBinding(fieldID: field.id))
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(field.fieldType == .number ? .decimalPad : .default)
                            }
                        }
                    }
                    .listRowBackground(DS.Palette.card)
                }
                Section("Notes") {
                    TextField("Notes", text: notesBinding, axis: .vertical)
                        .lineLimit(1...4)
                }
                .listRowBackground(DS.Palette.card)
                if let message = viewModel.saveErrorMessage {
                    Section {
                        Text(message).foregroundStyle(DS.Palette.danger)
                    }
                    .listRowBackground(DS.Palette.card)
                }
            }
            .dsScreenBackground()
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
