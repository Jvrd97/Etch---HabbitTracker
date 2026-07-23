// [review:need-review] PHASE-01/06-ios-table-view
// summary: pure mapping of GET /table response into a days×habits grid (columns, rows, cells)
import Foundation

/// One column of the table = one habit (category), surfaced through its primary field.
/// Categories without a primary field cannot produce cell values, so they are omitted.
struct TableGridColumn: Identifiable, Equatable {
    let categoryId: Int
    let fieldId: Int
    let title: String
    let fieldType: FieldTypeDTO

    /// Stable identity for SwiftUI; a category has exactly one column here.
    var id: Int { categoryId }
}

/// One cell = the aggregated value of a column's field for a row's day.
/// `value == nil` means the day has no data for that habit (empty cell).
struct TableGridCell: Equatable {
    let value: String?
    let entryCount: Int

    static let empty = TableGridCell(value: nil, entryCount: 0)

    var isEmpty: Bool { entryCount == 0 }
}

/// One row = one day. `cells` is parallel to the grid's `columns`.
struct TableGridRow: Identifiable, Equatable {
    let date: String
    let cells: [TableGridCell]

    var id: String { date }
}

/// Immutable days×habits grid built from a `TableResponseDTO`.
/// Rows are ordered newest day first; columns follow the response's category order.
struct TableGrid: Equatable {
    let columns: [TableGridColumn]
    let rows: [TableGridRow]

    static let empty = TableGrid(columns: [], rows: [])

    /// Maps the raw table response into a rectangular grid.
    ///
    /// - Columns come from categories that expose a primary field.
    /// - Each day becomes a row; every column gets a cell, defaulting to
    ///   `.empty` when the day has no matching aggregated cell.
    /// - Rows are sorted by date descending so the most recent day is on top.
    init(from response: TableResponseDTO) {
        let columns = response.categories.compactMap { meta -> TableGridColumn? in
            guard let fieldId = meta.primaryFieldId else { return nil }
            return TableGridColumn(
                categoryId: meta.id,
                fieldId: fieldId,
                title: meta.name,
                fieldType: meta.primaryFieldType.map(FieldTypeDTO.init(rawValue:)) ?? .unknown("")
            )
        }

        let sortedDays = response.days.sorted { $0.date > $1.date }
        let rows = sortedDays.map { day -> TableGridRow in
            // Index the day's cells by (category, field) for O(1) column lookup.
            let cellIndex = Dictionary(
                day.cells.map { (CellKey(categoryId: $0.categoryId, fieldId: $0.fieldId), $0) },
                uniquingKeysWith: { first, _ in first }
            )
            let cells = columns.map { column -> TableGridCell in
                guard let cell = cellIndex[
                    CellKey(categoryId: column.categoryId, fieldId: column.fieldId)
                ] else {
                    return .empty
                }
                return TableGridCell(value: cell.aggregatedValue, entryCount: cell.entryCount)
            }
            return TableGridRow(date: day.date, cells: cells)
        }

        self.columns = columns
        self.rows = rows
    }

    private init(columns: [TableGridColumn], rows: [TableGridRow]) {
        self.columns = columns
        self.rows = rows
    }

    private struct CellKey: Hashable {
        let categoryId: Int
        let fieldId: Int
    }
}
