import Foundation
import Combine
import ServiceManagement

@MainActor
final class SettingsStore: ObservableObject {
    @Published var refreshInterval: RefreshInterval
    @Published var iconStyle: IconStyle
    @Published var launchAtLogin: Bool
    @Published var launchError: String?

    var debugMenuEnabled: Bool {
        UserDefaults.standard.bool(forKey: "debugMenuEnabled")
    }

    init() {
        let defaults = UserDefaults.standard
        refreshInterval = RefreshInterval(rawValue: defaults.string(forKey: "refreshInterval") ?? "") ?? .tenMinutes
        iconStyle = IconStyle(rawValue: defaults.string(forKey: "iconStyle") ?? "") ?? .bitcoinSymbol
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
