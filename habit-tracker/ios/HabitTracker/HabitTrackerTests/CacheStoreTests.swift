// [review:need-review] PHASE-01/11-ios-read-cache
// summary: unit tests for the read-cache layer — SwiftData round-trip/overwrite, connectivity classifier, and ReadThroughCache fresh/stale/rethrow outcomes
import XCTest
@testable import HabitTracker

private struct Sample: Codable, Equatable {
    let id: Int
    let name: String
}

final class CacheStoreTests: XCTestCase {
    private func makeDate(_ offset: TimeInterval = 0) -> Date {
        Date(timeIntervalSince1970: 1_700_000_000 + offset)
    }

    // MARK: - SwiftDataCacheStore

    func testSwiftDataStoreRoundTripsSavedValue() throws {
        let store = try SwiftDataCacheStore(inMemory: true)
        let stamp = makeDate()

        store.save(Sample(id: 1, name: "pushups"), forKey: "k", updatedAt: stamp)
        let loaded = store.load(Sample.self, forKey: "k")

        XCTAssertEqual(loaded?.value, Sample(id: 1, name: "pushups"))
        XCTAssertEqual(loaded?.updatedAt, stamp)
    }

    func testSwiftDataStoreOverwritesSameKeyInPlace() throws {
        let store = try SwiftDataCacheStore(inMemory: true)

        store.save(Sample(id: 1, name: "old"), forKey: "k", updatedAt: makeDate(0))
        store.save(Sample(id: 2, name: "new"), forKey: "k", updatedAt: makeDate(60))
        let loaded = store.load(Sample.self, forKey: "k")

        XCTAssertEqual(loaded?.value, Sample(id: 2, name: "new"))
        XCTAssertEqual(loaded?.updatedAt, makeDate(60))
    }

    func testSwiftDataStoreReturnsNilForMissingKey() throws {
        let store = try SwiftDataCacheStore(inMemory: true)
        XCTAssertNil(store.load(Sample.self, forKey: "absent"))
    }

    // MARK: - Connectivity classification

    func testConnectivityErrorsAreOnlyTimeoutAndTransport() {
        XCTAssertTrue(APIClientError.timeout.isConnectivity)
        XCTAssertTrue(APIClientError.transport(code: -1009).isConnectivity)
        XCTAssertFalse(APIClientError.unauthorized.isConnectivity)
        XCTAssertFalse(APIClientError.unexpectedStatus(500).isConnectivity)
        XCTAssertFalse(APIClientError.invalidResponse.isConnectivity)
        XCTAssertFalse(APIClientError.invalidBaseURL.isConnectivity)
    }

    // MARK: - ReadThroughCache

    func testLoadReturnsFreshAndWritesCache() async throws {
        let store = InMemoryCacheStore()
        let stamp = makeDate()
        let cache = ReadThroughCache(store: store, now: { stamp })

        let outcome = try await cache.load(key: "k") { Sample(id: 7, name: "fresh") }

        guard case .fresh(let value) = outcome else {
            return XCTFail("Expected fresh, got \(outcome)")
        }
        XCTAssertEqual(value, Sample(id: 7, name: "fresh"))
        // The successful response is now persisted with the clock's timestamp.
        let cached = store.load(Sample.self, forKey: "k")
        XCTAssertEqual(cached?.value, Sample(id: 7, name: "fresh"))
        XCTAssertEqual(cached?.updatedAt, stamp)
    }

    func testLoadServesStaleCacheOnConnectivityError() async throws {
        let store = InMemoryCacheStore()
        let firstStamp = makeDate(0)
        let firstCache = ReadThroughCache(store: store, now: { firstStamp })
        _ = try await firstCache.load(key: "k") { Sample(id: 1, name: "cached") }

        let secondCache = ReadThroughCache(store: store, now: { self.makeDate(999) })
        let outcome: CacheOutcome<Sample> = try await secondCache.load(key: "k") {
            throw APIClientError.timeout
        }

        guard case .stale(let value, let updatedAt) = outcome else {
            return XCTFail("Expected stale, got \(outcome)")
        }
        XCTAssertEqual(value, Sample(id: 1, name: "cached"))
        XCTAssertEqual(updatedAt, firstStamp)
    }

    func testLoadRethrowsConnectivityErrorWhenCacheEmpty() async {
        let cache = ReadThroughCache(store: InMemoryCacheStore(), now: { self.makeDate() })
        do {
            _ = try await cache.load(key: "k") { () throws -> Sample in
                throw APIClientError.timeout
            }
            XCTFail("Expected error to propagate when nothing is cached")
        } catch let error as APIClientError {
            XCTAssertEqual(error, .timeout)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testLoadRethrowsNonConnectivityErrorEvenWithCache() async throws {
        let store = InMemoryCacheStore()
        let cache = ReadThroughCache(store: store, now: { self.makeDate() })
        _ = try await cache.load(key: "k") { Sample(id: 1, name: "cached") }

        do {
            _ = try await cache.load(key: "k") { () throws -> Sample in
                throw APIClientError.unauthorized
            }
            XCTFail("A reachable-server error must not be masked by stale cache")
        } catch let error as APIClientError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
