// [review:need-review] PHASE-01/05-ios-today-quick-entry
// summary: wire-format tests for APIClient TodayAPI endpoints (paths, query, snake_case JSON, checklist PUT)
import XCTest
@testable import HabitTracker

final class TodayAPIClientTests: XCTestCase {
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

    private static func okResponse(for request: URLRequest, body: String) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, Data(body.utf8))
    }

    func testFetchCategoriesDecodesBackendJSON() async throws {
        let body = """
        [{
            "id": 1,
            "name": "Pushups",
            "description": null,
            "icon": "💪",
            "color": "#FF0000",
            "display_mode": "form",
            "streak_mode": "build",
            "group": null,
            "is_active": true,
            "created_at": "2026-07-01T10:00:00",
            "updated_at": "2026-07-01T10:00:00",
            "fields": [{
                "id": 10,
                "category_id": 1,
                "name": "Count",
                "field_type": "number",
                "is_required": true,
                "default_value": null,
                "options": null,
                "order": 0,
                "created_at": "2026-07-01T10:00:00",
                "updated_at": "2026-07-01T10:00:00"
            }]
        }]
        """
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { request in
            capturedURL = request.url
            return Self.okResponse(for: request, body: body)
        }

        let categories = try await client.fetchCategories()

        XCTAssertEqual(capturedURL?.path, "/api/v1/categories")
        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(categories[0].name, "Pushups")
        XCTAssertEqual(categories[0].displayMode, "form")
        XCTAssertEqual(categories[0].fields[0].fieldType, .number)
    }

    func testFetchEntriesSendsDateRangeQuery() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { request in
            capturedURL = request.url
            return Self.okResponse(for: request, body: "[]")
        }

        _ = try await client.fetchEntries(startDate: "2026-07-23", endDate: "2026-07-23")

        XCTAssertEqual(capturedURL?.path, "/api/v1/entries")
        let components = URLComponents(url: capturedURL!, resolvingAgainstBaseURL: false)!
        let query = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) }
        )
        XCTAssertEqual(query["start_date"], "2026-07-23")
        XCTAssertEqual(query["end_date"], "2026-07-23")
    }

    func testCreateEntryPostsSnakeCaseBody() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            capturedBody = request.httpBody ?? request.httpBodyStream.map { stream in
                stream.open()
                defer { stream.close() }
                var data = Data()
                let bufferSize = 1024
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                defer { buffer.deallocate() }
                while stream.hasBytesAvailable {
                    let read = stream.read(buffer, maxLength: bufferSize)
                    if read <= 0 { break }
                    data.append(buffer, count: read)
                }
                return data
            }
            let body = """
            {"id": 5, "category_id": 1, "entry_date": "2026-07-23", "notes": null,
             "created_at": "2026-07-23T09:00:00", "updated_at": "2026-07-23T09:00:00",
             "values": [{"id": 7, "entry_id": 5, "field_id": 10, "value": "42"}]}
            """
            return Self.okResponse(for: request, body: body)
        }

        let payload = EntryCreateDTO(
            categoryId: 1,
            entryDate: "2026-07-23",
            notes: nil,
            values: [EntryValueDTO(fieldId: 10, value: "42")]
        )
        let created = try await client.createEntry(payload)

        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/entries")
        XCTAssertEqual(
            capturedRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json"
        )
        let json = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: XCTUnwrap(capturedBody)) as? [String: Any]
        )
        XCTAssertEqual(json["category_id"] as? Int, 1)
        XCTAssertEqual(json["entry_date"] as? String, "2026-07-23")
        let values = try XCTUnwrap(json["values"] as? [[String: Any]])
        XCTAssertEqual(values.first?["field_id"] as? Int, 10)
        XCTAssertEqual(values.first?["value"] as? String, "42")
        XCTAssertEqual(created.id, 5)
        XCTAssertEqual(created.values, [EntryValueDTO(fieldId: 10, value: "42")])
    }

    func testUpsertChecklistEntryPutsBoolValuesKeyedByFieldID() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            capturedBody = request.httpBody ?? request.httpBodyStream.map { stream in
                stream.open()
                defer { stream.close() }
                var data = Data()
                let bufferSize = 1024
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                defer { buffer.deallocate() }
                while stream.hasBytesAvailable {
                    let read = stream.read(buffer, maxLength: bufferSize)
                    if read <= 0 { break }
                    data.append(buffer, count: read)
                }
                return data
            }
            let body = """
            {"id": 8, "category_id": 2, "entry_date": "2026-07-23", "notes": null,
             "created_at": "2026-07-23T09:00:00", "updated_at": "2026-07-23T09:00:00",
             "values": [{"id": 9, "entry_id": 8, "field_id": 20, "value": "true"}]}
            """
            return Self.okResponse(for: request, body: body)
        }

        let payload = ChecklistUpsertDTO(
            categoryId: 2,
            entryDate: "2026-07-23",
            values: ["20": true]
        )
        let entry = try await client.upsertChecklistEntry(payload)

        XCTAssertEqual(capturedRequest?.httpMethod, "PUT")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/entries/checklist")
        let json = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: XCTUnwrap(capturedBody)) as? [String: Any]
        )
        XCTAssertEqual(json["category_id"] as? Int, 2)
        XCTAssertEqual(json["entry_date"] as? String, "2026-07-23")
        XCTAssertEqual(json["values"] as? [String: Bool], ["20": true])
        XCTAssertEqual(entry.id, 8)
    }
}
