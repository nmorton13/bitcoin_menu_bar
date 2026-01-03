import Foundation
import Combine
import ServiceManagement

@MainActor
final class SettingsStore: ObservableObject {
    @Published var refreshInterval: RefreshInterval
    @Published var iconStyle: IconStyle
    @Published var fiatCurrency: FiatCurrency
    @Published var launchAtLogin: Bool
    @Published var launchError: String?

    var debugMenuEnabled: Bool {
        UserDefaults.standard.bool(forKey: "debugMenuEnabled")
    }

    init() {
        let defaults = UserDefaults.standard
        refreshInterval = RefreshInterval(rawValue: defaults.string(forKey: "refreshInterval") ?? "") ?? .tenMinutes
        iconStyle = IconStyle(rawValue: defaults.string(forKey: "iconStyle") ?? "") ?? .bitcoinSymbol
        fiatCurrency = FiatCurrency(rawValue: defaults.string(forKey: "fiatCurrency") ?? "") ?? .usd
        launchAtLogin = defaults.bool(forKey: "launchAtLogin")
    }

    func setRefreshInterval(_ value: RefreshInterval) {
        refreshInterval = value
        UserDefaults.standard.set(value.rawValue, forKey: "refreshInterval")
    }

    func setIconStyle(_ value: IconStyle) {
        iconStyle = value
        UserDefaults.standard.set(value.rawValue, forKey: "iconStyle")
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
        UserDefaults.standard.set(value.rawValue, forKey: "fiatCurrency")
    }

    func toggleLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled
        UserDefaults.standard.set(enabled, forKey: "launchAtLogin")
        Task { await configureLaunchAtLogin(enabled) }
    }

    private func configureLaunchAtLogin(_ enabled: Bool) async {
        do {
            if enabled {
                try await SMAppService.mainApp.register()
            } else {
                try await SMAppService.mainApp.unregister()
            }
            launchError = nil
        } catch {
            launchError = error.localizedDescription
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
