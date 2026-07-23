// [review:need-review] PHASE-01/10-ios-dashboard
// summary: unit tests for DashboardViewModel — counter aggregation, recent activity (newest first, capped), failure + not-configured states
import XCTest
@testable import HabitTracker

/// Scriptable stand-in for the API used by `DashboardViewModel`.
final class MockDashboardAPI: DashboardAPI {
    var categoriesResult: Result<[CategoryDTO], Error> = .success([])
    var entriesResult: Result<[EntryDTO], Error> = .success([])
    var journalResult: Result<JournalListResponseDTO, Error> = .success(
        JournalListResponseDTO(total: 0, items: [])
    )
    private(set) var entriesCategoryFilters: [Int?] = []

    func fetchCategories() async throws -> [CategoryDTO] {
        try categoriesResult.get()
    }

    func fetchEntries(categoryId: Int?) async throws -> [EntryDTO] {
        entriesCategoryFilters.append(categoryId)
        return try entriesResult.get()
    }

    func fetchJournalList() async throws -> JournalListResponseDTO {
        try journalResult.get()
    }
}

@MainActor
final class DashboardViewModelTests: XCTestCase {
    private func makeCategory(id: Int, name: String) -> CategoryDTO {
        CategoryDTO(
            id: id,
            name: name,
            icon: nil,
            color: nil,
            displayMode: "form",
            isActive: true,
            fields: []
        )
    }

    private func makeEntry(id: Int, date: String) -> EntryDTO {
        EntryDTO(id: id, categoryId: 1, entryDate: date, values: [])
    }

    // MARK: - Counters (acceptance: parity with the web dashboard counters)

    func testLoadAggregatesCounters() async {
        let api = MockDashboardAPI()
        api.categoriesResult = .success([
            makeCategory(id: 1, name: "Отжимания"),
            makeCategory(id: 2, name: "Сон"),
        ])
        api.entriesResult = .success([
            makeEntry(id: 1, date: "2026-07-20"),
            makeEntry(id: 2, date: "2026-07-19"),
            makeEntry(id: 3, date: "2026-07-18"),
        ])
        api.journalResult = .success(JournalListResponseDTO(total: 7, items: []))

        let viewModel = DashboardViewModel(api: api)
        await viewModel.load()

        XCTAssertEqual(viewModel.state, .loaded)
        XCTAssertEqual(viewModel.stats.categoriesCount, 2)
        XCTAssertEqual(viewModel.stats.entriesCount, 3)
        XCTAssertEqual(viewModel.stats.journalCount, 7)
        // The dashboard aggregates from the unfiltered entries list.
        XCTAssertEqual(api.entriesCategoryFilters, [nil])
    }

    // MARK: - Recent activity

    func testRecentEntriesAreNewestFirstAndCapped() async {
        let api = MockDashboardAPI()
        api.entriesResult = .success([
            makeEntry(id: 3, date: "2026-07-18"),
            makeEntry(id: 6, date: "2026-07-21"),
            makeEntry(id: 1, date: "2026-07-20"),
            makeEntry(id: 2, date: "2026-07-20"),
            makeEntry(id: 4, date: "2026-07-19"),
            makeEntry(id: 5, date: "2026-07-17"),
        ])

        let viewModel = DashboardViewModel(api: api)
        await viewModel.load()

        // Newest first (date desc, id desc on ties), capped at the recent limit (5).
        XCTAssertEqual(viewModel.stats.recentEntries.map(\.id), [6, 2, 1, 4, 3])
        XCTAssertEqual(viewModel.stats.recentEntries.count, DashboardViewModel.recentEntriesLimit)
    }

    // MARK: - Failure / configuration

    func testLoadFailureSetsFailureMessage() async {
        let api = MockDashboardAPI()
        api.categoriesResult = .failure(APIClientError.timeout)

        let viewModel = DashboardViewModel(api: api)
        await viewModel.load()

        guard case .failure(let message) = viewModel.state else {
            return XCTFail("Expected failure state, got \(viewModel.state)")
        }
        XCTAssertFalse(message.isEmpty)
    }

    func testLoadWithoutConfiguredAPIFails() async {
        let viewModel = DashboardViewModel(apiProvider: { nil })
        await viewModel.load()

        XCTAssertEqual(viewModel.state, .failure(DashboardViewModel.notConfiguredMessage))
    }
}
