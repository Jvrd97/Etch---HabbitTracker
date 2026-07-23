// [review:need-review] PHASE-01/05-ios-today-quick-entry
// summary: unit tests for TodayViewModel — load, save success/failure, checklist upsert routing
import XCTest
@testable import HabitTracker

/// Scriptable stand-in for the API used by `TodayViewModel`.
final class MockTodayAPI: TodayAPI {
    var categoriesResult: Result<[CategoryDTO], Error> = .success([])
    var entriesResult: Result<[EntryDTO], Error> = .success([])
    var createEntryResult: Result<EntryDTO, Error>?
    var upsertChecklistResult: Result<EntryDTO, Error>?
    private(set) var fetchedEntryRanges: [(start: String, end: String)] = []
    private(set) var createdEntries: [EntryCreateDTO] = []
    private(set) var upsertedChecklists: [ChecklistUpsertDTO] = []

    func fetchCategories() async throws -> [CategoryDTO] {
        try categoriesResult.get()
    }

    func fetchEntries(startDate: String, endDate: String) async throws -> [EntryDTO] {
        fetchedEntryRanges.append((start: startDate, end: endDate))
        return try entriesResult.get()
    }

    func createEntry(_ entry: EntryCreateDTO) async throws -> EntryDTO {
        createdEntries.append(entry)
        guard let result = createEntryResult else {
            throw APIClientError.invalidResponse
        }
        return try result.get()
    }

    func upsertChecklistEntry(_ payload: ChecklistUpsertDTO) async throws -> EntryDTO {
        upsertedChecklists.append(payload)
        guard let result = upsertChecklistResult else {
            throw APIClientError.invalidResponse
        }
        return try result.get()
    }
}

@MainActor
final class TodayViewModelTests: XCTestCase {
    private static let fixedToday = "2026-07-23"

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

    private func makeViewModel(api: MockTodayAPI) -> TodayViewModel {
        let fixed = makeFixedDate()
        return TodayViewModel(api: api, timeZone: TimeZone(identifier: "UTC")!, now: { fixed })
    }

    private func makeCategory(
        id: Int, name: String, fields: [FieldDTO], displayMode: String = "form"
    ) -> CategoryDTO {
        CategoryDTO(
            id: id,
            name: name,
            icon: nil,
            color: nil,
            displayMode: displayMode,
            isActive: true,
            fields: fields
        )
    }

    private func makeNumberField(id: Int, name: String) -> FieldDTO {
        FieldDTO(
            id: id,
            name: name,
            fieldType: .number,
            isRequired: true,
            defaultValue: nil,
            options: nil,
            order: 0
        )
    }

    private func makeBooleanField(id: Int, name: String) -> FieldDTO {
        FieldDTO(
            id: id,
            name: name,
            fieldType: .boolean,
            isRequired: false,
            defaultValue: nil,
            options: nil,
            order: 0
        )
    }

    func testLoadSuccessPopulatesCategoriesAndTodayEntries() async {
        let api = MockTodayAPI()
        let pushups = makeCategory(
            id: 1, name: "Pushups", fields: [makeNumberField(id: 10, name: "Count")]
        )
        api.categoriesResult = .success([pushups])
        api.entriesResult = .success([
            EntryDTO(
                id: 100,
                categoryId: 1,
                entryDate: Self.fixedToday,
                values: [EntryValueDTO(fieldId: 10, value: "42")]
            )
        ])

        let viewModel = makeViewModel(api: api)
        await viewModel.load()

        XCTAssertEqual(viewModel.state, .loaded)
        XCTAssertEqual(viewModel.categories.map(\.id), [1])
        XCTAssertEqual(viewModel.entries(forCategory: 1).count, 1)
        XCTAssertEqual(api.fetchedEntryRanges.count, 1)
        XCTAssertEqual(api.fetchedEntryRanges.first?.start, Self.fixedToday)
        XCTAssertEqual(api.fetchedEntryRanges.first?.end, Self.fixedToday)
    }

