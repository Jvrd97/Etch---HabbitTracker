// [review:need-review] PHASE-01/05-ios-today-quick-entry
// summary: Today screen state — loads categories + entries; POST for form, idempotent checklist PUT
import Foundation
import os

@MainActor
final class TodayViewModel: ObservableObject {
    /// Discriminated load state for the Today list.
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failure(String)
    }

    @Published private(set) var state: LoadState = .idle
    @Published private(set) var categories: [CategoryDTO] = []
    @Published private(set) var todayEntries: [EntryDTO] = []
    @Published var saveErrorMessage: String?

    static let notConfiguredMessage = "Set the server address in Settings"

    private let apiProvider: () -> TodayAPI?
    private let dateFormatter: DateFormatter
    private let now: () -> Date

    /// Primary init: the provider is re-evaluated on every load, so Settings
    /// changes (server address / API key) take effect without an app restart.
    init(
        apiProvider: @escaping () -> TodayAPI?,
        timeZone: TimeZone = .current,
        now: @escaping () -> Date = Date.init
    ) {
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
        api: TodayAPI,
        timeZone: TimeZone = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.init(apiProvider: { api }, timeZone: timeZone, now: now)
    }

    private static let logger = Logger(
        subsystem: "com.habittracker.app", category: "TodayViewModel"
    )

    /// Builds the production view model from stored Settings (UserDefaults + Keychain).
    static func live() -> TodayViewModel {
        TodayViewModel(apiProvider: {
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
                        // send the request without a key and let the backend
                        // answer 401, which surfaces as a visible error in the UI.
                        // Logged (status code only, no secrets) so it is not
                        // silently swallowed.
                        Self.logger.error(
                            "Keychain read for API key failed: \(String(describing: error))"
                        )
                        return nil
                    }
                }
            )
        })
    }

    /// Today's date in the backend's `YYYY-MM-DD` format.
    var todayString: String {
        dateFormatter.string(from: now())
    }

    /// Loads active categories and today's entries in one pass.
    func load() async {
        state = .loading
        guard let api = apiProvider() else {
            state = .failure(Self.notConfiguredMessage)
            return
        }
        let today = todayString
        do {
            async let categoriesTask = api.fetchCategories()
            async let entriesTask = api.fetchEntries(startDate: today, endDate: today)
            let (fetchedCategories, fetchedEntries) = try await (categoriesTask, entriesTask)
            categories = fetchedCategories.filter(\.isActive)
            todayEntries = fetchedEntries
            state = .loaded
        } catch let error as APIClientError {
            state = .failure(error.userMessage)
        } catch {
            state = .failure("Unexpected error")
        }
    }

    /// Today's entries belonging to the given category.
    func entries(forCategory categoryID: Int) -> [EntryDTO] {
        todayEntries.filter { $0.categoryId == categoryID }
    }

    /// Saves today's values for the category. Form categories create a new entry
    /// via generic POST; checklist categories go through the idempotent
    /// `PUT /entries/checklist` upsert (one entry per category+date on the backend).
    /// Returns true on success.
    func saveEntry(categoryID: Int, values: [Int: String]) async -> Bool {
        saveErrorMessage = nil
        guard let api = apiProvider() else {
            saveErrorMessage = Self.notConfiguredMessage
            return false
        }
        let isChecklist = categories.first { $0.id == categoryID }?.isChecklist ?? false
        do {
            let saved: EntryDTO
            if isChecklist {
                saved = try await api.upsertChecklistEntry(
                    ChecklistUpsertDTO(
                        categoryId: categoryID,
                        entryDate: todayString,
                        values: Dictionary(
                            uniqueKeysWithValues: values.map {
                                (String($0.key), $0.value == "true")
                            }
                        )
                    )
                )
            } else {
                saved = try await api.createEntry(
                    EntryCreateDTO(
                        categoryId: categoryID,
                        entryDate: todayString,
                        notes: nil,
                        values: values
                            .sorted { $0.key < $1.key }
                            .map { EntryValueDTO(fieldId: $0.key, value: $0.value) }
                    )
                )
            }
            // The checklist upsert can return an entry we already loaded — replace
            // it in place so the list never shows duplicates.
            if let index = todayEntries.firstIndex(where: { $0.id == saved.id }) {
                todayEntries[index] = saved
            } else {
                todayEntries.append(saved)
            }
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
