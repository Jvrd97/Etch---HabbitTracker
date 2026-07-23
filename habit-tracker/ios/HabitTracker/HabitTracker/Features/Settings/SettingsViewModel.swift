// [review:need-review] PHASE-01/03-ios-scaffold-settings
// summary: Settings state — server address in UserDefaults, API key in Keychain, connection check state machine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    /// Discriminated connection-check state for the UI indicator.
    enum ConnectionState: Equatable {
        case idle
        case checking
        case success
        case failure(String)
    }

    static let serverAddressDefaultsKey = "server_address"
    static let apiKeyKeychainKey = "api-key"

    @Published var serverAddress: String
    @Published var apiKey: String
    @Published private(set) var connectionState: ConnectionState = .idle

    private let keychain: KeychainStore
    private let defaults: UserDefaults
    private let session: URLSession

    init(
        keychain: KeychainStore = KeychainStore(),
        defaults: UserDefaults = .standard,
        session: URLSession = .shared
    ) {
        self.keychain = keychain
        self.defaults = defaults
        self.session = session
        self.serverAddress = defaults.string(forKey: Self.serverAddressDefaultsKey) ?? ""
        self.apiKey = (try? keychain.read(Self.apiKeyKeychainKey)) ?? ""
    }

    /// Persists the server address to UserDefaults and the API key to the Keychain only.
    func saveSettings() throws {
        defaults.set(serverAddress, forKey: Self.serverAddressDefaultsKey)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedKey.isEmpty {
            try keychain.delete(Self.apiKeyKeychainKey)
        } else {
            try keychain.save(trimmedKey, for: Self.apiKeyKeychainKey)
        }
    }

    /// Saves current settings, then pings `GET /` on the configured server.
    func checkConnection() async {
        connectionState = .checking
        do {
            try saveSettings()
        } catch {
            connectionState = .failure("Failed to save settings")
            return
        }

        let trimmedAddress = serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let baseURL = URL(string: trimmedAddress), baseURL.scheme != nil, baseURL.host != nil else {
            connectionState = .failure("Invalid server address")
            return
        }

        let keychain = self.keychain
        let client = APIClient(
            baseURL: baseURL,
            apiKeyProvider: { try? keychain.read(Self.apiKeyKeychainKey) },
            session: session
        )
        do {
            try await client.checkConnection()
            connectionState = .success
        } catch let error as APIClientError {
            connectionState = .failure(Self.message(for: error))
        } catch {
            connectionState = .failure("Unexpected error")
        }
    }

    private static func message(for error: APIClientError) -> String {
        switch error {
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
