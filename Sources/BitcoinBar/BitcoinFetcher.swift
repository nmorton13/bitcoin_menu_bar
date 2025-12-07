import Foundation

struct BitcoinFetcher {
    private let baseURL = URL(string: "https://mempool.space/api")!
    private let v1URL = URL(string: "https://mempool.space/api/v1")!
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
        async let price: Double? = fetchPrice()
        async let fees: FeesResponse? = fetchFees()
        async let difficulty: DifficultyAdjustment? = fetchDifficulty()

        let snapshot = BitcoinSnapshot(
            block: await block,
            mempool: await mempool,
            priceUSD: await price,
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

    private func fetchPrice() async -> Double? {
        let url = v1URL.appendingPathComponent("prices")
        let response: PriceResponse? = await fetch(url: url, as: PriceResponse.self)
        return response?.usd
    }

    private func fetchFees() async -> FeesResponse? {
        let url = v1URL.appendingPathComponent("fees/recommended")
        return await fetch(url: url, as: FeesResponse.self)
    }

    private func fetchDifficulty() async -> DifficultyAdjustment? {
        let url = v1URL.appendingPathComponent("difficulty-adjustment")
        return await fetch(url: url, as: DifficultyAdjustment.self)
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
}

private extension URL {
    func appending(queryItems: [URLQueryItem]) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        components.queryItems = queryItems
        return components.url ?? self
    }
}
