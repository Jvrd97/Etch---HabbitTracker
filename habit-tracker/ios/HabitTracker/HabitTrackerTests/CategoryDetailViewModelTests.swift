// [review:need-review] PHASE-01/35-ios-category-detail
// summary: unit tests for CategoryDetailViewModel — load by category, date grouping, quick-add payload, edit/delete mutation
import XCTest
@testable import HabitTracker

/// Scriptable stand-in for the API used by `CategoryDetailViewModel`.
final class MockCategoryDetailAPI: CategoryDetailAPI {
    var entriesResult: Result<[EntryDTO], Error> = .success([])
    var createResult: Result<EntryDTO, Error>?
    var updateResult: Result<EntryDTO, Error>?
    var deleteResult: Result<Void, Error> = .success(())
    private(set) var fetchedCategoryFilters: [Int?] = []
    private(set) var createdPayloads: [EntryCreateDTO] = []
    private(set) var updatedPayloads: [(id: Int, payload: EntryUpdateDTO)] = []
    private(set) var deletedIDs: [Int] = []

    func fetchEntries(categoryId: Int?) async throws -> [EntryDTO] {
        fetchedCategoryFilters.append(categoryId)
        return try entriesResult.get()
    }

    func createEntry(_ entry: EntryCreateDTO) async throws -> EntryDTO {
        createdPayloads.append(entry)
        guard let result = createResult else { throw APIClientError.invalidResponse }
        return try result.get()
    }

    func updateEntry(id: Int, _ payload: EntryUpdateDTO) async throws -> EntryDTO {
        updatedPayloads.append((id: id, payload: payload))
        guard let result = updateResult else { throw APIClientError.invalidResponse }
        return try result.get()
    }

    func deleteEntry(id: Int) async throws {
        deletedIDs.append(id)
        try deleteResult.get()
    }
}

@MainActor
final class CategoryDetailViewModelTests: XCTestCase {
    private let fixedDate = "2026-07-21"

    private func makeField(id: Int, name: String, order: Int) -> FieldDTO {
        FieldDTO(
            id: id,
            name: name,
            fieldType: .number,
            isRequired: false,
            defaultValue: nil,
            options: nil,
            order: order
        )
    }

    private func makeCategory(id: Int, name: String, fields: [FieldDTO]) -> CategoryDTO {
        CategoryDTO(
            id: id,
            name: name,
            icon: nil,
            color: "#B8FF36",
            displayMode: "form",
            isActive: true,
            fields: fields
        )
    }

    private func makeEntry(
        id: Int, categoryId: Int, date: String, values: [EntryValueDTO]
    ) -> EntryDTO {
        EntryDTO(id: id, categoryId: categoryId, entryDate: date, values: values)
    }

    private func makeViewModel(
        category: CategoryDTO, api: CategoryDetailAPI
    ) -> CategoryDetailViewModel {
        CategoryDetailViewModel(
            category: category,
            api: api,
            timeZone: TimeZone(identifier: "UTC")!,
            now: { self.date(from: self.fixedDate) }
        )
    }

