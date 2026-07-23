// [review:need-review] PHASE-01/05-ios-today-quick-entry
// summary: Today screen — habit list, dynamic quick-entry sheet with required-field gating
import SwiftUI

struct TodayView: View {
    @StateObject private var viewModel: TodayViewModel
    @State private var selectedCategory: CategoryDTO?

    init(viewModel: TodayViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Today")
        }
        .task {
            await viewModel.load()
        }
        .sheet(item: $selectedCategory) { category in
            QuickEntrySheet(category: category, viewModel: viewModel)
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
            categoryList
        }
    }

    private var categoryList: some View {
        List(viewModel.categories) { category in
            Button {
                selectedCategory = category
            } label: {
                HStack {
                    if let icon = category.icon, !icon.isEmpty {
                        Text(icon)
                    }
                    Text(category.name)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(todaySummary(for: category))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .refreshable {
            await viewModel.load()
        }
    }

    /// Compact right-side summary: today's single value, entry count, or a dash.
    private func todaySummary(for category: CategoryDTO) -> String {
        let entries = viewModel.entries(forCategory: category.id)
        if entries.isEmpty {
            return "—"
        }
        if entries.count == 1, entries[0].values.count == 1,
           let value = entries[0].values[0].value {
            return value
        }
        return "\(entries.count) entries"
    }
}

/// Dynamic entry form generated from the category's field definitions.
/// The first number field is auto-focused so "42 pushups" needs only:
/// tap habit → type 42 → tap Save.
struct QuickEntrySheet: View {
    let category: CategoryDTO
    @ObservedObject var viewModel: TodayViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var fieldValues: [Int: String] = [:]
    @State private var isSaving = false
    @FocusState private var focusedFieldID: Int?

    private var sortedFields: [FieldDTO] {
        category.fields.sorted { ($0.order, $0.id) < ($1.order, $1.id) }
    }

    /// Required fields the user has not filled in yet; Save stays disabled
    /// (and the field names are highlighted) until this is empty, so the sheet
    /// never sends a POST with missing required values.
    private var missingRequiredFields: [FieldDTO] {
        sortedFields.filter { field in
            field.isRequired && trimmedValue(for: field.id).isEmpty
        }
    }

    private func trimmedValue(for fieldID: Int) -> String {
        (fieldValues[fieldID] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(sortedFields) { field in
                        fieldRow(for: field)
                    }
                } footer: {
                    if !missingRequiredFields.isEmpty {
                        Text(
                            "Required: "
                                + missingRequiredFields.map(\.name).joined(separator: ", ")
                        )
                        .foregroundStyle(.red)
                    }
                }
                if let message = viewModel.saveErrorMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(category.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || !missingRequiredFields.isEmpty)
                }
            }
            .onAppear {
                // A previous sheet's failure message must not leak into this one.
                viewModel.saveErrorMessage = nil
                seedDefaults()
                focusedFieldID = sortedFields.first { $0.fieldType == .number }?.id
                    ?? sortedFields.first?.id
            }
        }
    }

    @ViewBuilder
    private func fieldRow(for field: FieldDTO) -> some View {
        switch field.fieldType {
        case .number:
            TextField(field.name, text: binding(for: field.id))
                .keyboardType(.decimalPad)
                .focused($focusedFieldID, equals: field.id)
        case .boolean:
            Toggle(field.name, isOn: boolBinding(for: field.id))
        case .select:
            Picker(field.name, selection: binding(for: field.id)) {
                Text("—").tag("")
                ForEach(selectOptions(for: field), id: \.self) { option in
                    Text(option).tag(option)
                }
            }
        case .text, .date, .datetime, .time, .duration, .unknown:
            TextField(field.name, text: binding(for: field.id))
                .focused($focusedFieldID, equals: field.id)
        }
    }

    private func seedDefaults() {
        for field in sortedFields {
            guard fieldValues[field.id] == nil else { continue }
            if let defaultValue = field.defaultValue {
                fieldValues[field.id] = defaultValue
            } else if field.fieldType == .boolean {
                // The toggle already renders "off"; seed it so what the user
                // sees is what gets sent, and required booleans count as filled.
                fieldValues[field.id] = "false"
            }
        }
    }

    private func binding(for fieldID: Int) -> Binding<String> {
        Binding(
            get: { fieldValues[fieldID] ?? "" },
            set: { fieldValues[fieldID] = $0 }
        )
    }

    private func boolBinding(for fieldID: Int) -> Binding<Bool> {
        Binding(
            get: { fieldValues[fieldID] == "true" },
            set: { fieldValues[fieldID] = $0 ? "true" : "false" }
        )
    }

    /// Parses the field's `options` JSON array (e.g. `["good", "bad"]`).
    private func selectOptions(for field: FieldDTO) -> [String] {
        guard let options = field.options,
              let data = options.data(using: .utf8),
              let parsed = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return parsed
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let nonEmptyValues = fieldValues.filter {
            !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if await viewModel.saveEntry(categoryID: category.id, values: nonEmptyValues) {
            dismiss()
        }
    }
}
