// [review:need-review] PHASE-01/11-ios-read-cache
// summary: read-cache primitives — CacheStore protocol, in-memory impl, connectivity classifier, and ReadThroughCache that serves cached data (with a stale timestamp) when the network is down
import Foundation

/// A cached payload together with the moment it was written. `updatedAt` is what
/// the offline banner shows ("data from <time>").
struct CachedValue<T> {
    let value: T
    let updatedAt: Date
}

/// Persists Codable snapshots keyed by a stable string, with the write timestamp.
/// Implementations are the transparent persistence behind `ReadThroughCache`; the
/// interface stays intentionally small so a feature only ever sees whole snapshots.
protocol CacheStore {
    /// Overwrites the entry at `key` with `value`, stamping it `updatedAt`.
    func save<T: Encodable>(_ value: T, forKey key: String, updatedAt: Date)
    /// Returns the cached value at `key`, or nil when absent or undecodable.
    func load<T: Decodable>(_ type: T.Type, forKey key: String) -> CachedValue<T>?
}

/// Coder shared by every `CacheStore`: both ends are this app, so the on-disk form
/// is the DTOs' native casing (no snake_case conversion) — it never crosses the wire.
enum CacheCoding {
    static func encoder() -> JSONEncoder { JSONEncoder() }
    static func decoder() -> JSONDecoder { JSONDecoder() }
}

/// Process-lifetime cache backed by a dictionary. Used as the default in unit tests
/// and as the fallback when the on-disk store cannot be created.
final class InMemoryCacheStore: CacheStore {
    private struct Record {
        let payload: Data
        let updatedAt: Date
    }

    private var records: [String: Record] = [:]

    func save<T: Encodable>(_ value: T, forKey key: String, updatedAt: Date) {
        guard let data = try? CacheCoding.encoder().encode(value) else { return }
        records[key] = Record(payload: data, updatedAt: updatedAt)
    }

    func load<T: Decodable>(_ type: T.Type, forKey key: String) -> CachedValue<T>? {
        guard let record = records[key],
              let value = try? CacheCoding.decoder().decode(T.self, from: record.payload) else {
            return nil
        }
        return CachedValue(value: value, updatedAt: record.updatedAt)
    }
}

extension APIClientError {
    /// Whether the error means the server was unreachable (timeout / transport). Only
    /// these justify serving stale cache: a reachable server that answered 401/500 is
    /// a real error the user must see, not an excuse to show old data.
    var isConnectivity: Bool {
        switch self {
        case .timeout, .transport:
            return true
        case .invalidBaseURL, .unauthorized, .unexpectedStatus, .invalidResponse:
            return false
        }
    }
}

/// Outcome of a read-through load: either freshly fetched, or served from cache
/// because the network was down (carrying the timestamp for the offline banner).
enum CacheOutcome<T> {
    case fresh(T)
    case stale(T, updatedAt: Date)
}

/// The transparent read cache. A feature runs its fetch through `load`: a successful
/// response overwrites the cache and returns `.fresh`; a connectivity failure with a
/// cached snapshot returns `.stale` instead of throwing, so the UI keeps its last data.
struct ReadThroughCache {
    let store: CacheStore
    let now: () -> Date

    init(store: CacheStore, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.now = now
    }

    /// Fetches, caching on success. On a connectivity error, falls back to the cached
    /// snapshot when one exists; otherwise the original error is rethrown (nothing to show).
    func load<T: Codable>(
        key: String, fetch: () async throws -> T
    ) async throws -> CacheOutcome<T> {
        do {
            let value = try await fetch()
            store.save(value, forKey: key, updatedAt: now())
            return .fresh(value)
        } catch let error as APIClientError where error.isConnectivity {
            guard let cached = store.load(T.self, forKey: key) else {
                throw error
            }
            return .stale(cached.value, updatedAt: cached.updatedAt)
        }
    }
}
