// [review:need-review] PHASE-01/36-ios-category-charts
// summary: unit tests for pure category-chart helpers — parity with web chart-data/chart-utils (series/axes/units, value parsing, per-day points, period slicing, cumulate, checklist bars, streaks)
import XCTest
@testable import HabitTracker

final class CategoryChartDataTests: XCTestCase {
    // MARK: - Fixtures

    private func makeField(
        id: Int, name: String, type: FieldTypeDTO, order: Int
    ) -> FieldDTO {
        FieldDTO(
            id: id,
            name: name,
            fieldType: type,
            isRequired: false,
            defaultValue: nil,
            options: nil,
            order: order
        )
    }

    private lazy var kmField = makeField(id: 10, name: "Distance (km)", type: .number, order: 0)
    private lazy var timeField = makeField(id: 11, name: "Duration", type: .time, order: 1)
    private lazy var notesField = makeField(id: 12, name: "Notes", type: .text, order: 2)
    private lazy var stepsField = makeField(id: 13, name: "Steps", type: .number, order: 3)

    private func cell(
        _ categoryId: Int, _ fieldId: Int, _ value: String?
    ) -> TableCellDTO {
        TableCellDTO(categoryId: categoryId, fieldId: fieldId, aggregatedValue: value, entryCount: 1)
    }

    // MARK: - chartableFields

    func testChartableFieldsKeepsNumberAndTimeSortedByOrder() {
        let result = CategoryChart.chartableFields([stepsField, notesField, timeField, kmField])
        XCTAssertEqual(result.map(\.id), [10, 11, 13])
    }

    // MARK: - buildSeries

    func testBuildSeriesPutsKmAndTimeOnDifferentAxes() {
        let series = CategoryChart.buildSeries([kmField, timeField])
        XCTAssertEqual(series.count, 2)
        XCTAssertEqual(series[0].fieldId, 10)
        XCTAssertEqual(series[0].unit, "km")
        XCTAssertEqual(series[0].axis, .left)
        XCTAssertEqual(series[1].fieldId, 11)
        XCTAssertEqual(series[1].unit, "min")
        XCTAssertEqual(series[1].axis, .right)
    }

    func testBuildSeriesKeepsSameUnitOnLeftAxis() {
        let a = makeField(id: 1, name: "Work (h)", type: .number, order: 0)
        let b = makeField(id: 2, name: "Rest (h)", type: .number, order: 1)
        let series = CategoryChart.buildSeries([a, b])
        XCTAssertEqual(series.map(\.axis), [.left, .left])
    }

    func testBuildSeriesAssignsDistinctColorsInFixedOrder() {
        let series = CategoryChart.buildSeries([kmField, timeField, stepsField])
        XCTAssertEqual(Set(series.map(\.colorHex)).count, 3)
    }

    // MARK: - parseCellValue

    func testParseNumberValues() {
        XCTAssertEqual(CategoryChart.parseCellValue(fieldType: .number, raw: "12.5"), 12.5)
        XCTAssertNil(CategoryChart.parseCellValue(fieldType: .number, raw: "abc"))
        XCTAssertNil(CategoryChart.parseCellValue(fieldType: .number, raw: nil))
    }

    func testParseTimeValuesIntoMinutes() {
        XCTAssertEqual(CategoryChart.parseCellValue(fieldType: .time, raw: "01:30"), 90)
        XCTAssertEqual(CategoryChart.parseCellValue(fieldType: .time, raw: "00:45:30"), 45.5)
        XCTAssertNil(CategoryChart.parseCellValue(fieldType: .time, raw: "later"))
    }

    // MARK: - buildChartData

