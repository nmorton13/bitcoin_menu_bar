import Foundation
import XCTest
@testable import BitcoinBar

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testInitializationUsesAndPersistsActualLaunchStatus() {
        let defaults = makeDefaults()
        defaults.set(false, forKey: "launchAtLogin")
        let service = TestLaunchAtLoginService(isEnabled: true)

        let store = SettingsStore(defaults: defaults, launchAtLoginService: service)

        XCTAssertTrue(store.launchAtLogin)
        XCTAssertTrue(defaults.bool(forKey: "launchAtLogin"))
    }

    func testTogglePersistsActualStatusAfterServiceError() {
        let defaults = makeDefaults()
        let service = TestLaunchAtLoginService(isEnabled: false)
        service.error = TestError.failed
        let store = SettingsStore(defaults: defaults, launchAtLoginService: service)

        store.toggleLaunchAtLogin(true)

        XCTAssertFalse(store.launchAtLogin)
        XCTAssertFalse(defaults.bool(forKey: "launchAtLogin"))
        XCTAssertNotNil(store.launchError)
    }

    func testSuccessfulEnableCallsServicePersistsActualStateAndClearsError() {
        let defaults = makeDefaults()
        let service = TestLaunchAtLoginService(isEnabled: false)
        let store = SettingsStore(defaults: defaults, launchAtLoginService: service)
        store.launchError = "Previous error"

        store.toggleLaunchAtLogin(true)

        XCTAssertEqual(service.requests, [true])
        XCTAssertTrue(store.launchAtLogin)
        XCTAssertTrue(defaults.bool(forKey: "launchAtLogin"))
        XCTAssertNil(store.launchError)
    }

    func testSuccessfulDisableCallsServicePersistsActualStateAndClearsError() {
        let defaults = makeDefaults()
        let service = TestLaunchAtLoginService(isEnabled: true)
        let store = SettingsStore(defaults: defaults, launchAtLoginService: service)
        store.launchError = "Previous error"

        store.toggleLaunchAtLogin(false)

        XCTAssertEqual(service.requests, [false])
        XCTAssertFalse(store.launchAtLogin)
        XCTAssertFalse(defaults.bool(forKey: "launchAtLogin"))
        XCTAssertNil(store.launchError)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "BitcoinBarTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }
}

@MainActor
private final class TestLaunchAtLoginService: LaunchAtLoginServicing {
    var isEnabled: Bool
    var error: Error?
    private(set) var requests: [Bool] = []

    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    func setEnabled(_ enabled: Bool) throws {
        requests.append(enabled)
        if let error { throw error }
        isEnabled = enabled
    }
}

private enum TestError: Error {
    case failed
}
