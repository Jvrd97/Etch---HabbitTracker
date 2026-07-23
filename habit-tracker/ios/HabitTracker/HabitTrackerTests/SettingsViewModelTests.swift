// [review:need-review] PHASE-01/03-ios-scaffold-settings
// summary: unit tests for SettingsViewModel — Keychain-only key storage, connection state machine
import XCTest
@testable import HabitTracker

@MainActor
final class SettingsViewModelTests: XCTestCase {
    private static let defaultsSuite = "com.habittracker.tests.defaults"
    private let keychain = KeychainStore(service: "com.habittracker.tests.settings")
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        defaults = UserDefaults(suiteName: Self.defaultsSuite)
        defaults.removePersistentDomain(forName: Self.defaultsSuite)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: Self.defaultsSuite)
        try keychain.delete(SettingsViewModel.apiKeyKeychainKey)
        MockURLProtocol.requestHandler = nil
        try super.tearDownWithError()
    }

    private func makeViewModel() -> SettingsViewModel {
        SettingsViewModel(
            keychain: keychain,
            defaults: defaults,
            session: MockURLProtocol.makeSession()
        )
    }

    func testSaveStoresKeyInKeychainAndAddressInDefaults() throws {
        let viewModel = makeViewModel()
        viewModel.serverAddress = "http://100.64.0.1:8000"
        viewModel.apiKey = "super-secret"

        try viewModel.saveSettings()

        XCTAssertEqual(try keychain.read(SettingsViewModel.apiKeyKeychainKey), "super-secret")
        XCTAssertEqual(defaults.string(forKey: SettingsViewModel.serverAddressDefaultsKey), "http://100.64.0.1:8000")
        let persistedValues = defaults.persistentDomain(forName: Self.defaultsSuite)?.values.map { "\($0)" } ?? []
        XCTAssertFalse(persistedValues.contains("super-secret"), "API key must never reach UserDefaults")
    }

    func testInitLoadsPersistedValues() throws {
        try keychain.save("stored-key", for: SettingsViewModel.apiKeyKeychainKey)
        defaults.set("http://10.0.0.5:8000", forKey: SettingsViewModel.serverAddressDefaultsKey)

        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.apiKey, "stored-key")
        XCTAssertEqual(viewModel.serverAddress, "http://10.0.0.5:8000")
    }

    func testCheckConnectionSuccess() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("{}".utf8))
        }
        let viewModel = makeViewModel()
        viewModel.serverAddress = "http://127.0.0.1:8000"
        viewModel.apiKey = "k"

        await viewModel.checkConnection()

        XCTAssertEqual(viewModel.connectionState, .success)
    }

    func testCheckConnectionUnauthorizedReportsFailure() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let viewModel = makeViewModel()
        viewModel.serverAddress = "http://127.0.0.1:8000"

        await viewModel.checkConnection()

        guard case .failure = viewModel.connectionState else {
            XCTFail("Expected .failure, got \(viewModel.connectionState)")
            return
        }
    }

    func testCheckConnectionRejectsInvalidAddress() async {
        let viewModel = makeViewModel()
        viewModel.serverAddress = "not a url"

        await viewModel.checkConnection()

        guard case .failure = viewModel.connectionState else {
            XCTFail("Expected .failure, got \(viewModel.connectionState)")
            return
        }
    }
}
