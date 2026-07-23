// [review:need-review] PHASE-01/06-ios-table-view
// summary: wire-format tests for APIClient TableAPI — /table range query + decode, /entries category filter
import XCTest
@testable import HabitTracker

final class TableAPIClientTests: XCTestCase {
    private var client: APIClient!

    override func setUp() {
        super.setUp()
        client = APIClient(
            baseURL: URL(string: "http://localhost:8000")!,
            apiKeyProvider: { "secret" },
            session: MockURLProtocol.makeSession()
        )
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        client = nil
        super.tearDown()
    }

    private static func okResponse(
        for request: URLRequest, body: String
    ) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, Data(body.utf8))
    }

    func testFetchTableSendsRangeQueryAndDecodesResponse() async throws {
        let body = """
        {
            "categories": [{
                "id": 1,
                "name": "Pushups",
                "display_mode": "form",
                "group": null,
                "primary_field_id": 10,
                "primary_field_name": "Count",
                "primary_field_type": "number"
            }],
            "days": [{
                "date": "2026-07-23",
                "cells": [{
                    "category_id": 1,
                    "field_id": 10,
                    "aggregated_value": "42",
                    "entry_count": 2
                }]
            }]
        }
        """
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { request in
            capturedURL = request.url
            return Self.okResponse(for: request, body: body)
        }

        let response = try await client.fetchTable(
            dateFrom: "2026-06-24", dateTo: "2026-07-23"
        )

        XCTAssertEqual(capturedURL?.path, "/api/v1/table")
        let components = URLComponents(url: capturedURL!, resolvingAgainstBaseURL: false)!
        let query = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) }
        )
        XCTAssertEqual(query["date_from"], "2026-06-24")
        XCTAssertEqual(query["date_to"], "2026-07-23")
        XCTAssertEqual(response.categories.map(\.primaryFieldId), [10])
        XCTAssertEqual(response.days.count, 1)
        XCTAssertEqual(response.days[0].cells[0].aggregatedValue, "42")
        XCTAssertEqual(response.days[0].cells[0].entryCount, 2)
    }

    func testFetchEntriesForCellSendsCategoryAndSingleDayRange() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { request in
            capturedURL = request.url
            return Self.okResponse(for: request, body: "[]")
        }

        _ = try await client.fetchEntries(categoryId: 3, date: "2026-07-23")

        XCTAssertEqual(capturedURL?.path, "/api/v1/entries")
        let components = URLComponents(url: capturedURL!, resolvingAgainstBaseURL: false)!
        let query = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) }
        )
        XCTAssertEqual(query["category_id"], "3")
        XCTAssertEqual(query["start_date"], "2026-07-23")
        XCTAssertEqual(query["end_date"], "2026-07-23")
    }
}
