// [review:need-review] PHASE-01/11-ios-read-cache
// summary: read-cache integration tests for TodayViewModel — successful load caches + stays online; airplane mode serves the last cached snapshot with an offline timestamp; no cache surfaces the error
import XCTest
@testable import HabitTracker

@MainActor
final class TodayViewModelCacheTests: XCTestCase {
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

    private func category(id: Int, name: String) -> CategoryDTO {
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

    private func makeViewModel(
        api: MockTodayAPI, cache: CacheStore, now: Date
    ) -> TodayViewModel {
        TodayViewModel(
            api: api,
            cacheStore: cache,
            timeZone: TimeZone(identifier: "UTC")!,
            now: { now }
        )
    }

    func testSuccessfulLoadCachesAndStaysOnline() async {
        let api = MockTodayAPI()
        api.categoriesResult = .success([category(id: 1, name: "Pushups")])
        let store = InMemoryCacheStore()
        let viewModel = makeViewModel(api: api, cache: store, now: fixedDate(day: 23))

        await viewModel.load()

        XCTAssertEqual(viewModel.state, .loaded)
        XCTAssertNil(viewModel.offlineAsOf)
        XCTAssertEqual(viewModel.categories.map(\.id), [1])
        // The snapshot is now persisted for the next (possibly offline) load.
        XCTAssertNotNil(store.load(TodaySnapshot.self, forKey: TodayViewModel.cacheKey))
    }

    func testAirplaneModeServesCachedSnapshotWithOfflineTimestamp() async {
        let store = InMemoryCacheStore()
        let onlineDate = fixedDate(day: 23)

        let onlineAPI = MockTodayAPI()
        onlineAPI.categoriesResult = .success([category(id: 1, name: "Pushups")])
        let onlineVM = makeViewModel(api: onlineAPI, cache: store, now: onlineDate)
        await onlineVM.load()

        // A fresh view model with a dead network but the shared cache: it must show the
        // last data and an honest offline banner, not a white screen.
        let offlineAPI = MockTodayAPI()
        offlineAPI.categoriesResult = .failure(APIClientError.timeout)
        offlineAPI.entriesResult = .failure(APIClientError.timeout)
        let offlineVM = makeViewModel(api: offlineAPI, cache: store, now: fixedDate(day: 24))

        await offlineVM.load()

        XCTAssertEqual(offlineVM.state, .loaded)
        XCTAssertEqual(offlineVM.categories.map(\.id), [1])
        XCTAssertEqual(offlineVM.offlineAsOf, onlineDate)
    }

    func testOfflineWithoutCacheSurfacesFailure() async {
        let api = MockTodayAPI()
        api.categoriesResult = .failure(APIClientError.timeout)
        api.entriesResult = .failure(APIClientError.timeout)
        let viewModel = makeViewModel(api: api, cache: InMemoryCacheStore(), now: fixedDate(day: 23))

        await viewModel.load()

        XCTAssertEqual(viewModel.state, .failure(APIClientError.timeout.userMessage))
        XCTAssertNil(viewModel.offlineAsOf)
    }
}
