import Foundation

struct BitcoinFetcher {
    private let baseURL = URL(string: "https://mempool.space/api")!
    private let v1URL = URL(string: "https://mempool.space/api/v1")!
    private let coinGeckoURL = URL(string: "https://api.coingecko.com/api/v3")!
    private let session: URLSession

    init(session: URLSession? = nil) {
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
        async let priceData: (price: Double?, change: Double?, source: PriceSource?) = fetchPriceWithChange()
        async let fees: FeesResponse? = fetchFees()
        async let difficulty: DifficultyAdjustment? = fetchDifficulty()

        let price = await priceData
        let snapshot = BitcoinSnapshot(
            block: await block,
            mempool: await mempool,
            priceUSD: price.price,
            priceChange24h: price.change,
            priceSource: price.source,
            fees: await fees,
            difficulty: await difficulty,
            fetchedAt: Date()
        )
        return snapshot
    }

    private func fetchLatestBlock() async -> BlockInfo? {
        let url = baseURL.appendingPathComponent("blocks")
            .appending(queryItems: [URLQueryItem(name: "limit", value: "1")])
        let blocks: [BlockInfo]? = await fetchArray(BlockInfo.self, url: url)
        return blocks?.first
    }

    private func fetchMempoolStats() async -> MempoolStats? {
        let url = baseURL.appendingPathComponent("mempool")
        return await fetch(url: url, as: MempoolStats.self)
    }

    private func fetchPriceWithChange() async -> (price: Double?, change: Double?, source: PriceSource?) {
        // Try CoinGecko first for 24h change
        let url = coinGeckoURL.appendingPathComponent("simple/price")
            .appending(queryItems: [
                URLQueryItem(name: "ids", value: "bitcoin"),
                URLQueryItem(name: "vs_currencies", value: "usd"),
                URLQueryItem(name: "include_24hr_change", value: "true")
            ])

        if let response: CoinGeckoResponse = await fetch(url: url, as: CoinGeckoResponse.self),
           let bitcoin = response.bitcoin {
            return (bitcoin.usd, bitcoin.usd24hChange, .coinGecko)
        }

        // Fallback to mempool.space (no 24h change)
        let mempoolURL = v1URL.appendingPathComponent("prices")
        let mempoolResponse: PriceResponse? = await fetch(url: mempoolURL, as: PriceResponse.self)
        let source: PriceSource? = mempoolResponse?.usd == nil ? nil : .mempool
        return (mempoolResponse?.usd, nil, source)
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
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                return nil
            }
            return try JSONDecoder().decode([T].self, from: data)
        } catch {
            return nil
        }
    }

    private func fetch<T: Decodable>(url: URL, as type: T.Type) async -> T? {
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                return nil
            }
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            return nil
        }
    }

    private func roundedFee(_ fee: Double) -> Double {
        (fee * 10).rounded(.toNearestOrAwayFromZero) / 10
    }
}

private extension URL {
    func appending(queryItems: [URLQueryItem]) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        components.queryItems = queryItems
        return components.url ?? self
    }
}
