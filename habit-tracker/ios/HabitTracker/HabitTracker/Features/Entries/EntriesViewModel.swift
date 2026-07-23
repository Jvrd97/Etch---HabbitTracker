// [review:need-review] PHASE-01/08-ios-entries-crud
// summary: Entries history state — load list + categories, category filter, date grouping, edit draft (values/notes) PATCH, DELETE
import Foundation
import os

/// A single entry being edited in the history form. `values` is keyed by field id
/// so the form can bind each of the category's fields to its current value; it is
/// serialized back to the backend's value list only when the PATCH payload is built.
struct EntryEditDraft: Equatable, Identifiable {
    let entryId: Int
    let categoryId: Int
    var entryDate: String
    var notes: String
    var values: [Int: String]

    /// Stable identity for `.sheet(item:)`: one draft per entry.
    var id: Int { entryId }
}

@MainActor
final class EntriesViewModel: ObservableObject {
    /// Discriminated load state for the history list.
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failure(String)
    }

    /// One day's worth of entries, for the sectioned list.
    struct DayGroup: Equatable {
        let date: String
        let entries: [EntryDTO]
    }

    @Published private(set) var state: LoadState = .idle
    @Published private(set) var entries: [EntryDTO] = []
    @Published private(set) var categories: [CategoryDTO] = []
    /// Category filter for the list; `nil` shows every category.
    @Published var selectedCategoryId: Int?
    /// The entry currently open in the edit form; `nil` when no form is shown.
    /// A failed save leaves it intact so the user's input is never lost.
    @Published var editDraft: EntryEditDraft?
    @Published var saveErrorMessage: String?

    static let notConfiguredMessage = "Set the server address in Settings"

    private let apiProvider: () -> EntriesAPI?

    /// Primary init: the provider is re-evaluated on every call, so Settings
    /// changes (server address / API key) take effect without an app restart.
    init(apiProvider: @escaping () -> EntriesAPI?) {
        self.apiProvider = apiProvider
    }

    /// Convenience init with a fixed API (used by unit tests).
    convenience init(api: EntriesAPI) {
        self.init(apiProvider: { api })
    }

    private static let logger = Logger(
        subsystem: "com.habittracker.app", category: "EntriesViewModel"
    )

    /// Builds the production view model from stored Settings (UserDefaults + Keychain).
    static func live() -> EntriesViewModel {
        EntriesViewModel(apiProvider: {
            let address = UserDefaults.standard
                .string(forKey: SettingsViewModel.serverAddressDefaultsKey) ?? ""
            guard let baseURL = APIClient.makeBaseURL(from: address) else {
                return nil
            }
            let keychain = KeychainStore()
            return APIClient(
                baseURL: baseURL,
                apiKeyProvider: {
                    do {
                        return try keychain.read(SettingsViewModel.apiKeyKeychainKey)
                    } catch {
                        // A Keychain failure must not crash a background request:
                        // send it without a key and let the backend answer 401,
                        // which surfaces as a visible error. Logged (no secrets).
                        Self.logger.error(
                            "Keychain read for API key failed: \(String(describing: error))"
                        )
                        return nil
                    }
                }
            )
        })
    }

    // MARK: - Derived state

    /// Entries matching the current category filter, preserving load order.
    var filteredEntries: [EntryDTO] {
        guard let categoryID = selectedCategoryId else { return entries }
        return entries.filter { $0.categoryId == categoryID }
    }

    /// Filtered entries grouped by day, newest day first; within a day, load order.
    var groupedByDate: [DayGroup] {
        let grouped = Dictionary(grouping: filteredEntries) { $0.entryDate }
        return grouped
            .map { DayGroup(date: $0.key, entries: $0.value) }
            .sorted { $0.date > $1.date }
    }

    /// The category an entry belongs to, if still loaded (drives field labels).
    func category(for entry: EntryDTO) -> CategoryDTO? {
        categories.first { $0.id == entry.categoryId }
    }

    // MARK: - Loading

    /// Loads every category (for names/field labels) and the entry history in one pass.
    func load() async {
        state = .loading
        guard let api = apiProvider() else {
            state = .failure(Self.notConfiguredMessage)
            return
        }
        do {
            async let categoriesTask = api.fetchCategories()
            async let entriesTask = api.fetchEntries(categoryId: nil)
            let (fetchedCategories, fetchedEntries) = try await (categoriesTask, entriesTask)
            categories = fetchedCategories
            entries = fetchedEntries
            state = .loaded
        } catch let error as APIClientError {
            state = .failure(error.userMessage)
        } catch {
            state = .failure("Unexpected error")
        }
    }

    // MARK: - Editing

    /// Opens the edit form for an entry, seeding the draft from its current values.
    func beginEditing(_ entry: EntryDTO) {
        saveErrorMessage = nil
        editDraft = EntryEditDraft(
            entryId: entry.id,
            categoryId: entry.categoryId,
            entryDate: entry.entryDate,
            notes: entry.notes ?? "",
            values: Dictionary(
                uniqueKeysWithValues: entry.values.map { ($0.fieldId, $0.value ?? "") }
            )
        )
    }

    /// Cancels editing without touching the list.
    func cancelEditing() {
        editDraft = nil
        saveErrorMessage = nil
    }

    /// Saves the open draft via `PATCH /entries/{id}`. On success the updated entry
    /// replaces its list row and the form closes. On failure the draft is kept intact
    /// (so typed values survive a network error) and an error message is surfaced.
    func saveEdit() async -> Bool {
        guard let draft = editDraft else { return false }
        saveErrorMessage = nil
        guard let api = requireAPI() else { return false }
        let payload = EntryUpdateDTO(
            entryDate: draft.entryDate,
            notes: draft.notes.isEmpty ? nil : draft.notes,
            values: draft.values
                .sorted { $0.key < $1.key }
                .map { EntryValueDTO(fieldId: $0.key, value: $0.value) }
        )
        do {
            let updated = try await api.updateEntry(id: draft.entryId, payload)
            if let index = entries.firstIndex(where: { $0.id == updated.id }) {
                entries[index] = updated
            }
            editDraft = nil
            return true
        } catch let error as APIClientError {
            saveErrorMessage = error.userMessage
            return false
        } catch {
            saveErrorMessage = "Unexpected error"
            return false
        }
    }

    // MARK: - Deleting

    /// Deletes an entry via `DELETE /entries/{id}` and drops it from the list.
    /// On failure the entry stays and an error is surfaced. Returns true on success.
    func deleteEntry(id: Int) async -> Bool {
        saveErrorMessage = nil
        guard let api = requireAPI() else { return false }
        do {
            try await api.deleteEntry(id: id)
            entries.removeAll { $0.id == id }
            return true
        } catch let error as APIClientError {
            saveErrorMessage = error.userMessage
            return false
        } catch {
            saveErrorMessage = "Unexpected error"
            return false
        }
    }

    // MARK: - Private

    private func requireAPI() -> EntriesAPI? {
        guard let api = apiProvider() else {
            saveErrorMessage = Self.notConfiguredMessage
            return nil
        }
        return api
    }
}
