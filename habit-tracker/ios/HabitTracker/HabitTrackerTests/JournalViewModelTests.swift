// [review:need-review] PHASE-01/09-ios-journal
// summary: unit tests for JournalViewModel — load, create with mood + tag parsing, empty-content guard, failure keeps draft, delete
import XCTest
@testable import HabitTracker

/// Scriptable stand-in for the API used by `JournalViewModel`.
final class MockJournalAPI: JournalAPI {
    var entriesResult: Result<[JournalEntryDTO], Error> = .success([])
    var createResult: Result<JournalEntryDTO, Error>?
    var deleteResult: Result<Void, Error> = .success(())
    private(set) var createdPayloads: [JournalEntryCreateDTO] = []
    private(set) var deletedIDs: [Int] = []

    func fetchJournalEntries() async throws -> [JournalEntryDTO] {
        try entriesResult.get()
    }

    func createJournalEntry(_ payload: JournalEntryCreateDTO) async throws -> JournalEntryDTO {
        createdPayloads.append(payload)
        guard let result = createResult else { throw APIClientError.invalidResponse }
        return try result.get()
    }

    func updateJournalEntry(
        id: Int, _ payload: JournalEntryUpdateDTO
    ) async throws -> JournalEntryDTO {
        throw APIClientError.invalidResponse
    }

    func deleteJournalEntry(id: Int) async throws {
        deletedIDs.append(id)
        try deleteResult.get()
    }
}

@MainActor
final class JournalViewModelTests: XCTestCase {
    private func makeEntry(
        id: Int,
        title: String? = nil,
        content: String,
        date: String,
        mood: String? = nil,
        tags: String? = nil
    ) -> JournalEntryDTO {
        JournalEntryDTO(
            id: id,
            title: title,
            content: content,
            entryDate: date,
            mood: mood,
            tags: tags,
            createdAt: "2026-07-20T10:00:00",
            updatedAt: "2026-07-20T10:00:00"
        )
    }

    // MARK: - Tag parsing (pure helper)

    func testTagParsingTrimsAndDropsEmpties() {
        let parsed = JournalTags.parse("работа, достижения ,, проект ")
        XCTAssertEqual(parsed, ["работа", "достижения", "проект"])
    }

    func testTagNormalizeJoinsWithComma() {
        XCTAssertEqual(JournalTags.normalize("  a , b ,c "), "a,b,c")
    }

    func testTagNormalizeReturnsNilWhenEffectivelyEmpty() {
        XCTAssertNil(JournalTags.normalize("  ,, "))
        XCTAssertNil(JournalTags.normalize(""))
    }

    // MARK: - Load

    func testLoadPopulatesEntries() async {
        let api = MockJournalAPI()
        api.entriesResult = .success([
            makeEntry(id: 1, content: "как прошёл день", date: "2026-07-20", mood: "happy"),
        ])

        let viewModel = JournalViewModel(api: api)
        await viewModel.load()

        XCTAssertEqual(viewModel.state, .loaded)
        XCTAssertEqual(viewModel.entries.map(\.id), [1])
    }

    func testLoadFailureSetsFailureMessage() async {
        let api = MockJournalAPI()
        api.entriesResult = .failure(APIClientError.timeout)

        let viewModel = JournalViewModel(api: api)
        await viewModel.load()

        guard case .failure(let message) = viewModel.state else {
            return XCTFail("Expected failure state, got \(viewModel.state)")
        }
        XCTAssertFalse(message.isEmpty)
    }

    // MARK: - Create (acceptance: "как прошёл день" with mood is created from the phone)

