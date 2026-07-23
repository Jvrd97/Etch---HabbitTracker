// [review:need-review] PHASE-01/35-ios-category-detail
// summary: Single-category detail state — loads that category's entries, quick-add of first field; grouping/edit/delete come from the shared EntryMutating surface
import Foundation

@MainActor
final class CategoryDetailViewModel: ObservableObject, EntryMutating {
    /// The category this screen is scoped to; drives the header and field labels.
    let category: CategoryDTO

    @Published private(set) var state: EntryLoadState = .idle
    @Published var entries: [EntryDTO] = []
    /// Raw text bound to the quick-add field (the category's first field).
    @Published var quickAddValue: String = ""
    /// The entry currently open in the edit form; `nil` when no form is shown.
    /// A failed save leaves it intact so the user's input is never lost.
    @Published var editDraft: EntryEditDraft?
    @Published var saveErrorMessage: String?

    private let apiProvider: () -> CategoryDetailAPI?
    private let dateFormatter: DateFormatter
    private let now: () -> Date

    /// Primary init: the provider is re-evaluated on every call, so Settings
    /// changes (server address / API key) take effect without an app restart.
    init(
        category: CategoryDTO,
        apiProvider: @escaping () -> CategoryDetailAPI?,
        timeZone: TimeZone = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.category = category
        self.apiProvider = apiProvider
        self.now = now
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        self.dateFormatter = formatter
    }

    /// Convenience init with a fixed API (used by unit tests).
    convenience init(
        category: CategoryDTO,
        api: CategoryDetailAPI,
        timeZone: TimeZone = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.init(category: category, apiProvider: { api }, timeZone: timeZone, now: now)
    }

    /// Builds the production view model for a category from stored Settings.
    static func live(category: CategoryDTO) -> CategoryDetailViewModel {
        CategoryDetailViewModel(
            category: category, apiProvider: { EntryMutationLive.makeAPIClient() }
        )
    }

    func mutationAPI() -> EntryMutationAPI? { apiProvider() }

    // MARK: - Derived state

    /// Today's date in the backend's `YYYY-MM-DD` format.
    var todayString: String {
        dateFormatter.string(from: now())
    }

    /// The field the quick-add box writes to: the category's first field by order.
    var quickAddField: FieldDTO? {
        category.fields.sorted { $0.order < $1.order }.first
    }

    // MARK: - Loading

    /// Loads this category's entry history (server-side filtered by category id).
    func load() async {
        state = .loading
        guard let api = apiProvider() else {
            state = .failure(Self.notConfiguredMessage)
            return
        }
        do {
            entries = try await api.fetchEntries(categoryId: category.id)
            state = .loaded
        } catch let error as APIClientError {
            state = .failure(error.userMessage)
        } catch {
            state = .failure("Unexpected error")
        }
    }

    // MARK: - Quick-add

    /// Records today's value for the category's first field via generic POST.
    /// A blank value or a category without fields is a no-op. On success the new
    /// entry is inserted at the top of the list and the input is cleared. Returns
    /// true on success.
    func quickAdd() async -> Bool {
        saveErrorMessage = nil
        let trimmed = quickAddValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let field = quickAddField else { return false }
        guard let api = requireAPI() as? CategoryDetailAPI else { return false }
        let payload = EntryCreateDTO(
            categoryId: category.id,
            entryDate: todayString,
            notes: nil,
            values: [EntryValueDTO(fieldId: field.id, value: trimmed)]
        )
        do {
            let created = try await api.createEntry(payload)
            entries.insert(created, at: 0)
            quickAddValue = ""
            return true
        } catch let error as APIClientError {
            saveErrorMessage = error.userMessage
            return false
        } catch {
            saveErrorMessage = "Unexpected error"
            return false
        }
    }
}
