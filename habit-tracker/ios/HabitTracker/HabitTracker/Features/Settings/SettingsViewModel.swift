// [review:need-review] PHASE-01/05-ios-today-quick-entry
// summary: Settings state — server address in UserDefaults, API key in Keychain; base URL parsing via APIClient.makeBaseURL
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

        guard let baseURL = APIClient.makeBaseURL(from: serverAddress) else {
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
            connectionState = .failure(error.userMessage)
        } catch {
            connectionState = .failure("Unexpected error")
        }
    }
}
