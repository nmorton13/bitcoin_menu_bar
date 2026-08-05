import Foundation
import Combine
import ServiceManagement

@MainActor
protocol LaunchAtLoginServicing {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

@MainActor
struct SystemLaunchAtLoginService: LaunchAtLoginServicing {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var refreshInterval: RefreshInterval
    @Published var iconStyle: IconStyle
    @Published var fiatCurrency: FiatCurrency
    @Published var launchAtLogin: Bool
    @Published var launchError: String?

    private let defaults: UserDefaults
    private let launchAtLoginService: any LaunchAtLoginServicing

    var debugMenuEnabled: Bool {
        defaults.bool(forKey: "debugMenuEnabled")
    }

    init(
        defaults: UserDefaults = .standard,
        launchAtLoginService: any LaunchAtLoginServicing = SystemLaunchAtLoginService()
    ) {
        self.defaults = defaults
        self.launchAtLoginService = launchAtLoginService
        refreshInterval = RefreshInterval(rawValue: defaults.string(forKey: "refreshInterval") ?? "") ?? .tenMinutes
        iconStyle = IconStyle(rawValue: defaults.string(forKey: "iconStyle") ?? "") ?? .bitcoinSymbol
        fiatCurrency = FiatCurrency(rawValue: defaults.string(forKey: "fiatCurrency") ?? "") ?? .usd
        launchAtLogin = launchAtLoginService.isEnabled
        defaults.set(launchAtLogin, forKey: "launchAtLogin")
    }

    func setRefreshInterval(_ value: RefreshInterval) {
        refreshInterval = value
        defaults.set(value.rawValue, forKey: "refreshInterval")
    }

    func setIconStyle(_ value: IconStyle) {
        iconStyle = value
        defaults.set(value.rawValue, forKey: "iconStyle")
    }

    func cycleFiatCurrency() {
        let list = FiatCurrency.major
        guard let index = list.firstIndex(of: fiatCurrency) else {
            setFiatCurrency(.usd)
            return
        }
        let next = list[(index + 1) % list.count]
        setFiatCurrency(next)
    }

    func setFiatCurrency(_ value: FiatCurrency) {
        fiatCurrency = value
        defaults.set(value.rawValue, forKey: "fiatCurrency")
    }

    func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLoginService.setEnabled(enabled)
            launchError = nil
        } catch {
            launchError = error.localizedDescription
        }
        launchAtLogin = launchAtLoginService.isEnabled
        defaults.set(launchAtLogin, forKey: "launchAtLogin")
    }
}
