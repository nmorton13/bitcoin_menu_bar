import Foundation
import Combine

@MainActor
final class BlockStore: ObservableObject {
    @Published var snapshot: BitcoinSnapshot?
    @Published var errorMessage: String?
    @Published var isFetching = false
    @Published var lastSuccessfulFetch: Date?
    @Published var isStale = false

    private let fetcher = BitcoinFetcher()
    private var refreshTask: Task<Void, Never>?
    private weak var settings: SettingsStore?
    private var cancellables = Set<AnyCancellable>()

    func attach(settings: SettingsStore) {
        self.settings = settings
        settings.$refreshInterval
            .sink { [weak self] _ in
                Task { @MainActor in self?.restartTimer() }
            }
            .store(in: &cancellables)
        Task { await refresh() }
        restartTimer()
    }

    func refresh() async {
        guard !isFetching else { return }
        isFetching = true
        errorMessage = nil
        let result = await fetchWithRetry()

        if let result {
            snapshot = result
            lastSuccessfulFetch = Date()
            isFetching = false
            updateStaleness()
        } else {
            snapshot = nil
            markError("Unable to load Bitcoin data.")
        }
    }

    func markError(_ message: String) {
        errorMessage = message
        isFetching = false
        updateStaleness()
    }

    private func restartTimer() {
        refreshTask?.cancel()
        guard let settings else { return }

        let intervalMinutes = settings.refreshInterval.minutes
        guard intervalMinutes > 0 else { return }

        refreshTask = Task { [weak self] in
            while let self {
                try? await Task.sleep(for: .seconds(intervalMinutes * 60))
                if Task.isCancelled { break }
                await self.refresh()
            }
        }
    }

    private func fetchWithRetry() async -> BitcoinSnapshot? {
        let delays: [Duration] = [.seconds(0), .seconds(1), .seconds(3)]

        for delay in delays {
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }

            let snapshot = await fetcher.fetchSnapshot()
            if snapshot.hasData {
                return snapshot
            }

            if Task.isCancelled { break }
        }

        return nil
    }

    private func updateStaleness() {
        guard let settings else {
            isStale = errorMessage != nil
            return
        }
        if errorMessage != nil {
            isStale = true
            return
        }
        guard let last = lastSuccessfulFetch else {
            isStale = true
            return
        }
        let budget = max(settings.refreshInterval.minutes * 60 * 1.5, 180)
        isStale = Date().timeIntervalSince(last) > budget
    }
}
