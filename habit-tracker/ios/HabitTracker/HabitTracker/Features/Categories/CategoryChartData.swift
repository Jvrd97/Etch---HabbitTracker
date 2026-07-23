// [review:need-review] PHASE-01/36-ios-category-charts
// summary: pure category-chart helpers (parity with web chart-data/chart-utils) — series/axes/units, cell parsing, per-day points, period slicing, cumulative folding, checklist "X of N" bars, per-field streaks
import Foundation

/// Which slice of history the chart shows.
enum ChartPeriod: String, CaseIterable, Identifiable {
    case sevenDays
    case thirtyDays
    case ninetyDays
    case all

    var id: String { rawValue }

    /// Short label for the period picker.
    var label: String {
        switch self {
        case .sevenDays: return "7 days"
        case .thirtyDays: return "30 days"
        case .ninetyDays: return "90 days"
        case .all: return "All"
        }
    }

    /// Number of trailing days the period keeps; `nil` means "everything".
    var days: Int? {
        switch self {
        case .sevenDays: return 7
        case .thirtyDays: return 30
        case .ninetyDays: return 90
        case .all: return nil
        }
    }
}

/// Per day vs. running-total rendering of the line chart.
enum ChartMode: String, CaseIterable, Identifiable {
    case perDay
    case cumulative

    var id: String { rawValue }

    var label: String {
        switch self {
        case .perDay: return "Per day"
        case .cumulative: return "Cumulative"
        }
    }
}

/// Which Y axis a series is drawn against (two axes max, per web #20).
enum ChartAxis: Equatable {
    case left
    case right
}

/// One plotted line: a chartable field with its unit, axis, and color.
struct ChartSeries: Identifiable, Equatable {
    let fieldId: Int
    let name: String
    let unit: String
    let axis: ChartAxis
    let colorHex: String

    var id: Int { fieldId }
}

/// One day's plottable values, keyed by field id. A present key whose value is
/// `nil` is a gap in that line (missing cell); the key is always present for
/// every plottable field so lines stay aligned across days.
struct ChartPoint: Equatable {
    let date: String
    var values: [Int: Double?]
}

/// One bar of a checklist category's "X out of N" chart.
struct ChecklistBarPoint: Identifiable, Equatable {
    let date: String
    let done: Int

    var id: String { date }
}

/// Pure, side-effect-free helpers that turn a `GET /table` response into the
/// series/points/bars the category chart draws. Kept UI-free so the whole
/// mapping is unit-tested in parity with the web implementation.
enum CategoryChart {
    /// Dark-surface categorical palette in the Lime Tech idiom; validated for
    /// distinctness against the near-black chart surface.
    static let seriesColors: [String] = [
        "#B8FF36", // lime
        "#60A5FA", // info blue
        "#FACC15", // warning amber
        "#69E76A", // green
    ]

    private static let timeUnit = "min"
    private static let minutesPerHour = 60.0
    private static let secondsPerMinute = 60.0
    private static let trueValue = "true"
    /// Backend caps `GET /table` at 366 days; fetch a year and slice client-side.
    static let maxChartDays = 365

    // MARK: - Line series

    /// Fields that can be plotted as lines (number/time), in field order.
    static func chartableFields(_ fields: [FieldDTO]) -> [FieldDTO] {
        fields
            .filter { $0.fieldType == .number || $0.fieldType == .time }
            .sorted { ($0.order, $0.id) < ($1.order, $1.id) }
    }

    /// Boolean fields of a checklist category, in field order.
    static func booleanFields(_ fields: [FieldDTO]) -> [FieldDTO] {
        fields
            .filter { $0.fieldType == .boolean }
            .sorted { ($0.order, $0.id) < ($1.order, $1.id) }
    }

    /// Unit label: time fields are minutes; number fields use a trailing
    /// "(unit)" from the name if present, otherwise the whole name.
    private static func fieldUnit(_ field: FieldDTO) -> String {
        if field.fieldType == .time { return timeUnit }
        if let range = field.name.range(of: #"\(([^)]+)\)\s*$"#, options: .regularExpression) {
            let matched = field.name[range]
            let inner = matched
                .trimmingCharacters(in: .whitespaces)
                .dropFirst()  // "("
                .dropLast()   // ")"
            return inner.trimmingCharacters(in: .whitespaces)
        }
        return field.name
    }

    /// Build one line series per chartable field. The first distinct unit takes
    /// the left Y axis; every other unit shares the right one (two axes max).
    static func buildSeries(_ fields: [FieldDTO]) -> [ChartSeries] {
        let plottable = chartableFields(fields)
        var leftUnit: String?
        return plottable.enumerated().map { index, field in
            let unit = fieldUnit(field)
            if leftUnit == nil { leftUnit = unit }
            return ChartSeries(
                fieldId: field.id,
                name: field.name,
                unit: unit,
                axis: unit == leftUnit ? .left : .right,
                colorHex: seriesColors[index % seriesColors.count]
            )
        }
    }