    private func date(from string: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)!
    }

    // MARK: - Load

    func testLoadFetchesEntriesForThisCategoryOnly() async {
        let category = makeCategory(
            id: 1, name: "Push-ups", fields: [makeField(id: 10, name: "Reps", order: 0)]
        )
        let api = MockCategoryDetailAPI()
        api.entriesResult = .success([
            makeEntry(id: 100, categoryId: 1, date: "2026-07-20",
                      values: [EntryValueDTO(fieldId: 10, value: "42")]),
        ])

        let viewModel = makeViewModel(category: category, api: api)
        await viewModel.load()

        XCTAssertEqual(viewModel.state, .loaded)
        XCTAssertEqual(api.fetchedCategoryFilters, [1])
        XCTAssertEqual(viewModel.entries.map(\.id), [100])
    }

    func testLoadFailureSetsFailureMessage() async {
        let category = makeCategory(id: 1, name: "Push-ups", fields: [])
        let api = MockCategoryDetailAPI()
        api.entriesResult = .failure(APIClientError.timeout)

        let viewModel = makeViewModel(category: category, api: api)
        await viewModel.load()

        guard case .failure(let message) = viewModel.state else {
            return XCTFail("Expected failure state, got \(viewModel.state)")
        }
        XCTAssertFalse(message.isEmpty)
    }

    // MARK: - Date grouping

    func testGroupedByDateSortsDaysDescending() async {
        let category = makeCategory(
            id: 1, name: "Push-ups", fields: [makeField(id: 10, name: "Reps", order: 0)]
        )
        let api = MockCategoryDetailAPI()
        api.entriesResult = .success([
            makeEntry(id: 1, categoryId: 1, date: "2026-07-18",
                      values: [EntryValueDTO(fieldId: 10, value: "1")]),
            makeEntry(id: 2, categoryId: 1, date: "2026-07-20",
                      values: [EntryValueDTO(fieldId: 10, value: "2")]),
            makeEntry(id: 3, categoryId: 1, date: "2026-07-20",
                      values: [EntryValueDTO(fieldId: 10, value: "3")]),
        ])

        let viewModel = makeViewModel(category: category, api: api)
        await viewModel.load()

        let groups = viewModel.groupedByDate
        XCTAssertEqual(groups.map(\.date), ["2026-07-20", "2026-07-18"])
        XCTAssertEqual(groups.first?.entries.map(\.id), [2, 3])
    }

    // MARK: - Quick-add (acceptance: quick-add value of the first field)

    func testQuickAddFieldIsFirstFieldByOrder() {
        let category = makeCategory(
            id: 1,
            name: "Push-ups",
            fields: [
                makeField(id: 20, name: "Notes field", order: 1),
                makeField(id: 10, name: "Reps", order: 0),
            ]
        )
        let viewModel = makeViewModel(category: category, api: MockCategoryDetailAPI())

        XCTAssertEqual(viewModel.quickAddField?.id, 10)
    }

    func testQuickAddSendsPayloadWithFirstFieldAndInsertsEntry() async {
        let category = makeCategory(
            id: 1, name: "Push-ups", fields: [makeField(id: 10, name: "Reps", order: 0)]
        )
        let api = MockCategoryDetailAPI()
        api.entriesResult = .success([])
        let created = makeEntry(id: 500, categoryId: 1, date: fixedDate,
                                values: [EntryValueDTO(fieldId: 10, value: "42")])
        api.createResult = .success(created)

        let viewModel = makeViewModel(category: category, api: api)
        await viewModel.load()
        viewModel.quickAddValue = "42"
        let ok = await viewModel.quickAdd()

        XCTAssertTrue(ok)
        XCTAssertEqual(api.createdPayloads.count, 1)
        let payload = api.createdPayloads[0]
        XCTAssertEqual(payload.categoryId, 1)
        XCTAssertEqual(payload.entryDate, fixedDate)
        XCTAssertEqual(payload.values, [EntryValueDTO(fieldId: 10, value: "42")])
        // New entry appears in the list without a reload.
        XCTAssertEqual(viewModel.entries.map(\.id), [500])
        // Input is cleared after a successful quick-add.
        XCTAssertEqual(viewModel.quickAddValue, "")
        XCTAssertNil(viewModel.saveErrorMessage)
    }

    func testQuickAddBlankValueDoesNotCallAPI() async {
        let category = makeCategory(
            id: 1, name: "Push-ups", fields: [makeField(id: 10, name: "Reps", order: 0)]
        )
        let api = MockCategoryDetailAPI()

        let viewModel = makeViewModel(category: category, api: api)
        viewModel.quickAddValue = "   "
        let ok = await viewModel.quickAdd()

        XCTAssertFalse(ok)
        XCTAssertTrue(api.createdPayloads.isEmpty)
    }

    func testQuickAddFailureKeepsValueAndSetsError() async {
        let category = makeCategory(
            id: 1, name: "Push-ups", fields: [makeField(id: 10, name: "Reps", order: 0)]
        )
        let api = MockCategoryDetailAPI()
        api.createResult = .failure(APIClientError.unexpectedStatus(500))

        let viewModel = makeViewModel(category: category, api: api)
        viewModel.quickAddValue = "42"
        let ok = await viewModel.quickAdd()

        XCTAssertFalse(ok)
        XCTAssertEqual(viewModel.quickAddValue, "42")
        XCTAssertNotNil(viewModel.saveErrorMessage)
        XCTAssertTrue(viewModel.entries.isEmpty)
    }

    // MARK: - Edit

    func testEditUpdatesEntryInList() async {
        let category = makeCategory(
            id: 1, name: "Push-ups", fields: [makeField(id: 10, name: "Reps", order: 0)]
        )
        let api = MockCategoryDetailAPI()
        let original = makeEntry(id: 100, categoryId: 1, date: "2026-07-20",
                                 values: [EntryValueDTO(fieldId: 10, value: "422")])
        api.entriesResult = .success([original])
        let corrected = makeEntry(id: 100, categoryId: 1, date: "2026-07-20",
                                  values: [EntryValueDTO(fieldId: 10, value: "42")])
        api.updateResult = .success(corrected)

        let viewModel = makeViewModel(category: category, api: api)
        await viewModel.load()
        viewModel.beginEditing(original)
        viewModel.editDraft?.values[10] = "42"
        let ok = await viewModel.saveEdit()

        XCTAssertTrue(ok)
        XCTAssertEqual(api.updatedPayloads.first?.id, 100)
        XCTAssertEqual(viewModel.entries.first { $0.id == 100 }?.values.first?.value, "42")
        XCTAssertNil(viewModel.editDraft)
    }

    // MARK: - Delete

    func testDeleteRemovesEntryFromList() async {
        let category = makeCategory(
            id: 1, name: "Push-ups", fields: [makeField(id: 10, name: "Reps", order: 0)]
        )
        let api = MockCategoryDetailAPI()
        api.entriesResult = .success([
            makeEntry(id: 100, categoryId: 1, date: "2026-07-20",
                      values: [EntryValueDTO(fieldId: 10, value: "42")]),
            makeEntry(id: 200, categoryId: 1, date: "2026-07-19",
                      values: [EntryValueDTO(fieldId: 10, value: "30")]),
        ])

        let viewModel = makeViewModel(category: category, api: api)
        await viewModel.load()
        let ok = await viewModel.deleteEditEntry(id: 100)

        XCTAssertTrue(ok)
        XCTAssertEqual(api.deletedIDs, [100])
        XCTAssertEqual(viewModel.entries.map(\.id), [200])
    }

    func testDeleteFailureKeepsEntryAndSetsError() async {
        let category = makeCategory(
            id: 1, name: "Push-ups", fields: [makeField(id: 10, name: "Reps", order: 0)]
        )
        let api = MockCategoryDetailAPI()
        api.entriesResult = .success([
            makeEntry(id: 100, categoryId: 1, date: "2026-07-20",
                      values: [EntryValueDTO(fieldId: 10, value: "42")]),
        ])
        api.deleteResult = .failure(APIClientError.unexpectedStatus(500))

        let viewModel = makeViewModel(category: category, api: api)
        await viewModel.load()
        let ok = await viewModel.deleteEditEntry(id: 100)

        XCTAssertFalse(ok)
        XCTAssertEqual(viewModel.entries.map(\.id), [100])
        XCTAssertNotNil(viewModel.saveErrorMessage)
    }
}
