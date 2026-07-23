// [review:need-review] PHASE-01/12-ios-offline-queue
// summary: unit tests for the offline outbox — enqueue offline then flush online sends once and clears; repeated failure keeps a single entry (no duplicate); order preserved; auto-flush on network online; SwiftData store round-trip; TodayViewModel enqueues on connectivity failure and shows the pending entry + badge; a background flush reactively clears the badge and reconciles the optimistic pending row away
import XCTest
@testable import HabitTracker

/// Scriptable poster standing in for the network side of the outbox.
private final class MockOutboxPoster: OutboxPosting {
    private(set) var received: [EntryCreateDTO] = []
    /// Idempotency-Key passed on each `createEntry` call, in call order.
    private(set) var receivedKeys: [String?] = []
    /// Behaviour per call; default echoes a saved entry back. Set to `throw` for failures.
    var behavior: (EntryCreateDTO) throws -> EntryDTO = { entry in
        EntryDTO(
            id: 1,
            categoryId: entry.categoryId,
            entryDate: entry.entryDate,
            notes: entry.notes,
            values: entry.values
        )
    }

    func createEntry(_ entry: EntryCreateDTO, idempotencyKey: String?) async throws -> EntryDTO {
        received.append(entry)
        receivedKeys.append(idempotencyKey)
        return try behavior(entry)
    }
}

/// Mock NWPathMonitor: records the flush handler and lets a test fire "became online".
@MainActor
private final class MockNetworkMonitor: NetworkPathMonitoring {
    private var handler: (() async -> Void)?
    private(set) var started = false

    func onBecameOnline(_ handler: @escaping () async -> Void) {
        self.handler = handler
    }

    func start() {
        started = true
    }

    func simulateOnline() async {
        await handler?()
    }
}

@MainActor
final class OutboxQueueTests: XCTestCase {
    private func makePayload(
        count: String, category: Int = 1, field: Int = 10, date: String = "2026-07-23"
    ) -> EntryCreateDTO {
        EntryCreateDTO(
            categoryId: category,
            entryDate: date,
            notes: nil,
            values: [EntryValueDTO(fieldId: field, value: count)]
        )
    }

    // MARK: - OutboxQueue

    func testEnqueueOfflineThenFlushOnlineSendsOnceAndClears() async {
        let queue = OutboxQueue(store: InMemoryOutboxStore())
        queue.enqueue(makePayload(count: "42"))
        XCTAssertEqual(queue.pendingCount, 1)

        let poster = MockOutboxPoster()
        let saved = await queue.flush(using: poster)

        XCTAssertEqual(poster.received.count, 1)
        XCTAssertEqual(poster.received.first?.values.first?.value, "42")
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(queue.pendingCount, 0)
        XCTAssertTrue(queue.pending.isEmpty)
    }

