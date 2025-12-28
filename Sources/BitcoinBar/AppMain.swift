import SwiftUI

@main
struct BitcoinBarApp: App {
    @StateObject private var store: BlockStore
    @StateObject private var settings: SettingsStore
    @State private var isInserted = true

    init() {
        let settings = SettingsStore()
        let store = BlockStore()
        store.attach(settings: settings)
        _settings = StateObject(wrappedValue: settings)
        _store = StateObject(wrappedValue: store)
    }

    var body: some Scene {
        MenuBarExtra(isInserted: $isInserted) {
            BitcoinMenuView(store: store, settings: settings)
        } label: {
            IconView(
                snapshot: store.snapshot,
                isStale: store.isStale,
                settings: settings
            )
        }
        .menuBarExtraStyle(.window)
        Settings {
            EmptyView()
        }
    }
}