    func testBuildChartDataOnePointPerDayIgnoringOtherCategories() {
        let days: [TableDayDTO] = [
            TableDayDTO(date: "2026-07-01", cells: [
                cell(1, 10, "5.2"),
                cell(1, 11, "00:30"),
                cell(2, 99, "999"),
            ]),
            TableDayDTO(date: "2026-07-02", cells: []),
        ]
        let data = CategoryChart.buildChartData(days: days, categoryId: 1, fields: [kmField, timeField])
        XCTAssertEqual(data.count, 2)
        XCTAssertEqual(data[0].date, "2026-07-01")
        XCTAssertEqual(data[0].values[10], .some(5.2))
        XCTAssertEqual(data[0].values[11], .some(30))
        XCTAssertEqual(data[1].date, "2026-07-02")
        // Missing cells become a null gap, but the key is still present.
        XCTAssertEqual(data[1].values[10], .some(nil))
        XCTAssertEqual(data[1].values[11], .some(nil))
    }

    // MARK: - chartDateRange

    func testChartDateRangeSpansMaxDaysEndingToday() {
        let today = isoDate("2026-07-22")
        let range = CategoryChart.chartDateRange(today: today)
        XCTAssertEqual(range.from, "2025-07-23")
        XCTAssertEqual(range.to, "2026-07-22")
    }

    // MARK: - sliceByPeriod

    func testSliceByPeriodKeepsLastNForFixedPeriod() {
        let points = (0..<40).map { "d\($0)" }
        let result = CategoryChart.sliceByPeriod(points, period: .sevenDays)
        XCTAssertEqual(result.count, 7)
        XCTAssertEqual(result.first, "d33")
    }

    func testSliceByPeriodKeepsEverythingForAll() {
        let points = (0..<40).map { "d\($0)" }
        XCTAssertEqual(CategoryChart.sliceByPeriod(points, period: .all).count, 40)
    }

    // MARK: - cumulate

    func testCumulateEmptySeries() {
        XCTAssertEqual(CategoryChart.cumulate([]), [])
    }

    func testCumulateMonotonicRunningSumForOneLine() {
        let points = [
            point("2026-07-01", [1: 2]),
            point("2026-07-02", [1: 3]),
            point("2026-07-03", [1: 1]),
        ]
        XCTAssertEqual(CategoryChart.cumulate(points), [
            point("2026-07-01", [1: 2]),
            point("2026-07-02", [1: 5]),
            point("2026-07-03", [1: 6]),
        ])
    }

    func testCumulateKeepsNullGapsWithoutBreakingTotal() {
        let points = [
            point("2026-07-01", [1: nil]),
            point("2026-07-02", [1: 4]),
            point("2026-07-03", [1: nil]),
            point("2026-07-04", [1: 6]),
        ]
        XCTAssertEqual(CategoryChart.cumulate(points), [
            point("2026-07-01", [1: nil]),
            point("2026-07-02", [1: 4]),
            point("2026-07-03", [1: nil]),
            point("2026-07-04", [1: 10]),
        ])
    }

    func testCumulateAccumulatesMultipleLinesIndependently() {
        let points = [
            point("2026-07-01", [1: 1, 2: 10]),
            point("2026-07-02", [1: 2, 2: nil]),
            point("2026-07-03", [1: 3, 2: 30]),
        ]
        XCTAssertEqual(CategoryChart.cumulate(points), [
            point("2026-07-01", [1: 1, 2: 10]),
            point("2026-07-02", [1: 3, 2: nil]),
            point("2026-07-03", [1: 6, 2: 40]),
        ])
    }

    // MARK: - buildChecklistBarData

    func testChecklistBarEmptyHistory() {
        XCTAssertEqual(CategoryChart.buildChecklistBarData(days: [], categoryId: 1, fields: []), [])
    }

    func testChecklistBarCountsTrueCellsPerDay() {
        let vitaminD = makeField(id: 1, name: "Vitamin D", type: .boolean, order: 0)
        let magnesium = makeField(id: 2, name: "Magnesium", type: .boolean, order: 1)
        let omega3 = makeField(id: 3, name: "Omega 3", type: .boolean, order: 2)
        let days: [TableDayDTO] = [
            checklistDay("2026-07-01", [1, 2, 3]),
            checklistDay("2026-07-02", [2]),
            checklistDay("2026-07-03", []),
        ]
        let result = CategoryChart.buildChecklistBarData(
            days: days, categoryId: 1, fields: [vitaminD, magnesium, omega3]
        )
        XCTAssertEqual(result, [
            ChecklistBarPoint(date: "2026-07-01", done: 3),
            ChecklistBarPoint(date: "2026-07-02", done: 1),
            ChecklistBarPoint(date: "2026-07-03", done: 0),
        ])
    }