    func testRepeatedFlushFailureKeepsSingleEntryAndNeverDuplicates() async {
        let queue = OutboxQueue(store: InMemoryOutboxStore())
        queue.enqueue(makePayload(count: "42"))

        let offline = MockOutboxPoster()
        offline.behavior = { _ in throw APIClientError.timeout }
        _ = await queue.flush(using: offline)
        _ = await queue.flush(using: offline)

        // Two failed flushes must not multiply the queued record.
        XCTAssertEqual(queue.pendingCount, 1)
        XCTAssertEqual(queue.pending.count, 1)
        XCTAssertEqual(queue.pending.first?.attempts, 2)

        // Network restored: the entry is sent exactly once and then removed.
        let online = MockOutboxPoster()
        _ = await queue.flush(using: online)
        XCTAssertEqual(online.received.count, 1)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testReplayedFlushSendsStableIdempotencyKeyEqualToPendingID() async {
        let queue = OutboxQueue(store: InMemoryOutboxStore())
        queue.enqueue(makePayload(count: "42"))
        let pendingID = queue.pending.first!.id.uuidString

        // First flush hits a dead network: the entry survives and is replayed next time.
        let offline = MockOutboxPoster()
        offline.behavior = { _ in throw APIClientError.timeout }
        _ = await queue.flush(using: offline)

        // Second flush succeeds. The lost-ack window closes only if the replay carries
        // the same key as the first attempt — namely the stable PendingEntry.id.
        let online = MockOutboxPoster()
        _ = await queue.flush(using: online)

        XCTAssertEqual(offline.receivedKeys, [pendingID])
        XCTAssertEqual(online.receivedKeys, [pendingID])
    }

    func testFlushPreservesEnqueueOrder() async {
        var tick = Date(timeIntervalSince1970: 0)
        let queue = OutboxQueue(store: InMemoryOutboxStore(), now: {
            defer { tick += 1 }
            return tick
        })
        queue.enqueue(makePayload(count: "1"))
        queue.enqueue(makePayload(count: "2"))
        queue.enqueue(makePayload(count: "3"))

        let poster = MockOutboxPoster()
        _ = await queue.flush(using: poster)

        XCTAssertEqual(poster.received.map { $0.values.first?.value }, ["1", "2", "3"])
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testConnectivityFailureStopsFlushAndKeepsLaterEntriesForRetry() async {
        var tick = Date(timeIntervalSince1970: 0)
        let queue = OutboxQueue(store: InMemoryOutboxStore(), now: {
            defer { tick += 1 }
            return tick
        })
        queue.enqueue(makePayload(count: "1"))
        queue.enqueue(makePayload(count: "2"))

        let poster = MockOutboxPoster()
        poster.behavior = { _ in throw APIClientError.timeout }
        _ = await queue.flush(using: poster)

        // A dead network means the first attempt aborts the whole flush: only one
        // request is issued, and both entries survive in order for the next trigger.
        XCTAssertEqual(poster.received.count, 1)
        XCTAssertEqual(queue.pendingCount, 2)
        XCTAssertEqual(queue.pending.map { $0.payload.values.first?.value }, ["1", "2"])
    }

    func testAutoFlushRunsWhenNetworkBecomesOnline() async {
        let queue = OutboxQueue(store: InMemoryOutboxStore())
        queue.enqueue(makePayload(count: "42"))

        let poster = MockOutboxPoster()
        let monitor = MockNetworkMonitor()
        queue.startAutoFlush(monitor: monitor, posterProvider: { poster })
        XCTAssertTrue(monitor.started)

        await monitor.simulateOnline()

        XCTAssertEqual(poster.received.count, 1)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    // MARK: - SwiftData store

    func testSwiftDataOutboxStoreRoundTrips() throws {
        let store = try SwiftDataOutboxStore(inMemory: true)
        let entry = PendingEntry(
            id: UUID(),
            payload: makePayload(count: "42"),
            createdAt: Date(timeIntervalSince1970: 100),
            attempts: 0,
            status: .pending
        )
        store.append(entry)
        XCTAssertEqual(store.fetchAll().count, 1)
        XCTAssertEqual(store.fetchAll().first?.payload.values.first?.value, "42")

        var updated = entry
        updated.attempts = 3
        store.update(updated)
        XCTAssertEqual(store.fetchAll().first?.attempts, 3)

        store.delete(id: entry.id)
        XCTAssertTrue(store.fetchAll().isEmpty)
    }

    // MARK: - TodayViewModel integration

    private func category(id: Int, field: Int) -> CategoryDTO {
        CategoryDTO(
            id: id,
            name: "Pushups",
            icon: nil,
            color: nil,
            displayMode: "form",
            isActive: true,
            fields: [
                FieldDTO(
                    id: field,
                    name: "Count",
                    fieldType: .number,
                    isRequired: true,
                    defaultValue: nil,
                    options: nil,
                    order: 0
                )
            ]
        )
    }

    func testSaveEntryOfflineEnqueuesAndShowsPendingEntryAndBadge() async {
        let api = MockTodayAPI()
        api.categoriesResult = .success([category(id: 1, field: 10)])
        api.createEntryResult = .failure(APIClientError.timeout)
        let outbox = OutboxQueue(store: InMemoryOutboxStore())
        let fixed = Date(timeIntervalSince1970: 0)
        let viewModel = TodayViewModel(
            api: api,
            outbox: outbox,
            timeZone: TimeZone(identifier: "UTC")!,
            now: { fixed }
        )
        await viewModel.load()

        let saved = await viewModel.saveEntry(categoryID: 1, values: [10: "42"])

        // Airplane mode must not lose the record: it is optimistically accepted,
        // queued, shown in the list, and counted by the badge.
        XCTAssertTrue(saved)
        XCTAssertEqual(outbox.pendingCount, 1)
        XCTAssertEqual(viewModel.pendingUploadCount, 1)
        XCTAssertEqual(viewModel.entries(forCategory: 1).count, 1)
        XCTAssertEqual(viewModel.entries(forCategory: 1).first?.values.first?.value, "42")
        XCTAssertNil(viewModel.saveErrorMessage)
    }

    func testSaveEntryOnlineDoesNotEnqueue() async {
        let api = MockTodayAPI()
        api.categoriesResult = .success([category(id: 1, field: 10)])
        api.createEntryResult = .success(
            EntryDTO(
                id: 101,
                categoryId: 1,
                entryDate: "2026-07-23",
                values: [EntryValueDTO(fieldId: 10, value: "42")]
            )
        )
        let outbox = OutboxQueue(store: InMemoryOutboxStore())
        let fixed = Date(timeIntervalSince1970: 0)
        let viewModel = TodayViewModel(
            api: api,
            outbox: outbox,
            timeZone: TimeZone(identifier: "UTC")!,
            now: { fixed }
        )
        await viewModel.load()

        let saved = await viewModel.saveEntry(categoryID: 1, values: [10: "42"])

        XCTAssertTrue(saved)
        XCTAssertEqual(outbox.pendingCount, 0)
        XCTAssertEqual(viewModel.pendingUploadCount, 0)
    }

    func testBackgroundFlushClearsBadgeAndOptimisticPendingRow() async {
        let api = MockTodayAPI()
        api.categoriesResult = .success([category(id: 1, field: 10)])
        // Offline while saving: the create is queued and shown optimistically.
        api.createEntryResult = .failure(APIClientError.timeout)
        let outbox = OutboxQueue(store: InMemoryOutboxStore())
        let fixed = Date(timeIntervalSince1970: 0)
        let viewModel = TodayViewModel(
            api: api,
            outbox: outbox,
            timeZone: TimeZone(identifier: "UTC")!,
            now: { fixed }
        )
        await viewModel.load()
        _ = await viewModel.saveEntry(categoryID: 1, values: [10: "42"])

        // Precondition: badge shows 1 and an optimistic pending row is in the list.
        XCTAssertEqual(viewModel.pendingUploadCount, 1)
        XCTAssertTrue(viewModel.todayEntries.contains { $0.isPending })

        // Network restored: the monitor fires a background flush against a live poster,
        // with no manual pull-to-refresh from the user.
        let poster = MockOutboxPoster()
        let monitor = MockNetworkMonitor()
        outbox.startAutoFlush(monitor: monitor, posterProvider: { poster })
        await monitor.simulateOnline()

        // The badge clears reactively and the synthetic pending row is reconciled away.
        XCTAssertEqual(poster.received.count, 1)
        XCTAssertEqual(outbox.pendingCount, 0)
        XCTAssertEqual(viewModel.pendingUploadCount, 0)
        XCTAssertFalse(viewModel.todayEntries.contains { $0.isPending })
    }
}