    /// Parse an aggregated cell value into a plottable number (time -> minutes).
    static func parseCellValue(fieldType: FieldTypeDTO, raw: String?) -> Double? {
        guard let raw else { return nil }
        if fieldType == .number {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let value = Double(trimmed) else { return nil }
            return value.isFinite ? value : nil
        }
        // time: HH:MM[:SS]
        guard let match = raw.range(of: #"^(\d{1,2}):(\d{2})(:(\d{2}))?$"#, options: .regularExpression),
              match == raw.startIndex..<raw.endIndex else {
            return nil
        }
        let parts = raw.split(separator: ":").map { Double($0) ?? 0 }
        let hours = parts[0]
        let minutes = parts[1]
        let seconds = parts.count > 2 ? parts[2] : 0
        return hours * minutesPerHour + minutes + seconds / secondsPerMinute
    }

    /// One chart point per day; missing cells become a null gap in the line.
    static func buildChartData(
        days: [TableDayDTO], categoryId: Int, fields: [FieldDTO]
    ) -> [ChartPoint] {
        let plottable = chartableFields(fields)
        return days.map { day in
            var values: [Int: Double?] = [:]
            for field in plottable {
                let cell = day.cells.first {
                    $0.categoryId == categoryId && $0.fieldId == field.id
                }
                values.updateValue(
                    parseCellValue(fieldType: field.fieldType, raw: cell?.aggregatedValue),
                    forKey: field.id
                )
            }
            return ChartPoint(date: day.date, values: values)
        }
    }

    /// Running (prefix) sum per series, computed independently for each line.
    /// Null cells stay null (gap) and leave the running total untouched, so the
    /// drawn curve is monotonically non-decreasing. Input is not mutated.
    static func cumulate(_ points: [ChartPoint]) -> [ChartPoint] {
        var totals: [Int: Double] = [:]
        return points.map { point in
            var out: [Int: Double?] = [:]
            for (key, value) in point.values {
                if let value {
                    let total = (totals[key] ?? 0) + value
                    totals[key] = total
                    out.updateValue(total, forKey: key)
                } else {
                    out.updateValue(nil, forKey: key)
                }
            }
            return ChartPoint(date: point.date, values: out)
        }
    }

    // MARK: - Checklist bars & streaks

    /// One bar per day: how many boolean fields of the category were checked
    /// ("X out of N"). Missing cells and non-"true" values count as not done.
    static func buildChecklistBarData(
        days: [TableDayDTO], categoryId: Int, fields: [FieldDTO]
    ) -> [ChecklistBarPoint] {
        let boolIds = Set(booleanFields(fields).map(\.id))
        return days.map { day in
            let done = day.cells.filter {
                $0.categoryId == categoryId
                    && boolIds.contains($0.fieldId)
                    && $0.aggregatedValue == trueValue
            }.count
            return ChecklistBarPoint(date: day.date, done: done)
        }
    }

    /// Consecutive days with a true value for one boolean field, counted from
    /// today backwards. A day without a true value breaks the streak, except
    /// today itself: an unchecked today is treated as pending, so a streak
    /// ending yesterday still counts until the day is over.
    static func currentStreak(
        days: [TableDayDTO], categoryId: Int, fieldId: Int, today: String
    ) -> Int {
        let doneDates = Set(
            days
                .filter { day in
                    day.cells.contains {
                        $0.categoryId == categoryId
                            && $0.fieldId == fieldId
                            && $0.aggregatedValue == trueValue
                    }
                }
                .map(\.date)
        )
        var cursor = doneDates.contains(today) ? today : previousDay(today)
        var streak = 0
        while doneDates.contains(cursor) {
            streak += 1
            cursor = previousDay(cursor)
        }
        return streak
    }

    // MARK: - Ranges & slicing

    /// Widest fetch window: `maxChartDays` ending today (backend caps at 366).
    static func chartDateRange(today: Date) -> (from: String, to: String) {
        let from = utcCalendar.date(byAdding: .day, value: -(maxChartDays - 1), to: today) ?? today
        return (from: isoString(from), to: isoString(today))
    }

    /// Keep the last N per-day items for the period (`all` keeps everything).
    static func sliceByPeriod<T>(_ items: [T], period: ChartPeriod) -> [T] {
        guard let days = period.days else { return items }
        return items.count <= days ? items : Array(items.suffix(days))
    }

    // MARK: - Date helpers (UTC)

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private static let isoFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func isoString(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }

    /// Previous calendar day of an ISO date string (UTC arithmetic). Falls back
    /// to the input on an unparseable string, which cannot extend a streak.
    private static func previousDay(_ isoDate: String) -> String {
        guard let date = isoFormatter.date(from: isoDate),
              let previous = utcCalendar.date(byAdding: .day, value: -1, to: date) else {
            return isoDate
        }
        return isoString(previous)
    }
}
