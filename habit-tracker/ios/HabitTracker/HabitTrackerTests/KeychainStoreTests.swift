// [review:need-review] PHASE-01/03-ios-scaffold-settings
// summary: unit tests for KeychainStore — round-trip, overwrite, delete, missing key
import XCTest
@testable import HabitTracker

final class KeychainStoreTests: XCTestCase {
    private let store = KeychainStore(service: "com.habittracker.tests")
    private let key = "api-key"

    override func tearDownWithError() throws {
        try store.delete(key)
        try super.tearDownWithError()
    }

    func testSaveThenReadRoundTrip() throws {
        try store.save("secret-123", for: key)
        XCTAssertEqual(try store.read(key), "secret-123")
    }

    func testSaveOverwritesExistingValue() throws {
        try store.save("old-value", for: key)
        try store.save("new-value", for: key)
        XCTAssertEqual(try store.read(key), "new-value")
    }

    func testReadMissingKeyReturnsNil() throws {
        XCTAssertNil(try store.read("never-written"))
    }

    func testDeleteRemovesValue() throws {
        try store.save("to-be-deleted", for: key)
        try store.delete(key)
        XCTAssertNil(try store.read(key))
    }

    func testDeleteMissingKeyDoesNotThrow() throws {
        XCTAssertNoThrow(try store.delete("never-written"))
    }
}
