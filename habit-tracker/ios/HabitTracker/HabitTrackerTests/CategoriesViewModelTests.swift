// [review:need-review] PHASE-01/07-ios-categories-crud
// summary: unit tests for CategoriesViewModel — load, validation (empty name, select w/o options), create/update/delete
import XCTest
@testable import HabitTracker

/// Scriptable stand-in for the API used by `CategoriesViewModel`.
final class MockCategoriesAPI: CategoriesAPI {
    var categoriesResult: Result<[CategoryDTO], Error> = .success([])
    var createResult: Result<CategoryDTO, Error>?
    var updateResult: Result<CategoryDTO, Error>?
    var deleteResult: Result<Void, Error> = .success(())
    var addFieldResult: Result<FieldDTO, Error>?
    private(set) var createdPayloads: [CategoryCreateDTO] = []
    private(set) var updatedPayloads: [(id: Int, payload: CategoryUpdateDTO)] = []
    private(set) var deletedIDs: [Int] = []
    private(set) var addedFields: [(categoryID: Int, payload: FieldCreateDTO)] = []

    func fetchCategories() async throws -> [CategoryDTO] {
        try categoriesResult.get()
    }

    func createCategory(_ payload: CategoryCreateDTO) async throws -> CategoryDTO {
        createdPayloads.append(payload)
        guard let result = createResult else { throw APIClientError.invalidResponse }
        return try result.get()
    }

    func updateCategory(id: Int, _ payload: CategoryUpdateDTO) async throws -> CategoryDTO {
        updatedPayloads.append((id: id, payload: payload))
        guard let result = updateResult else { throw APIClientError.invalidResponse }
        return try result.get()
    }

    func deleteCategory(id: Int) async throws {
        deletedIDs.append(id)
        try deleteResult.get()
    }

    func addField(categoryID: Int, _ payload: FieldCreateDTO) async throws -> FieldDTO {
        addedFields.append((categoryID: categoryID, payload: payload))
        guard let result = addFieldResult else { throw APIClientError.invalidResponse }
        return try result.get()
    }
}

@MainActor
final class CategoriesViewModelTests: XCTestCase {
    private func makeCategory(
        id: Int, name: String, color: String? = nil, fields: [FieldDTO] = []
    ) -> CategoryDTO {
        CategoryDTO(
            id: id,
            name: name,
            icon: nil,
            color: color,
            displayMode: "form",
            isActive: true,
            fields: fields
        )
    }

    private func makeFieldResponse(id: Int, name: String, type: FieldTypeDTO) -> FieldDTO {
        FieldDTO(
            id: id,
            name: name,
            fieldType: type,
            isRequired: false,
            defaultValue: nil,
            options: nil,
            order: 0
        )
    }

    // MARK: - Load

    func testLoadPopulatesCategories() async {
        let api = MockCategoriesAPI()
        api.categoriesResult = .success([makeCategory(id: 1, name: "Squats")])

        let viewModel = CategoriesViewModel(api: api)
        await viewModel.load()

        XCTAssertEqual(viewModel.state, .loaded)
        XCTAssertEqual(viewModel.categories.map(\.name), ["Squats"])
    }

    func testLoadFailureSetsFailureMessage() async {
        let api = MockCategoriesAPI()
        api.categoriesResult = .failure(APIClientError.timeout)

        let viewModel = CategoriesViewModel(api: api)
        await viewModel.load()

        guard case .failure(let message) = viewModel.state else {
            return XCTFail("Expected failure state, got \(viewModel.state)")
        }
        XCTAssertFalse(message.isEmpty)
    }

    // MARK: - Validation

    func testValidateRejectsEmptyName() {
        let api = MockCategoriesAPI()
        let viewModel = CategoriesViewModel(api: api)

        let errors = viewModel.validate(CategoryDraft(name: "   "))

        XCTAssertTrue(errors.contains(.emptyName))
    }

    func testValidateRejectsSelectFieldWithoutOptions() {
        let api = MockCategoriesAPI()
        let viewModel = CategoriesViewModel(api: api)
        let draft = CategoryDraft(
            name: "Mood",
            fields: [FieldDraft(name: "How", fieldType: .select, options: [" "])]
        )

        let errors = viewModel.validate(draft)

        XCTAssertTrue(errors.contains(.selectWithoutOptions(index: 0)))
    }

    func testValidateAcceptsSelectFieldWithOptions() {
        let api = MockCategoriesAPI()
        let viewModel = CategoriesViewModel(api: api)
        let draft = CategoryDraft(
            name: "Mood",
            fields: [FieldDraft(name: "How", fieldType: .select, options: ["good", "bad"])]
        )

        XCTAssertTrue(viewModel.validate(draft).isEmpty)
    }

    func testCreateInvalidDraftDoesNotCallAPIAndSetsError() async {
        let api = MockCategoriesAPI()
        let viewModel = CategoriesViewModel(api: api)

        let ok = await viewModel.createCategory(CategoryDraft(name: ""))

        XCTAssertFalse(ok)
        XCTAssertTrue(api.createdPayloads.isEmpty)
        XCTAssertEqual(viewModel.saveErrorMessage, CategoryValidationError.emptyName.message)
    }