    func testCreateEntryWithMoodAndTagsSendsNormalizedPayload() async {
        let api = MockJournalAPI()
        let created = makeEntry(
            id: 42,
            title: "Отличный день",
            content: "Сегодня был продуктивный день",
            date: "2026-07-21",
            mood: "happy",
            tags: "работа,достижения"
        )
        api.createResult = .success(created)

        let viewModel = JournalViewModel(api: api)
        viewModel.draftTitle = "Отличный день"
        viewModel.draftContent = "Сегодня был продуктивный день"
        viewModel.draftDate = "2026-07-21"
        viewModel.draftMood = "happy"
        viewModel.draftTags = " работа , достижения ,"
        let ok = await viewModel.createEntry()

        XCTAssertTrue(ok)
        XCTAssertEqual(api.createdPayloads.count, 1)
        let payload = api.createdPayloads[0]
        XCTAssertEqual(payload.title, "Отличный день")
        XCTAssertEqual(payload.content, "Сегодня был продуктивный день")
        XCTAssertEqual(payload.entryDate, "2026-07-21")
        XCTAssertEqual(payload.mood, "happy")
        XCTAssertEqual(payload.tags, "работа,достижения")
        // New entry appears at the top of the feed.
        XCTAssertEqual(viewModel.entries.first?.id, 42)
        XCTAssertNil(viewModel.saveErrorMessage)
    }

    func testCreateEntryOmitsBlankOptionalFields() async {
        let api = MockJournalAPI()
        api.createResult = .success(
            makeEntry(id: 7, content: "просто заметка", date: "2026-07-21")
        )

        let viewModel = JournalViewModel(api: api)
        viewModel.draftContent = "просто заметка"
        viewModel.draftDate = "2026-07-21"
        viewModel.draftTitle = "   "
        viewModel.draftTags = "   "
        let ok = await viewModel.createEntry()

        XCTAssertTrue(ok)
        let payload = api.createdPayloads[0]
        XCTAssertNil(payload.title)
        XCTAssertNil(payload.tags)
        XCTAssertNil(payload.mood)
    }

    func testCreateEmptyContentFailsWithoutHittingAPI() async {
        let api = MockJournalAPI()

        let viewModel = JournalViewModel(api: api)
        viewModel.draftContent = "   "
        let ok = await viewModel.createEntry()

        XCTAssertFalse(ok)
        XCTAssertTrue(api.createdPayloads.isEmpty)
        XCTAssertNotNil(viewModel.saveErrorMessage)
    }

    func testCreateFailureKeepsDraftAndSetsError() async {
        let api = MockJournalAPI()
        api.createResult = .failure(APIClientError.timeout)

        let viewModel = JournalViewModel(api: api)
        viewModel.draftContent = "как прошёл день"
        viewModel.draftDate = "2026-07-21"
        let ok = await viewModel.createEntry()

        XCTAssertFalse(ok)
        XCTAssertNotNil(viewModel.saveErrorMessage)
        // Draft is preserved so the user's text survives a network error.
        XCTAssertEqual(viewModel.draftContent, "как прошёл день")
        XCTAssertTrue(viewModel.entries.isEmpty)
    }

    // MARK: - Delete

    func testDeleteRemovesEntryFromFeed() async {
        let api = MockJournalAPI()
        api.entriesResult = .success([
            makeEntry(id: 1, content: "a", date: "2026-07-20"),
            makeEntry(id: 2, content: "b", date: "2026-07-19"),
        ])

        let viewModel = JournalViewModel(api: api)
        await viewModel.load()
        let ok = await viewModel.deleteEntry(id: 1)

        XCTAssertTrue(ok)
        XCTAssertEqual(api.deletedIDs, [1])
        XCTAssertEqual(viewModel.entries.map(\.id), [2])
    }

    func testDeleteFailureKeepsEntryAndSetsError() async {
        let api = MockJournalAPI()
        api.entriesResult = .success([
            makeEntry(id: 1, content: "a", date: "2026-07-20"),
        ])
        api.deleteResult = .failure(APIClientError.unexpectedStatus(500))

        let viewModel = JournalViewModel(api: api)
        await viewModel.load()
        let ok = await viewModel.deleteEntry(id: 1)

        XCTAssertFalse(ok)
        XCTAssertEqual(viewModel.entries.map(\.id), [1])
        XCTAssertNotNil(viewModel.saveErrorMessage)
    }
}
