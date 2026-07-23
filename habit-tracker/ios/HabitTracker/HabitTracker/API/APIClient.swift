// [review:need-review] PHASE-01/05-ios-today-quick-entry
// summary: URLSession async/await HTTP client; /api/v1 JSON requests (categories, entries POST + checklist PUT) as TodayAPI
import Foundation

/// API surface needed by the Today screen; `APIClient` is the production implementation.
protocol TodayAPI {
    func fetchCategories() async throws -> [CategoryDTO]
    func fetchEntries(startDate: String, endDate: String) async throws -> [EntryDTO]
    func createEntry(_ entry: EntryCreateDTO) async throws -> EntryDTO
    func upsertChecklistEntry(_ payload: ChecklistUpsertDTO) async throws -> EntryDTO
}

/// Errors surfaced by `APIClient`, suitable for user-facing mapping.
enum APIClientError: Error, Equatable {
    case invalidBaseURL
    case unauthorized
    case timeout
    case transport(code: Int)
    case unexpectedStatus(Int)
    case invalidResponse
}

extension APIClientError {
    /// Human-readable message for surfacing the error in UI state.
    var userMessage: String {
        switch self {
        case .invalidBaseURL:
            return "Invalid server address"
        case .unauthorized:
            return "Invalid API key (401)"
        case .timeout:
            return "Connection timed out"
        case .transport(let code):
            return "Network error (\(code))"
        case .unexpectedStatus(let status):
            return "Server returned status \(status)"
        case .invalidResponse:
            return "Invalid server response"
        }
    }
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

    /// Parses a user-entered server address into a validated base URL.
    /// Single source of truth for Settings and Today so the rules never diverge.
    static func makeBaseURL(from address: String) -> URL? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil, url.host != nil else {
            return nil
        }
        return url
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
        _ = try await send(makeRequest(url: url, method: "GET"))
    }
}

// MARK: - TodayAPI (JSON endpoints under /api/v1)

extension APIClient: TodayAPI {
    static let apiV1Path = "/api/v1"

    func fetchCategories() async throws -> [CategoryDTO] {
        try await getJSON(path: "/categories", query: [])
    }

    func fetchEntries(startDate: String, endDate: String) async throws -> [EntryDTO] {
        try await getJSON(
            path: "/entries",
            query: [
                URLQueryItem(name: "start_date", value: startDate),
                URLQueryItem(name: "end_date", value: endDate),
            ]
        )
    }

    func createEntry(_ entry: EntryCreateDTO) async throws -> EntryDTO {
        try await sendJSON(path: "/entries", method: "POST", body: entry)
    }

    func upsertChecklistEntry(_ payload: ChecklistUpsertDTO) async throws -> EntryDTO {
        try await sendJSON(path: "/entries/checklist", method: "PUT", body: payload)
    }

    private func sendJSON<Body: Encodable, Response: Decodable>(
        path: String, method: String, body: Body
    ) async throws -> Response {
        let url = try makeAPIURL(path: path, query: [])
        var request = makeRequest(url: url, method: method)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try APIJSONCoding.makeEncoder().encode(body)
        let data = try await send(request)
        return try decodeJSON(data)
    }

    private func getJSON<T: Decodable>(path: String, query: [URLQueryItem]) async throws -> T {
        let url = try makeAPIURL(path: path, query: query)
        let data = try await send(makeRequest(url: url, method: "GET"))
        return try decodeJSON(data)
    }

    private func decodeJSON<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try APIJSONCoding.makeDecoder().decode(T.self, from: data)
        } catch {
            throw APIClientError.invalidResponse
        }
    }

    /// Builds `<baseURL>/api/v1<path>` preserving any path prefix in the base URL.
    private func makeAPIURL(path: String, query: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIClientError.invalidBaseURL
        }
        let basePath = components.path.hasSuffix("/")
            ? String(components.path.dropLast())
            : components.path
        components.path = basePath + Self.apiV1Path + path
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else {
            throw APIClientError.invalidBaseURL
        }
        return url
    }

    private func makeRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method
        if let apiKey = apiKeyProvider() {
            request.setValue(apiKey, forHTTPHeaderField: Self.apiKeyHeader)
        }
        return request
    }

    /// Executes the request, maps transport/status errors, returns the body on 2xx.
    @discardableResult
    private func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
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
            return data
        case 401:
            throw APIClientError.unauthorized
        default:
            throw APIClientError.unexpectedStatus(httpResponse.statusCode)
        }
    }
}
