// [review:need-review] PHASE-01/36-ios-category-charts
// summary: Swift Charts view for the category detail screen — multi-line value chart (legend, Per day | Cumulative, 7/30/90/all periods) for number/time fields; "X of N" bar + streak badges for checklist categories; Lime Tech styling
import SwiftUI
import Charts

/// Category chart card: value lines for number/time categories, or an "X of N"
/// bar with streak badges for checklist categories. Reads its state (period,
/// mode, series, points) from `CategoryDetailViewModel`.
struct CategoryChartView: View {
    @ObservedObject var viewModel: CategoryDetailViewModel

    private static let axisDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            periodPicker
            if viewModel.isChecklistChart {
                checklistChart
            } else {
                modePicker
                lineChart
            }
        }
    }

    // MARK: - Controls

    private var periodPicker: some View {
        Picker("Period", selection: $viewModel.selectedPeriod) {
            ForEach(ChartPeriod.allCases) { period in
                Text(period.label).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    private var modePicker: some View {
        Picker("Mode", selection: $viewModel.chartMode) {
            ForEach(ChartMode.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Line chart

    /// One drawable sample: a non-null value of one series on one day.
    private struct LineSample: Identifiable {
        let id: String
        let series: String
        let date: Date
        let value: Double
    }

    private var lineSamples: [LineSample] {
        let series = viewModel.chartSeries
        guard !series.isEmpty else { return [] }
        var samples: [LineSample] = []
        for point in viewModel.linePoints {
            guard let date = Self.axisDateFormatter.date(from: point.date) else { continue }
            for line in series {
                guard let value = point.values[line.fieldId] ?? nil else { continue }
                samples.append(
                    LineSample(
                        id: "\(line.fieldId)-\(point.date)",
                        series: line.name,
                        date: date,
                        value: value
                    )
                )
            }
        }
        return samples
    }

    @ViewBuilder
    private var lineChart: some View {
        let samples = lineSamples
        if samples.isEmpty {
            emptyChart
        } else {
            let names = viewModel.chartSeries.map(\.name)
            let colors = viewModel.chartSeries.map { Color(hex: $0.colorHex) ?? DS.Palette.lime }
            Chart(samples) { sample in
                LineMark(
                    x: .value("Day", sample.date, unit: .day),
                    y: .value("Value", sample.value)
                )
                .foregroundStyle(by: .value("Series", sample.series))
                .interpolationMethod(.monotone)
                .symbol(by: .value("Series", sample.series))
            }
            .chartForegroundStyleScale(domain: names, range: colors)
            .chartLegend(position: .bottom, alignment: .leading)
            .chartXAxis { axisMarks }
            .frame(height: 220)
        }
    }

    private var axisMarks: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
            AxisGridLine().foregroundStyle(DS.Palette.cardStroke)
            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                .foregroundStyle(DS.Palette.textSecondary)
        }
    }

    // MARK: - Checklist chart

    private struct BarSample: Identifiable {
        let id: String
        let date: Date
        let done: Int
    }

    private var barSamples: [BarSample] {
        viewModel.checklistBarPoints.compactMap { point in
            guard let date = Self.axisDateFormatter.date(from: point.date) else { return nil }
            return BarSample(id: point.date, date: date, done: point.done)
        }
    }

    @ViewBuilder
    private var checklistChart: some View {
        let total = CategoryChart.booleanFields(viewModel.category.fields).count
        let samples = barSamples
        if samples.isEmpty {
            emptyChart
        } else {
            Chart(samples) { sample in
                BarMark(
                    x: .value("Day", sample.date, unit: .day),
                    y: .value("Done", sample.done)
                )
                .foregroundStyle(DS.Palette.lime)
                .cornerRadius(DS.Radius.chip / 3)
            }
            .chartYScale(domain: 0...Double(max(total, 1)))
            .chartXAxis { axisMarks }
            .frame(height: 200)
        }
        streakBadges
    }

    private var streakBadges: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(viewModel.fieldStreaks, id: \.field.id) { entry in
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(entry.streak > 0 ? DS.Palette.lime : DS.Palette.textDisabled)
                        Text("\(entry.field.name) · \(entry.streak)")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Palette.textPrimary)
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                            .fill(DS.Palette.surface)
                    )
                }
            }
        }
    }

    private var emptyChart: some View {
        Text("No chart data yet.")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 120)
    }
}
