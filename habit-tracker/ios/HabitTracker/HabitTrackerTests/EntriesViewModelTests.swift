// [review:need-review] PHASE-01/08-ios-entries-crud
// summary: unit tests for EntriesViewModel — load, category filter, date grouping, edit (typo fix + failure keeps form), delete
import XCTest
@testable import HabitTracker

/// Scriptable stand-in for the API used by `EntriesViewModel`.
final class MockEntriesAPI: EntriesAPI {
    var categoriesResult: Result<[CategoryDTO], Error> = .success([])
    var entriesResult: Result<[EntryDTO], Error> = .success([])
    var updateResult: Result<EntryDTO, Error>?
    var deleteResult: Result<Void, Error> = .success(())
    private(set) var fetchedCategoryFilters: [Int?] = []
    private(set) var updatedPayloads: [(id: Int, payload: EntryUpdateDTO)] = []
    private(set) var deletedIDs: [Int] = []

    func fetchCategories() async throws -> [CategoryDTO] {
        try categoriesResult.get()
    }

    func fetchEntries(categoryId: Int?) async throws -> [EntryDTO] {
        fetchedCategoryFilters.append(categoryId)
        return try entriesResult.get()
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
final class EntriesViewModelTests: XCTestCase {
    private func makeCategory(id: Int, name: String, fields: [FieldDTO] = []) -> CategoryDTO {
        CategoryDTO(
            id: id,
            name: name,
            icon: nil,
            color: nil,
            displayMode: "form",
            isActive: true,
            fields: fields
        )
    }

    private func makeField(id: Int, name: String) -> FieldDTO {
        FieldDTO(
            id: id,
            name: name,
            fieldType: .number,
            isRequired: false,
            defaultValue: nil,
            options: nil,
            order: 0
        )
    }

    private func makeEntry(
        id: Int, categoryId: Int, date: String, notes: String? = nil, values: [EntryValueDTO]
    ) -> EntryDTO {
        EntryDTO(id: id, categoryId: categoryId, entryDate: date, notes: notes, values: values)
    }

    // MARK: - Load

    func testLoadPopulatesEntriesAndCategories() async {
        let api = MockEntriesAPI()
        api.categoriesResult = .success([makeCategory(id: 1, name: "Отжимания")])
        api.entriesResult = .success([
            makeEntry(id: 100, categoryId: 1, date: "2026-07-20",
                      values: [EntryValueDTO(fieldId: 10, value: "42")]),
        ])

        let viewModel = EntriesViewModel(api: api)
        await viewModel.load()

        XCTAssertEqual(viewModel.state, .loaded)
        XCTAssertEqual(viewModel.entries.map(\.id), [100])
        XCTAssertEqual(viewModel.categories.map(\.name), ["Отжимания"])
    }

    func testLoadFailureSetsFailureMessage() async {
        let api = MockEntriesAPI()
        api.categoriesResult = .failure(APIClientError.timeout)

        let viewModel = EntriesViewModel(api: api)
        await viewModel.load()

        guard case .failure(let message) = viewModel.state else {
            return XCTFail("Expected failure state, got \(viewModel.state)")
        }
        XCTAssertFalse(message.isEmpty)
    }

    // MARK: - Category filter

    func testFilteredEntriesRespectsSelectedCategory() async {
        let api = MockEntriesAPI()
        api.categoriesResult = .success([
            makeCategory(id: 1, name: "Отжимания"),
            makeCategory(id: 2, name: "Сон"),
        ])
        api.entriesResult = .success([
            makeEntry(id: 100, categoryId: 1, date: "2026-07-20",
                      values: [EntryValueDTO(fieldId: 10, value: "42")]),
            makeEntry(id: 200, categoryId: 2, date: "2026-07-20",
                      values: [EntryValueDTO(fieldId: 20, value: "8")]),
        ])

        let viewModel = EntriesViewModel(api: api)
        await viewModel.load()
        viewModel.selectedCategoryId = 1

        XCTAssertEqual(viewModel.filteredEntries.map(\.id), [100])
    }

    func testNilFilterReturnsAllEntries() async {
        let api = MockEntriesAPI()
        api.entriesResult = .success([
            makeEntry(id: 100, categoryId: 1, date: "2026-07-20",
                      values: [EntryValueDTO(fieldId: 10, value: "42")]),
            makeEntry(id: 200, categoryId: 2, date: "2026-07-20",
                      values: [EntryValueDTO(fieldId: 20, value: "8")]),
        ])

        let viewModel = EntriesViewModel(api: api)
        await viewModel.load()

        XCTAssertNil(viewModel.selectedCategoryId)
        XCTAssertEqual(viewModel.filteredEntries.map(\.id), [100, 200])
    }

    // MARK: - Date grouping

    func testGroupedByDateSortsDaysDescending() async {
        let api = MockEntriesAPI()
        api.entriesResult = .success([
            makeEntry(id: 1, categoryId: 1, date: "2026-07-18",
                      values: [EntryValueDTO(fieldId: 10, value: "1")]),
            makeEntry(id: 2, categoryId: 1, date: "2026-07-20",
                      values: [EntryValueDTO(fieldId: 10, value: "2")]),
            makeEntry(id: 3, categoryId: 1, date: "2026-07-20",
                      values: [EntryValueDTO(fieldId: 10, value: "3")]),
        ])

        let viewModel = EntriesViewModel(api: api)
        await viewModel.load()

        let groups = viewModel.groupedByDate
        XCTAssertEqual(groups.map(\.date), ["2026-07-20", "2026-07-18"])
        XCTAssertEqual(groups.first?.entries.map(\.id), [2, 3])
    }

    // MARK: - Edit (acceptance: fix "422 отжимания" typo to 42)

    func testEditFixesTypoAndUpdatesList() async {
        let api = MockEntriesAPI()
        let original = makeEntry(id: 100, categoryId: 1, date: "2026-07-20",
                                 values: [EntryValueDTO(fieldId: 10, value: "422")])
        api.entriesResult = .success([original])
        let corrected = makeEntry(id: 100, categoryId: 1, date: "2026-07-20",
                                  values: [EntryValueDTO(fieldId: 10, value: "42")])
        api.updateResult = .success(corrected)

        let viewModel = EntriesViewModel(api: api)
        await viewModel.load()
        viewModel.beginEditing(original)
        viewModel.editDraft?.values[10] = "42"
        let ok = await viewModel.saveEdit()

        XCTAssertTrue(ok)
        XCTAssertEqual(api.updatedPayloads.count, 1)
        XCTAssertEqual(api.updatedPayloads[0].id, 100)
        XCTAssertEqual(api.updatedPayloads[0].payload.values, [EntryValueDTO(fieldId: 10, value: "42")])
        XCTAssertEqual(
            viewModel.entries.first { $0.id == 100 }?.values.first?.value, "42"
        )
        XCTAssertNil(viewModel.editDraft)
        XCTAssertNil(viewModel.saveErrorMessage)
    }

    func testEditEditsNotes() async {
        let api = MockEntriesAPI()
        let original = makeEntry(id: 100, categoryId: 1, date: "2026-07-20", notes: "old",
                                 values: [EntryValueDTO(fieldId: 10, value: "42")])
        api.entriesResult = .success([original])
        api.updateResult = .success(original)

        let viewModel = EntriesViewModel(api: api)
        await viewModel.load()
        viewModel.beginEditing(original)
        viewModel.editDraft?.notes = "new note"
        _ = await viewModel.saveEdit()

        XCTAssertEqual(api.updatedPayloads[0].payload.notes, "new note")
    }

    // MARK: - Edit failure keeps the form data (network error must not lose input)

    func testEditFailureKeepsDraftAndListUnchanged() async {
        let api = MockEntriesAPI()
        let original = makeEntry(id: 100, categoryId: 1, date: "2026-07-20",
                                 values: [EntryValueDTO(fieldId: 10, value: "422")])
        api.entriesResult = .success([original])
        api.updateResult = .failure(APIClientError.timeout)

        let viewModel = EntriesViewModel(api: api)
        await viewModel.load()
        viewModel.beginEditing(original)
        viewModel.editDraft?.values[10] = "42"
        let ok = await viewModel.saveEdit()

        XCTAssertFalse(ok)
        XCTAssertNotNil(viewModel.saveErrorMessage)
        // Form data preserved: the draft still holds the user's correction.
        XCTAssertEqual(viewModel.editDraft?.values[10], "42")
        // List is unchanged — the stored entry keeps its original value.
        XCTAssertEqual(viewModel.entries.first { $0.id == 100 }?.values.first?.value, "422")
    }

    // MARK: - Delete

    func testDeleteRemovesEntryFromList() async {
        let api = MockEntriesAPI()
        api.entriesResult = .success([
            makeEntry(id: 100, categoryId: 1, date: "2026-07-20",
                      values: [EntryValueDTO(fieldId: 10, value: "42")]),
            makeEntry(id: 200, categoryId: 1, date: "2026-07-19",
                      values: [EntryValueDTO(fieldId: 10, value: "30")]),
        ])

        let viewModel = EntriesViewModel(api: api)
        await viewModel.load()
        let ok = await viewModel.deleteEntry(id: 100)

        XCTAssertTrue(ok)
        XCTAssertEqual(api.deletedIDs, [100])
        XCTAssertEqual(viewModel.entries.map(\.id), [200])
    }

    func testDeleteFailureKeepsEntryAndSetsError() async {
        let api = MockEntriesAPI()
        api.entriesResult = .success([
            makeEntry(id: 100, categoryId: 1, date: "2026-07-20",
                      values: [EntryValueDTO(fieldId: 10, value: "42")]),
        ])
        api.deleteResult = .failure(APIClientError.unexpectedStatus(500))

        let viewModel = EntriesViewModel(api: api)
        await viewModel.load()
        let ok = await viewModel.deleteEntry(id: 100)

        XCTAssertFalse(ok)
        XCTAssertEqual(viewModel.entries.map(\.id), [100])
        XCTAssertNotNil(viewModel.saveErrorMessage)
    }
}
