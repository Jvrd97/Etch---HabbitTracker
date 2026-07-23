// [review:need-review] PHASE-01/06-ios-table-view
// summary: unit tests for TableViewModel — 30-day load, older pagination merge, cell detail fetch, errors
import XCTest
@testable import HabitTracker

/// Scriptable stand-in for the table API used by `TableViewModel`.
final class MockTableAPI: TableAPI {
    var tableResults: [Result<TableResponseDTO, Error>] = []
    var entriesResult: Result<[EntryDTO], Error> = .success([])
    private(set) var tableRanges: [(from: String, to: String)] = []
    private(set) var entriesQueries: [(categoryId: Int, date: String)] = []

    func fetchTable(dateFrom: String, dateTo: String) async throws -> TableResponseDTO {
        tableRanges.append((from: dateFrom, to: dateTo))
        guard !tableResults.isEmpty else {
            return TableResponseDTO(categories: [], days: [])
        }
        return try tableResults.removeFirst().get()
    }

    func fetchEntries(categoryId: Int, date: String) async throws -> [EntryDTO] {
        entriesQueries.append((categoryId: categoryId, date: date))
        return try entriesResult.get()
    }
}

@MainActor
final class TableViewModelTests: XCTestCase {
    private func makeFixedDate() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 23
        components.hour = 12
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: components)!
    }

    private func makeViewModel(api: MockTableAPI) -> TableViewModel {
        let fixed = makeFixedDate()
        return TableViewModel(api: api, timeZone: TimeZone(identifier: "UTC")!, now: { fixed })
    }

    private func meta(id: Int, name: String, fieldId: Int) -> TableCategoryMetaDTO {
        TableCategoryMetaDTO(
            id: id,
            name: name,
            displayMode: "form",
            group: nil,
            primaryFieldId: fieldId,
            primaryFieldName: "count",
            primaryFieldType: "number"
        )
    }

    func testLoadRequestsMostRecentThirtyDaysAndBuildsGrid() async {
        let api = MockTableAPI()
        api.tableResults = [
            .success(
                TableResponseDTO(
                    categories: [meta(id: 1, name: "Pushups", fieldId: 10)],
                    days: [
                        TableDayDTO(
                            date: "2026-07-23",
                            cells: [
                                TableCellDTO(
                                    categoryId: 1, fieldId: 10,
                                    aggregatedValue: "42", entryCount: 2
                                )
                            ]
                        )
                    ]
                )
            )
        ]

        let viewModel = makeViewModel(api: api)
        await viewModel.load()

        XCTAssertEqual(viewModel.state, .loaded)
        XCTAssertEqual(api.tableRanges.count, 1)
        // 30-day window ending today (inclusive): 2026-06-24 .. 2026-07-23.
        XCTAssertEqual(api.tableRanges[0].from, "2026-06-24")
        XCTAssertEqual(api.tableRanges[0].to, "2026-07-23")
        XCTAssertEqual(viewModel.grid.columns.map(\.title), ["Pushups"])
        XCTAssertEqual(viewModel.grid.rows.map(\.date), ["2026-07-23"])
        XCTAssertEqual(
            viewModel.grid.rows[0].cells, [TableGridCell(value: "42", entryCount: 2)]
        )
    }

    func testLoadFailureSetsFailureStateWithoutCrash() async {
        let api = MockTableAPI()
        api.tableResults = [.failure(APIClientError.timeout)]

        let viewModel = makeViewModel(api: api)
        await viewModel.load()

        guard case .failure(let message) = viewModel.state else {
            return XCTFail("Expected failure state, got \(viewModel.state)")
        }
        XCTAssertEqual(message, "Connection timed out")
    }

    func testNotConfiguredProviderYieldsFailure() async {
        let viewModel = TableViewModel(
            apiProvider: { nil },
            timeZone: TimeZone(identifier: "UTC")!,
            now: { self.makeFixedDate() }
        )
        await viewModel.load()

        XCTAssertEqual(viewModel.state, .failure(TableViewModel.notConfiguredMessage))
    }

    func testLoadOlderFetchesPreviousBlockAndMergesRows() async {
        let api = MockTableAPI()
        api.tableResults = [
            .success(
                TableResponseDTO(
                    categories: [meta(id: 1, name: "Pushups", fieldId: 10)],
                    days: [TableDayDTO(date: "2026-07-23", cells: [])]
                )
            ),
            .success(
                TableResponseDTO(
                    categories: [meta(id: 1, name: "Pushups", fieldId: 10)],
                    days: [TableDayDTO(date: "2026-06-20", cells: [])]
                )
            ),
        ]

        let viewModel = makeViewModel(api: api)
        await viewModel.load()
        await viewModel.loadOlder()

        XCTAssertEqual(api.tableRanges.count, 2)
        // Older page ends the day before the first window's start (2026-06-24).
        XCTAssertEqual(api.tableRanges[1].to, "2026-06-23")
        XCTAssertEqual(api.tableRanges[1].from, "2026-05-25")
        XCTAssertEqual(viewModel.grid.rows.map(\.date), ["2026-07-23", "2026-06-20"])
        XCTAssertNil(viewModel.loadOlderErrorMessage)
    }

    func testLoadOlderKeepsGridAndReportsErrorOnFailure() async {
        let api = MockTableAPI()
        api.tableResults = [
            .success(
                TableResponseDTO(
                    categories: [meta(id: 1, name: "Pushups", fieldId: 10)],
                    days: [TableDayDTO(date: "2026-07-23", cells: [])]
                )
            ),
            .failure(APIClientError.unauthorized),
        ]

        let viewModel = makeViewModel(api: api)
        await viewModel.load()
        await viewModel.loadOlder()

        XCTAssertEqual(viewModel.state, .loaded)
        XCTAssertEqual(viewModel.grid.rows.map(\.date), ["2026-07-23"])
        XCTAssertEqual(viewModel.loadOlderErrorMessage, "Invalid API key (401)")
    }

    func testFetchCellEntriesQueriesCategoryAndDate() async throws {
        let api = MockTableAPI()
        api.entriesResult = .success([
            EntryDTO(
                id: 7,
                categoryId: 1,
                entryDate: "2026-07-23",
                values: [EntryValueDTO(fieldId: 10, value: "20")]
            )
        ])

        let viewModel = makeViewModel(api: api)
        let entries = try await viewModel.fetchCellEntries(categoryId: 1, date: "2026-07-23")

        XCTAssertEqual(api.entriesQueries.count, 1)
        XCTAssertEqual(api.entriesQueries[0].categoryId, 1)
        XCTAssertEqual(api.entriesQueries[0].date, "2026-07-23")
        XCTAssertEqual(entries.map(\.id), [7])
    }
}
