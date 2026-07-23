// [review:need-review] PHASE-01/03-ios-scaffold-settings
// summary: unit tests for APIClient.checkConnection — success, 401, timeout, header injection
import XCTest
@testable import HabitTracker

final class APIClientTests: XCTestCase {
    private func makeClient(apiKey: String? = "test-key") -> APIClient {
        APIClient(
            baseURL: URL(string: "http://127.0.0.1:8000")!,
            apiKeyProvider: { apiKey },
            session: MockURLProtocol.makeSession()
        )
    }

    private static func httpResponse(for request: URLRequest, status: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testCheckConnectionSucceedsOn200AndSendsAPIKeyHeader() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let body = Data(#"{"message": "Habit Tracker API", "version": "1.0.0"}"#.utf8)
            return (Self.httpResponse(for: request, status: 200), body)
        }

        try await makeClient().checkConnection()

        XCTAssertEqual(capturedRequest?.url?.path, "/")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "X-API-Key"), "test-key")
    }

    func testCheckConnectionThrowsUnauthorizedOn401() async {
        MockURLProtocol.requestHandler = { request in
            (Self.httpResponse(for: request, status: 401), Data(#"{"detail": "Invalid API key"}"#.utf8))
        }

        do {
            try await makeClient(apiKey: "wrong").checkConnection()
            XCTFail("Expected APIClientError.unauthorized")
        } catch let error as APIClientError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testCheckConnectionThrowsTimeout() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.timedOut)
        }

        do {
            try await makeClient().checkConnection()
            XCTFail("Expected APIClientError.timeout")
        } catch let error as APIClientError {
            XCTAssertEqual(error, .timeout)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testCheckConnectionThrowsUnexpectedStatusOn500() async {
        MockURLProtocol.requestHandler = { request in
            (Self.httpResponse(for: request, status: 500), Data())
        }

        do {
            try await makeClient().checkConnection()
            XCTFail("Expected APIClientError.unexpectedStatus")
        } catch let error as APIClientError {
            XCTAssertEqual(error, .unexpectedStatus(500))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testCheckConnectionOmitsHeaderWhenNoKeyStored() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            return (Self.httpResponse(for: request, status: 200), Data("{}".utf8))
        }

        try await makeClient(apiKey: nil).checkConnection()

        XCTAssertNil(capturedRequest?.value(forHTTPHeaderField: "X-API-Key"))
    }
}
