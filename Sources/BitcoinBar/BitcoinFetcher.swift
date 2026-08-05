import Foundation

struct BitcoinFetcher: Sendable {
    private let baseURL = URL(string: "https://mempool.space/api")!
    private let v1URL = URL(string: "https://mempool.space/api/v1")!
    private let coinGeckoURL = URL(string: "https://api.coingecko.com/api/v3")!
    private let session: URLSession
    private let rateLimiter: HostRateLimiter

    init(session: URLSession? = nil, rateLimiter: HostRateLimiter = HostRateLimiter()) {
        self.rateLimiter = rateLimiter
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 15
            config.timeoutIntervalForResource = 20
            self.session = URLSession(configuration: config)
        }
    }

    func fetchSnapshot() async -> BitcoinSnapshot {
        async let block: BlockInfo? = fetchLatestBlock()
        async let mempool: MempoolStats? = fetchMempoolStats()
        async let priceData: (price: Double?, change: Double?, source: PriceSource?, details: PriceDetails?) = fetchPriceDetails()
        async let fees: FeesResponse? = fetchFees()
        async let difficulty: DifficultyAdjustment? = fetchDifficulty()

        let price = await priceData
        let snapshot = BitcoinSnapshot(
            block: await block,
            mempool: await mempool,
            priceUSD: price.price,
            priceChange24h: price.change,
            priceSource: price.source,
            priceDetails: price.details,
            fees: await fees,
            difficulty: await difficulty,
            fetchedAt: Date()
        )
        return snapshot
    }

    private func fetchLatestBlock() async -> BlockInfo? {
        let v1BlocksURL = v1URL.appendingPathComponent("blocks")
            .appending(queryItems: [URLQueryItem(name: "limit", value: "1")])
        if let blocks: [BlockInfo] = await fetchArray(BlockInfo.self, url: v1BlocksURL),
           let block = blocks.first {
            return block
        }

        let legacyURL = baseURL.appendingPathComponent("blocks")
            .appending(queryItems: [URLQueryItem(name: "limit", value: "1")])
        let blocks: [BlockInfo]? = await fetchArray(BlockInfo.self, url: legacyURL)
        return blocks?.first
    }

    private func fetchMempoolStats() async -> MempoolStats? {
        let url = baseURL.appendingPathComponent("mempool")
        return await fetch(url: url, as: MempoolStats.self)
    }

    private func fetchPriceDetails() async -> (price: Double?, change: Double?, source: PriceSource?, details: PriceDetails?) {
        if let detailsResponse: CoinGeckoCoinResponse = await fetchCoinGeckoDetails(),
           let marketData = detailsResponse.marketData,
           let priceUSD = marketData.currentPrice?["usd"] {
            let details = PriceDetails(
                currentPrice: marketData.currentPrice,
                change24h: marketData.priceChangePercentage24h,
                change7d: marketData.priceChangePercentage7d,
                change30d: marketData.priceChangePercentage30d,
                high24h: marketData.high24h?["usd"],
                low24h: marketData.low24h?["usd"],
                ath: marketData.ath?["usd"],
                athDate: parseISODate(marketData.athDate?["usd"]),
                atl: marketData.atl?["usd"],
                atlDate: parseISODate(marketData.atlDate?["usd"]),
                lastUpdated: parseISODate(marketData.lastUpdated),
                sparkline7d: marketData.sparkline7d?.price
            )
            return (priceUSD, marketData.priceChangePercentage24h, .coinGecko, details)
        }

        // Fallback to mempool.space (no extra details)
        let mempoolURL = v1URL.appendingPathComponent("prices")
        let mempoolResponse: PriceResponse? = await fetch(url: mempoolURL, as: PriceResponse.self)
        let source: PriceSource? = mempoolResponse?.usd == nil ? nil : .mempool
        return (mempoolResponse?.usd, nil, source, nil)
    }

    private func fetchCoinGeckoDetails() async -> CoinGeckoCoinResponse? {
        let url = coinGeckoURL.appendingPathComponent("coins/bitcoin")
            .appending(queryItems: [
                URLQueryItem(name: "localization", value: "false"),
                URLQueryItem(name: "tickers", value: "false"),
                URLQueryItem(name: "market_data", value: "true"),
                URLQueryItem(name: "community_data", value: "false"),
                URLQueryItem(name: "developer_data", value: "false"),
                URLQueryItem(name: "sparkline", value: "true")
            ])
        return await fetch(url: url, as: CoinGeckoCoinResponse.self)
    }

    private func parseISODate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatterWithFractional = ISO8601DateFormatter()
        formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatterWithFractional.date(from: value) {
            return date
        }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: value)
    }

    private func fetchFees() async -> FeesResponse? {
        if let recommended = await fetchFeesRecommended() {
            return recommended
        }
        return await fetchFeesFromMempoolBlocks()
    }

    private func fetchDifficulty() async -> DifficultyAdjustment? {
        let url = v1URL.appendingPathComponent("difficulty-adjustment")
        return await fetch(url: url, as: DifficultyAdjustment.self)
    }

    private func fetchFeesRecommended() async -> FeesResponse? {
        let url = v1URL.appendingPathComponent("fees/recommended")
        return await fetch(url: url, as: FeesResponse.self)
    }

    private func fetchFeesFromMempoolBlocks() async -> FeesResponse? {
        let url = v1URL.appendingPathComponent("fees/mempool-blocks")
        guard let blocks: [MempoolBlockFee] = await fetchArray(MempoolBlockFee.self, url: url),
              !blocks.isEmpty else {
            return nil
        }

        let fastest = blocks[0].medianFee
        let halfHour = blocks[min(2, blocks.count - 1)].medianFee
        let hour = blocks[min(5, blocks.count - 1)].medianFee
        return FeesResponse(
            fastestFee: roundedFee(fastest),
            halfHourFee: roundedFee(halfHour),
            hourFee: roundedFee(hour)
        )
    }

    private func fetchArray<T: Decodable>(_ type: T.Type, url: URL) async -> [T]? {
        guard let data = await fetchData(from: url) else { return nil }
        return try? JSONDecoder().decode([T].self, from: data)
    }

    private func fetch<T: Decodable>(url: URL, as type: T.Type) async -> T? {
        guard let data = await fetchData(from: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func fetchData(from url: URL) async -> Data? {
        guard let host = url.host,
              await rateLimiter.shouldStartRequest(to: host) else {
            return nil
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else { return nil }

            if http.statusCode == 429 {
                await rateLimiter.recordRateLimit(
                    for: host,
                    retryAfter: http.value(forHTTPHeaderField: "Retry-After")
                )
                return nil
            }

            guard 200..<300 ~= http.statusCode else { return nil }
            await rateLimiter.recordSuccess(for: host)
            return data
        } catch {
            return nil
        }
    }

    private func roundedFee(_ fee: Double) -> Double {
        (fee * 10).rounded(.toNearestOrAwayFromZero) / 10
    }
}

actor HostRateLimiter {
    typealias Jitter = @Sendable (ClosedRange<Double>) -> Double

    private struct LimitState {
        var consecutiveLimits: Int
        var blockedUntil: Date
    }

    private var states: [String: LimitState] = [:]
    private let jitter: Jitter

    init(jitter: @escaping Jitter = { Double.random(in: $0) }) {
        self.jitter = jitter
    }

    func shouldStartRequest(to host: String, now: Date = Date()) -> Bool {
        guard let state = states[host] else { return true }
        return now >= state.blockedUntil
    }

    func recordRateLimit(for host: String, retryAfter: String?, now: Date = Date()) {
        let consecutiveLimits = min((states[host]?.consecutiveLimits ?? 0) + 1, 5)
        let exponentialDelay = min(60 * pow(2, Double(consecutiveLimits - 1)), 15 * 60)
        let requestedDelay = RetryAfterParser.delay(from: retryAfter, now: now) ?? 0
        let baseDelay = max(exponentialDelay, requestedDelay)
        let jitterDelay = jitter(0...min(baseDelay * 0.2, 30))
        let blockedUntil = now.addingTimeInterval(baseDelay + jitterDelay)

        states[host] = LimitState(
            consecutiveLimits: consecutiveLimits,
            blockedUntil: max(states[host]?.blockedUntil ?? .distantPast, blockedUntil)
        )
    }

    func recordSuccess(for host: String, now: Date = Date()) {
        guard let state = states[host], now >= state.blockedUntil else { return }
        states.removeValue(forKey: host)
    }
}

enum RetryAfterParser {
    static func delay(from value: String?, now: Date) -> TimeInterval? {
        guard let value else { return nil }

        if let seconds = TimeInterval(value.trimmingCharacters(in: .whitespaces)), seconds >= 0 {
            return seconds
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let date = formatter.date(from: value) else { return nil }
        return max(0, date.timeIntervalSince(now))
    }
}

private extension URL {
    func appending(queryItems: [URLQueryItem]) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        components.queryItems = queryItems
        return components.url ?? self
    }
}
