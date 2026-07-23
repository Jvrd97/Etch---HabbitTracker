// [review:need-review] PHASE-01/06-ios-table-view
// summary: unit tests for TableGrid mapping — columns, empty days/cells, field types, row ordering
import XCTest
@testable import HabitTracker

final class TableGridMappingTests: XCTestCase {
    private func meta(
        id: Int,
        name: String,
        primaryFieldId: Int?,
        primaryFieldType: String? = "number"
    ) -> TableCategoryMetaDTO {
        TableCategoryMetaDTO(
            id: id,
            name: name,
            displayMode: "form",
            group: nil,
            primaryFieldId: primaryFieldId,
            primaryFieldName: primaryFieldId.map { "field\($0)" },
            primaryFieldType: primaryFieldId == nil ? nil : primaryFieldType
        )
    }

    private func cell(
        categoryId: Int, fieldId: Int, value: String?, count: Int
    ) -> TableCellDTO {
        TableCellDTO(
            categoryId: categoryId,
            fieldId: fieldId,
            aggregatedValue: value,
            entryCount: count
        )
    }

    func testColumnsComeFromCategoriesWithPrimaryField() {
        let response = TableResponseDTO(
            categories: [
                meta(id: 1, name: "Pushups", primaryFieldId: 10),
                meta(id: 2, name: "No field", primaryFieldId: nil),
                meta(id: 3, name: "Mood", primaryFieldId: 30, primaryFieldType: "select"),
            ],
            days: []
        )

        let grid = TableGrid(from: response)

        XCTAssertEqual(grid.columns.map(\.categoryId), [1, 3])
        XCTAssertEqual(grid.columns.map(\.title), ["Pushups", "Mood"])
        XCTAssertEqual(grid.columns.map(\.fieldId), [10, 30])
        XCTAssertEqual(grid.columns.map(\.fieldType), [.number, .select])
    }

    func testAggregatedNumberValueLandsInMatchingCell() {
        let response = TableResponseDTO(
            categories: [meta(id: 1, name: "Pushups", primaryFieldId: 10)],
            days: [
                TableDayDTO(
                    date: "2026-07-23",
                    cells: [cell(categoryId: 1, fieldId: 10, value: "42", count: 2)]
                )
            ]
        )

        let grid = TableGrid(from: response)

        XCTAssertEqual(grid.rows.count, 1)
        XCTAssertEqual(grid.rows[0].date, "2026-07-23")
        XCTAssertEqual(grid.rows[0].cells, [TableGridCell(value: "42", entryCount: 2)])
    }

    func testEmptyDayProducesEmptyCellsForEveryColumn() {
        let response = TableResponseDTO(
            categories: [
                meta(id: 1, name: "Pushups", primaryFieldId: 10),
                meta(id: 2, name: "Water", primaryFieldId: 20),
            ],
            days: [TableDayDTO(date: "2026-07-22", cells: [])]
        )

        let grid = TableGrid(from: response)

        XCTAssertEqual(grid.rows[0].cells, [.empty, .empty])
        XCTAssertTrue(grid.rows[0].cells.allSatisfy(\.isEmpty))
    }

    func testMissingCellForOneColumnStaysEmptyWhileOthersFill() {
        let response = TableResponseDTO(
            categories: [
                meta(id: 1, name: "Pushups", primaryFieldId: 10),
                meta(id: 2, name: "Water", primaryFieldId: 20),
            ],
            days: [
                TableDayDTO(
                    date: "2026-07-23",
                    // Only Water has data this day; Pushups column must stay empty.
                    cells: [cell(categoryId: 2, fieldId: 20, value: "3", count: 1)]
                )
            ]
        )

        let grid = TableGrid(from: response)

        XCTAssertEqual(
            grid.rows[0].cells,
            [.empty, TableGridCell(value: "3", entryCount: 1)]
        )
    }

    func testTextFieldValuePassesThroughUnchanged() {
        let response = TableResponseDTO(
            categories: [
                meta(id: 5, name: "Journal", primaryFieldId: 50, primaryFieldType: "text")
            ],
            days: [
                TableDayDTO(
                    date: "2026-07-23",
                    cells: [cell(categoryId: 5, fieldId: 50, value: "felt great", count: 1)]
                )
            ]
        )

        let grid = TableGrid(from: response)

        XCTAssertEqual(grid.columns[0].fieldType, .text)
        XCTAssertEqual(grid.rows[0].cells[0], TableGridCell(value: "felt great", entryCount: 1))
    }

    func testRowsSortedByDateDescending() {
        let response = TableResponseDTO(
            categories: [meta(id: 1, name: "Pushups", primaryFieldId: 10)],
            days: [
                TableDayDTO(date: "2026-07-20", cells: []),
                TableDayDTO(date: "2026-07-23", cells: []),
                TableDayDTO(date: "2026-07-21", cells: []),
            ]
        )

        let grid = TableGrid(from: response)

        XCTAssertEqual(grid.rows.map(\.date), ["2026-07-23", "2026-07-21", "2026-07-20"])
    }
}
