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
    private var stalenessTask: Task<Void, Never>?
    private weak var settings: SettingsStore?
    private var cancellables = Set<AnyCancellable>()
    private var lastPriceChange24h: Double?

    deinit {
        refreshTask?.cancel()
        stalenessTask?.cancel()
    }

    func attach(settings: SettingsStore) {
        self.settings = settings
        settings.$refreshInterval
            .sink { [weak self] _ in
                Task { @MainActor in self?.restartTimer() }
            }
            .store(in: &cancellables)
        Task { await refresh() }
        restartTimer()
        startStalenessTimer()
    }

    func refresh() async {
        guard !isFetching else { return }
        isFetching = true
        errorMessage = nil
        let result = await fetchWithRetry()

        if let result {
            if let change = result.priceChange24h {
                lastPriceChange24h = change
                snapshot = result
            } else if let lastChange = lastPriceChange24h {
                var updated = result
                updated.priceChange24h = lastChange
                snapshot = updated
            } else {
                snapshot = result
            }
            lastSuccessfulFetch = Date()
            isFetching = false
            updateStaleness()
        } else {
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
        refreshTask = nil

        guard let settings else { return }
        let intervalSeconds = settings.refreshInterval.minutes * 60
        guard intervalSeconds > 0 else { return }

        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(intervalSeconds))
                guard !Task.isCancelled else { break }
                await self.refresh()
            }
        }
    }

    private func startStalenessTimer() {
        stalenessTask?.cancel()
        stalenessTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self.updateStaleness()
                }
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
