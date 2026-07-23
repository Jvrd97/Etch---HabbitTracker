// [review:need-review] PHASE-01/11-ios-read-cache
// summary: read-cache integration tests for TableViewModel — successful load caches + stays online; airplane mode serves the last cached window with an offline timestamp; no cache surfaces the error
import XCTest
@testable import HabitTracker

@MainActor
final class TableViewModelCacheTests: XCTestCase {
    private func fixedDate(day: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = day
        components.hour = 12
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: components)!
    }

    private func meta(id: Int, name: String) -> TableCategoryMetaDTO {
        TableCategoryMetaDTO(
            id: id,
            name: name,
            displayMode: "form",
            group: nil,
            primaryFieldId: 10,
            primaryFieldName: "count",
            primaryFieldType: "number"
        )
    }

    private func makeViewModel(
        api: MockTableAPI, cache: CacheStore, now: Date
    ) -> TableViewModel {
        TableViewModel(
            api: api,
            cacheStore: cache,
            timeZone: TimeZone(identifier: "UTC")!,
            now: { now }
        )
    }

    func testSuccessfulLoadCachesAndStaysOnline() async {
        let api = MockTableAPI()
        api.tableResults = [
            .success(
                TableResponseDTO(
                    categories: [meta(id: 1, name: "Pushups")],
                    days: [TableDayDTO(date: "2026-07-23", cells: [])]
                )
            )
        ]
        let store = InMemoryCacheStore()
        let viewModel = makeViewModel(api: api, cache: store, now: fixedDate(day: 23))

        await viewModel.load()

        XCTAssertEqual(viewModel.state, .loaded)
        XCTAssertNil(viewModel.offlineAsOf)
        XCTAssertEqual(viewModel.grid.columns.map(\.title), ["Pushups"])
        XCTAssertNotNil(store.load(TableResponseDTO.self, forKey: TableViewModel.cacheKey))
    }

    func testAirplaneModeServesCachedWindowWithOfflineTimestamp() async {
        let store = InMemoryCacheStore()
        let onlineDate = fixedDate(day: 23)

        let onlineAPI = MockTableAPI()
        onlineAPI.tableResults = [
            .success(
                TableResponseDTO(
                    categories: [meta(id: 1, name: "Pushups")],
                    days: [TableDayDTO(date: "2026-07-23", cells: [])]
                )
            )
        ]
        let onlineVM = makeViewModel(api: onlineAPI, cache: store, now: onlineDate)
        await onlineVM.load()

        let offlineAPI = MockTableAPI()
        offlineAPI.tableResults = [.failure(APIClientError.timeout)]
        let offlineVM = makeViewModel(api: offlineAPI, cache: store, now: fixedDate(day: 24))

        await offlineVM.load()

        XCTAssertEqual(offlineVM.state, .loaded)
        XCTAssertEqual(offlineVM.grid.columns.map(\.title), ["Pushups"])
        XCTAssertEqual(offlineVM.offlineAsOf, onlineDate)
    }

    func testOfflineWithoutCacheSurfacesFailure() async {
        let api = MockTableAPI()
        api.tableResults = [.failure(APIClientError.timeout)]
        let viewModel = makeViewModel(api: api, cache: InMemoryCacheStore(), now: fixedDate(day: 23))

        await viewModel.load()

        XCTAssertEqual(viewModel.state, .failure(APIClientError.timeout.userMessage))
        XCTAssertNil(viewModel.offlineAsOf)
    }
}