    func testChecklistBarIgnoresNonBooleanOtherCategoriesAndFalseCells() {
        let vitaminD = makeField(id: 1, name: "Vitamin D", type: .boolean, order: 0)
        let magnesium = makeField(id: 2, name: "Magnesium", type: .boolean, order: 1)
        let omega3 = makeField(id: 3, name: "Omega 3", type: .boolean, order: 2)
        let notes = makeField(id: 4, name: "Notes", type: .text, order: 3)
        let days: [TableDayDTO] = [
            TableDayDTO(date: "2026-07-01", cells: [
                cell(1, 1, "true"),
                cell(1, 2, "false"),
                cell(1, 4, "true"),
                cell(9, 3, "true"),
            ]),
        ]
        let result = CategoryChart.buildChecklistBarData(
            days: days, categoryId: 1, fields: [vitaminD, magnesium, omega3, notes]
        )
        XCTAssertEqual(result, [ChecklistBarPoint(date: "2026-07-01", done: 1)])
    }

    // MARK: - currentStreak

    private let today = "2026-07-22"

    func testStreakIsZeroForEmptyHistory() {
        XCTAssertEqual(CategoryChart.currentStreak(days: [], categoryId: 1, fieldId: 1, today: today), 0)
    }

    func testStreakIsZeroWhenNeitherTodayNorYesterdayDone() {
        let days = [checklistDay("2026-07-19", [1])]
        XCTAssertEqual(CategoryChart.currentStreak(days: days, categoryId: 1, fieldId: 1, today: today), 0)
    }

    func testStreakIsOneWhenOnlyTodayDone() {
        let days = [checklistDay(today, [1])]
        XCTAssertEqual(CategoryChart.currentStreak(days: days, categoryId: 1, fieldId: 1, today: today), 1)
    }

    func testStreakCountsConsecutiveDaysEndingToday() {
        let days = [
            checklistDay("2026-07-19", [1]),
            checklistDay("2026-07-20", [1]),
            checklistDay("2026-07-21", [1]),
            checklistDay(today, [1]),
        ]
        XCTAssertEqual(CategoryChart.currentStreak(days: days, categoryId: 1, fieldId: 1, today: today), 4)
    }

    func testStreakBreaksAtDayWithoutTrueValue() {
        let days = [
            checklistDay("2026-07-18", [1]),
            checklistDay("2026-07-19", [1]),
            checklistDay("2026-07-20", []),
            checklistDay("2026-07-21", [1]),
            checklistDay(today, [1]),
        ]
        XCTAssertEqual(CategoryChart.currentStreak(days: days, categoryId: 1, fieldId: 1, today: today), 2)
    }

    func testStreakKeepsYesterdayEndingStreakAliveWhileTodayPending() {
        let days = [checklistDay("2026-07-20", [1]), checklistDay("2026-07-21", [1])]
        XCTAssertEqual(CategoryChart.currentStreak(days: days, categoryId: 1, fieldId: 1, today: today), 2)
    }

    func testStreakIgnoresOtherFieldsAndCategories() {
        let days = [checklistDay(today, [2]), checklistDay("2026-07-21", [1], categoryId: 9)]
        XCTAssertEqual(CategoryChart.currentStreak(days: days, categoryId: 1, fieldId: 1, today: today), 0)
    }

    // MARK: - Helpers

    private func point(_ date: String, _ values: [Int: Double?]) -> ChartPoint {
        ChartPoint(date: date, values: values)
    }

    private func checklistDay(_ date: String, _ trueFieldIds: [Int], categoryId: Int = 1) -> TableDayDTO {
        TableDayDTO(
            date: date,
            cells: trueFieldIds.map { cell(categoryId, $0, "true") }
        )
    }

    private func isoDate(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)!
    }
}