    // MARK: - Create (acceptance: "Приседания" with a number field, from the phone)

    func testCreateSquatsWithNumberFieldSendsPayloadAndAppends() async {
        let api = MockCategoriesAPI()
        let numberField = makeFieldResponse(id: 10, name: "Reps", type: .number)
        let created = makeCategory(id: 7, name: "Приседания", fields: [numberField])
        api.createResult = .success(created)

        let viewModel = CategoriesViewModel(api: api)
        let draft = CategoryDraft(
            name: "Приседания",
            color: "#FF0000",
            fields: [FieldDraft(name: "Reps", fieldType: .number, isRequired: true)]
        )
        let ok = await viewModel.createCategory(draft)

        XCTAssertTrue(ok)
        XCTAssertEqual(api.createdPayloads.count, 1)
        let payload = api.createdPayloads[0]
        XCTAssertEqual(payload.name, "Приседания")
        XCTAssertEqual(payload.color, "#FF0000")
        XCTAssertEqual(payload.fields.count, 1)
        XCTAssertEqual(payload.fields[0].name, "Reps")
        XCTAssertEqual(payload.fields[0].fieldType, .number)
        XCTAssertTrue(payload.fields[0].isRequired)
        XCTAssertNil(payload.fields[0].options)
        XCTAssertEqual(payload.fields[0].order, 0)
        XCTAssertEqual(viewModel.categories.map(\.id), [7])
        XCTAssertNil(viewModel.saveErrorMessage)
    }

    func testCreateSelectFieldEncodesOptionsAsJSONArray() async {
        let api = MockCategoriesAPI()
        api.createResult = .success(makeCategory(id: 8, name: "Mood"))

        let viewModel = CategoriesViewModel(api: api)
        let draft = CategoryDraft(
            name: "Mood",
            fields: [FieldDraft(name: "How", fieldType: .select, options: ["good", " bad "])]
        )
        _ = await viewModel.createCategory(draft)

        XCTAssertEqual(api.createdPayloads[0].fields[0].options, #"["good","bad"]"#)
    }

    func testCreateFailureSetsErrorAndReturnsFalse() async {
        let api = MockCategoriesAPI()
        api.createResult = .failure(APIClientError.unauthorized)

        let viewModel = CategoriesViewModel(api: api)
        let ok = await viewModel.createCategory(CategoryDraft(name: "X"))

        XCTAssertFalse(ok)
        XCTAssertEqual(viewModel.saveErrorMessage, "Invalid API key (401)")
        XCTAssertTrue(viewModel.categories.isEmpty)
    }

    // MARK: - Update

    func testUpdateReplacesCategoryInList() async {
        let api = MockCategoriesAPI()
        api.categoriesResult = .success([makeCategory(id: 3, name: "Old")])
        let renamed = makeCategory(id: 3, name: "New")
        api.updateResult = .success(renamed)

        let viewModel = CategoriesViewModel(api: api)
        await viewModel.load()
        let ok = await viewModel.updateCategory(id: 3, CategoryDraft(name: "New"))

        XCTAssertTrue(ok)
        XCTAssertEqual(api.updatedPayloads.map(\.id), [3])
        XCTAssertEqual(viewModel.categories.first { $0.id == 3 }?.name, "New")
    }

    func testUpdateEmptyNameDoesNotCallAPI() async {
        let api = MockCategoriesAPI()
        let viewModel = CategoriesViewModel(api: api)

        let ok = await viewModel.updateCategory(id: 3, CategoryDraft(name: "  "))

        XCTAssertFalse(ok)
        XCTAssertTrue(api.updatedPayloads.isEmpty)
        XCTAssertEqual(viewModel.saveErrorMessage, CategoryValidationError.emptyName.message)
    }

    // MARK: - Delete

    func testDeleteRemovesCategoryFromList() async {
        let api = MockCategoriesAPI()
        api.categoriesResult = .success([
            makeCategory(id: 1, name: "A"),
            makeCategory(id: 2, name: "B"),
        ])

        let viewModel = CategoriesViewModel(api: api)
        await viewModel.load()
        let ok = await viewModel.deleteCategory(id: 1)

        XCTAssertTrue(ok)
        XCTAssertEqual(api.deletedIDs, [1])
        XCTAssertEqual(viewModel.categories.map(\.id), [2])
    }

    func testDeleteFailureKeepsCategoryAndSetsError() async {
        let api = MockCategoriesAPI()
        api.categoriesResult = .success([makeCategory(id: 1, name: "A")])
        api.deleteResult = .failure(APIClientError.unexpectedStatus(500))

        let viewModel = CategoriesViewModel(api: api)
        await viewModel.load()
        let ok = await viewModel.deleteCategory(id: 1)

        XCTAssertFalse(ok)
        XCTAssertEqual(viewModel.categories.map(\.id), [1])
        XCTAssertNotNil(viewModel.saveErrorMessage)
    }
}
