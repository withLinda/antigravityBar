import XCTest
@testable import AntigravityBar

final class AccountDisclosureStoreTests: XCTestCase {
    func testDefaultsToExpandedWhenNoValueWasSaved() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = AccountDisclosureStore(defaults: defaults)

        XCTAssertTrue(store.isExpanded(email: "person@example.com"))
    }

    func testPersistsCollapsedStatePerEmail() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = AccountDisclosureStore(defaults: defaults)

        store.setExpanded(false, for: "person@example.com")

        let reloaded = AccountDisclosureStore(defaults: defaults)
        XCTAssertFalse(reloaded.isExpanded(email: "person@example.com"))
        XCTAssertTrue(reloaded.isExpanded(email: "other@example.com"))
    }
}
