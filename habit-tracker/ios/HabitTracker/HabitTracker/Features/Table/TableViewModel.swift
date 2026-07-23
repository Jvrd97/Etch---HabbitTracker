// [review:need-review] PHASE-01/06-ios-table-view
// summary: Table screen state — loads GET /table (default 30 days), paginates older, fetches cell details
import Foundation
import os

@MainActor
final class TableViewModel: ObservableObject {
    /// Discriminated load state for the table grid.
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failure(String)
    }

    @Published private(set) var state: LoadState = .idle
    @Published private(set) var grid: TableGrid = .empty
    @Published private(set) var isLoadingOlder = false
    @Published var loadOlderErrorMessage: String?

    static let notConfiguredMessage = "Set the server address in Settings"
    /// Number of days fetched per page (initial load and each "load older" step).
    static let pageDays = 30

    private let apiProvider: () -> TableAPI?
    private let dateFormatter: DateFormatter
    private let calendar: Calendar
    private let now: () -> Date

    /// Accumulated days keyed by their `YYYY-MM-DD` string; the source of truth
    /// the grid is rebuilt from as older pages arrive.
    private var loadedDays: [String: TableDayDTO] = [:]
    private var categories: [TableCategoryMetaDTO] = []
    /// Start of the oldest range already fetched; the next page ends the day before it.
    private var earliestLoadedFrom: Date?

    private static let logger = Logger(
        subsystem: "com.habittracker.app", category: "TableViewModel"
    )

    /// Primary init: the provider is re-evaluated on every load, so Settings
    /// changes (server address / API key) take effect without an app restart.
    init(
        apiProvider: @escaping () -> TableAPI?,
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
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    /// Convenience init with a fixed API (used by unit tests).
    convenience init(
        api: TableAPI,
        timeZone: TimeZone = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.init(apiProvider: { api }, timeZone: timeZone, now: now)
    }

    /// Builds the production view model from stored Settings (UserDefaults + Keychain).
    static func live() -> TableViewModel {
        TableViewModel(apiProvider: {
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
                        // send without a key and let the backend answer 401,
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

    /// Loads the most recent `pageDays` days, replacing any previously loaded data.
    func load() async {
        state = .loading
        loadOlderErrorMessage = nil
        guard let api = apiProvider() else {
            state = .failure(Self.notConfiguredMessage)
            return
        }
        let to = now()
        let from = pageStart(endingAt: to)
        do {
            let response = try await api.fetchTable(
                dateFrom: dateFormatter.string(from: from),
                dateTo: dateFormatter.string(from: to)
            )
            categories = response.categories
            loadedDays = Dictionary(
                response.days.map { ($0.date, $0) }, uniquingKeysWith: { _, new in new }
            )
            earliestLoadedFrom = from
            rebuildGrid()
            state = .loaded
        } catch let error as APIClientError {
            state = .failure(error.userMessage)
        } catch {
            state = .failure("Unexpected error")
        }
    }

    /// Fetches the previous `pageDays` days and merges them into the grid.
    /// No-op unless the initial load has succeeded and no page is already in flight.
    func loadOlder() async {
        guard state == .loaded, !isLoadingOlder,
              let api = apiProvider(),
              let currentFrom = earliestLoadedFrom,
              let newTo = calendar.date(byAdding: .day, value: -1, to: currentFrom) else {
            return
        }
        isLoadingOlder = true
        loadOlderErrorMessage = nil
        defer { isLoadingOlder = false }
        let newFrom = pageStart(endingAt: newTo)
        do {
            let response = try await api.fetchTable(
                dateFrom: dateFormatter.string(from: newFrom),
                dateTo: dateFormatter.string(from: newTo)
            )
            for day in response.days {
                loadedDays[day.date] = day
            }
            if !response.categories.isEmpty {
                categories = response.categories
            }
            earliestLoadedFrom = newFrom
            rebuildGrid()
        } catch let error as APIClientError {
            loadOlderErrorMessage = error.userMessage
        } catch {
            loadOlderErrorMessage = "Unexpected error"
        }
    }

    /// Source entries behind a cell: the day's records for the tapped habit,
    /// which the aggregated value was composed from.
    func fetchCellEntries(categoryId: Int, date: String) async throws -> [EntryDTO] {
        guard let api = apiProvider() else {
            throw APIClientError.invalidBaseURL
        }
        return try await api.fetchEntries(categoryId: categoryId, date: date)
    }

    private func pageStart(endingAt end: Date) -> Date {
        calendar.date(byAdding: .day, value: -(Self.pageDays - 1), to: end) ?? end
    }

    private func rebuildGrid() {
        let days = loadedDays.values.sorted { $0.date > $1.date }
        grid = TableGrid(from: TableResponseDTO(categories: categories, days: Array(days)))
    }
}
