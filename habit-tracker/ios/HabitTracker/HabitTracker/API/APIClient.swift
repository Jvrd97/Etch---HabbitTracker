// [review:need-review] PHASE-01/03-ios-scaffold-settings
// summary: URLSession async/await HTTP client with base URL + X-API-Key injection and typed errors
import Foundation

/// Errors surfaced by `APIClient`, suitable for user-facing mapping.
enum APIClientError: Error, Equatable {
    case invalidBaseURL
    case unauthorized
    case timeout
    case transport(code: Int)
    case unexpectedStatus(Int)
    case invalidResponse
}

/// Thin async HTTP client for the Habit Tracker backend.
/// Base URL and API key are injected so Settings can reconfigure it at runtime.
final class APIClient {
    static let apiKeyHeader = "X-API-Key"
    static let defaultTimeout: TimeInterval = 10

    private let baseURL: URL
    private let apiKeyProvider: () -> String?
    private let session: URLSession
    private let timeout: TimeInterval

    init(
        baseURL: URL,
        apiKeyProvider: @escaping () -> String?,
        session: URLSession = .shared,
        timeout: TimeInterval = APIClient.defaultTimeout
    ) {
        self.baseURL = baseURL
        self.apiKeyProvider = apiKeyProvider
        self.session = session
        self.timeout = timeout
    }

    /// Hits `GET /` (backend health/root endpoint). Throws a typed error on any failure.
    func checkConnection() async throws {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIClientError.invalidBaseURL
        }
        if components.path.isEmpty {
            components.path = "/"
        }
        guard let url = components.url else {
            throw APIClientError.invalidBaseURL
        }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        if let apiKey = apiKeyProvider() {
            request.setValue(apiKey, forHTTPHeaderField: Self.apiKeyHeader)
        }

        let response: URLResponse
        do {
            (_, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw APIClientError.timeout
        } catch let error as URLError {
            throw APIClientError.transport(code: error.errorCode)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIClientError.unauthorized
        default:
            throw APIClientError.unexpectedStatus(httpResponse.statusCode)
        }
    }
}
