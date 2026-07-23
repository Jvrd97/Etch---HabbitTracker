// [review:need-review] PHASE-01/37-ios-insights
// summary: unit tests for InsightsViewModel — load history, run analysis (happy/503/502→retry), open past report, period selection
import XCTest
@testable import HabitTracker

/// Scriptable stand-in for the API used by `InsightsViewModel`.
final class MockInsightsAPI: InsightsAPI {
    var listResult: Result<[InsightListItemDTO], Error> = .success([])
    var detailResult: Result<InsightReportDTO, Error>?
    var createResult: Result<InsightReportDTO, Error>?
    private(set) var createdPayloads: [InsightRequestDTO] = []
    private(set) var fetchedDetailIDs: [Int] = []

    func fetchInsights() async throws -> [InsightListItemDTO] {
        try listResult.get()
    }

    func fetchInsight(id: Int) async throws -> InsightReportDTO {
        fetchedDetailIDs.append(id)
        guard let detailResult else { throw APIClientError.invalidResponse }
        return try detailResult.get()
    }

    func createInsight(_ payload: InsightRequestDTO) async throws -> InsightReportDTO {
        createdPayloads.append(payload)
        guard let createResult else { throw APIClientError.invalidResponse }
        return try createResult.get()
    }
}

@MainActor
final class InsightsViewModelTests: XCTestCase {
    private func makeReport(
        id: Int,
        periodDays: Int = 30,
        content: String = "## Тренды\n- всё хорошо",
        model: String = "claude-sonnet-5"
    ) -> InsightReportDTO {
        InsightReportDTO(
            id: id,
            periodDays: periodDays,
            content: content,
            model: model,
            createdAt: "2026-07-21T10:00:00"
        )
    }

    private func makeListItem(
        id: Int,
        periodDays: Int = 30,
        preview: String = "превью",
        model: String = "claude-sonnet-5"
    ) -> InsightListItemDTO {
        InsightListItemDTO(
            id: id,
            periodDays: periodDays,
            model: model,
            createdAt: "2026-07-21T10:00:00",
            preview: preview
        )
    }

    // MARK: - Load history

    func testLoadPopulatesReports() async {
        let api = MockInsightsAPI()
        api.listResult = .success([makeListItem(id: 2), makeListItem(id: 1)])

        let viewModel = InsightsViewModel(api: api)
        await viewModel.load()

        XCTAssertEqual(viewModel.historyState, .loaded)
        XCTAssertEqual(viewModel.reports.map(\.id), [2, 1])
    }

    func testLoadFailureSetsFailureMessage() async {
        let api = MockInsightsAPI()
        api.listResult = .failure(APIClientError.timeout)

        let viewModel = InsightsViewModel(api: api)
        await viewModel.load()

        guard case .failure(let message) = viewModel.historyState else {
            return XCTFail("Expected failure state, got \(viewModel.historyState)")
        }
        XCTAssertFalse(message.isEmpty)
    }

    // MARK: - Run analysis (acceptance: разбор запускается и сохраняется в историю)

    func testRunAnalysisSendsSelectedPeriodAndSavesToHistory() async {
        let api = MockInsightsAPI()
        api.createResult = .success(
            makeReport(id: 42, periodDays: 90, content: "## Разбор за 90 дней")
        )

        let viewModel = InsightsViewModel(api: api)
        viewModel.selectedPeriod = .quarter
        let ok = await viewModel.runAnalysis()

        XCTAssertTrue(ok)
        XCTAssertEqual(api.createdPayloads.map(\.periodDays), [90])
        XCTAssertEqual(viewModel.analysisState, .idle)
        // The fresh report is opened for viewing…
        XCTAssertEqual(viewModel.openedReport?.id, 42)
        // …and inserted at the top of the history without a reload round trip.
        XCTAssertEqual(viewModel.reports.first?.id, 42)
        XCTAssertEqual(viewModel.reports.first?.periodDays, 90)
    }

    func testRunAnalysis503SurfacesNotConfiguredHint() async {
        let api = MockInsightsAPI()
        api.createResult = .failure(APIClientError.unexpectedStatus(503))

        let viewModel = InsightsViewModel(api: api)
        let ok = await viewModel.runAnalysis()

        XCTAssertFalse(ok)
        XCTAssertEqual(viewModel.analysisState, .notConfigured)
        XCTAssertTrue(viewModel.reports.isEmpty)
    }

    func testRunAnalysis502SetsFailureThenRetrySucceeds() async {
        let api = MockInsightsAPI()
        api.createResult = .failure(APIClientError.unexpectedStatus(502))

        let viewModel = InsightsViewModel(api: api)
        let firstOk = await viewModel.runAnalysis()

        XCTAssertFalse(firstOk)
        guard case .failure(let message) = viewModel.analysisState else {
            return XCTFail("Expected failure state, got \(viewModel.analysisState)")
        }
        XCTAssertFalse(message.isEmpty)

        // Retry: the transient LLM error clears and the analysis succeeds.
        api.createResult = .success(makeReport(id: 7))
        let retryOk = await viewModel.runAnalysis()

        XCTAssertTrue(retryOk)
        XCTAssertEqual(viewModel.analysisState, .idle)
        XCTAssertEqual(viewModel.reports.first?.id, 7)
    }

    func testRunAnalysisNotConfiguredWhenNoAPI() async {
        let viewModel = InsightsViewModel(apiProvider: { nil })
        let ok = await viewModel.runAnalysis()

        XCTAssertFalse(ok)
        guard case .failure = viewModel.analysisState else {
            return XCTFail("Expected failure state, got \(viewModel.analysisState)")
        }
    }

    // MARK: - Open a past report (acceptance: прошлые отчёты открываются)

    func testOpenReportFetchesFullReport() async {
        let api = MockInsightsAPI()
        api.detailResult = .success(makeReport(id: 5, content: "## Полный отчёт"))

        let viewModel = InsightsViewModel(api: api)
        await viewModel.openReport(id: 5)

        XCTAssertEqual(api.fetchedDetailIDs, [5])
        XCTAssertEqual(viewModel.openedReport?.id, 5)
        XCTAssertEqual(viewModel.openedReport?.content, "## Полный отчёт")
    }

    func testOpenReportFailureSetsErrorMessage() async {
        let api = MockInsightsAPI()
        api.detailResult = .failure(APIClientError.unexpectedStatus(404))

        let viewModel = InsightsViewModel(api: api)
        await viewModel.openReport(id: 99)

        XCTAssertNil(viewModel.openedReport)
        XCTAssertNotNil(viewModel.openErrorMessage)
    }
}