    func testSaveEntryPostsTodayPayloadAndAppendsEntry() async {
        let api = MockTodayAPI()
        let created = EntryDTO(
            id: 101,
            categoryId: 1,
            entryDate: Self.fixedToday,
            values: [EntryValueDTO(fieldId: 10, value: "42")]
        )
        api.createEntryResult = .success(created)

        let viewModel = makeViewModel(api: api)
        let saved = await viewModel.saveEntry(categoryID: 1, values: [10: "42"])

        XCTAssertTrue(saved)
        XCTAssertEqual(api.createdEntries.count, 1)
        let payload = api.createdEntries[0]
        XCTAssertEqual(payload.categoryId, 1)
        XCTAssertEqual(payload.entryDate, Self.fixedToday)
        XCTAssertEqual(payload.values, [EntryValueDTO(fieldId: 10, value: "42")])
        XCTAssertEqual(viewModel.entries(forCategory: 1), [created])
        XCTAssertNil(viewModel.saveErrorMessage)
    }

    func testSaveEntryFailureSetsErrorMessageAndReturnsFalse() async {
        let api = MockTodayAPI()
        api.createEntryResult = .failure(APIClientError.unauthorized)

        let viewModel = makeViewModel(api: api)
        let saved = await viewModel.saveEntry(categoryID: 1, values: [10: "42"])

        XCTAssertFalse(saved)
        XCTAssertEqual(viewModel.saveErrorMessage, "Invalid API key (401)")
        XCTAssertTrue(viewModel.entries(forCategory: 1).isEmpty)
    }

    func testSaveEntryChecklistCategoryUsesIdempotentUpsertNotPost() async {
        let api = MockTodayAPI()
        let checklist = makeCategory(
            id: 2,
            name: "Morning routine",
            fields: [makeBooleanField(id: 20, name: "Meditate")],
            displayMode: "checklist"
        )
        api.categoriesResult = .success([checklist])
        let upserted = EntryDTO(
            id: 200,
            categoryId: 2,
            entryDate: Self.fixedToday,
            values: [EntryValueDTO(fieldId: 20, value: "true")]
        )
        api.upsertChecklistResult = .success(upserted)

        let viewModel = makeViewModel(api: api)
        await viewModel.load()
        let saved = await viewModel.saveEntry(categoryID: 2, values: [20: "true"])

        XCTAssertTrue(saved)
        XCTAssertTrue(api.createdEntries.isEmpty, "checklist must not use generic POST")
        XCTAssertEqual(api.upsertedChecklists.count, 1)
        let payload = api.upsertedChecklists[0]
        XCTAssertEqual(payload.categoryId, 2)
        XCTAssertEqual(payload.entryDate, Self.fixedToday)
        XCTAssertEqual(payload.values, ["20": true])
        XCTAssertEqual(viewModel.entries(forCategory: 2), [upserted])
    }

    func testSaveEntryChecklistUpsertReplacesExistingEntryInsteadOfDuplicating() async {
        let api = MockTodayAPI()
        let checklist = makeCategory(
            id: 2,
            name: "Morning routine",
            fields: [makeBooleanField(id: 20, name: "Meditate")],
            displayMode: "checklist"
        )
        api.categoriesResult = .success([checklist])
        api.upsertChecklistResult = .success(
            EntryDTO(
                id: 200,
                categoryId: 2,
                entryDate: Self.fixedToday,
                values: [EntryValueDTO(fieldId: 20, value: "false")]
            )
        )

        let viewModel = makeViewModel(api: api)
        await viewModel.load()
        _ = await viewModel.saveEntry(categoryID: 2, values: [20: "false"])
        let updated = EntryDTO(
            id: 200,
            categoryId: 2,
            entryDate: Self.fixedToday,
            values: [EntryValueDTO(fieldId: 20, value: "true")]
        )
        api.upsertChecklistResult = .success(updated)
        _ = await viewModel.saveEntry(categoryID: 2, values: [20: "true"])

        XCTAssertEqual(api.upsertedChecklists.count, 2)
        XCTAssertEqual(viewModel.entries(forCategory: 2), [updated])
    }

    func testLoadFailureSetsFailureMessageWithoutCrash() async {
        let api = MockTodayAPI()
        api.categoriesResult = .failure(APIClientError.timeout)

        let viewModel = makeViewModel(api: api)
        await viewModel.load()

        guard case .failure(let message) = viewModel.state else {
            return XCTFail("Expected failure state, got \(viewModel.state)")
        }
        XCTAssertFalse(message.isEmpty)
    }
}
