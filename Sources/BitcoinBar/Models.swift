import Foundation

enum IconStyle: String, CaseIterable, Identifiable {
    case bitcoinSymbol
    case blockHeight

    var id: String { rawValue }
    var label: String {
        switch self {
        case .bitcoinSymbol:
            return "Bitcoin Symbol"
        case .blockHeight:
            return "Block Height"
        }
    }
}

enum RefreshInterval: String, CaseIterable, Identifiable {
    case manual
    case fiveMinutes
    case tenMinutes
    case fifteenMinutes

    var id: String { rawValue }
    var minutes: Double {
        switch self {
        case .manual: return 0
        case .fiveMinutes: return 5
        case .tenMinutes: return 10
        case .fifteenMinutes: return 15
        }
    }

    var label: String {
        switch self {
        case .manual: return "Manual"
        case .fiveMinutes: return "Every 5 minutes"
        case .tenMinutes: return "Every 10 minutes"
        case .fifteenMinutes: return "Every 15 minutes"
        }
    }
}

struct BlockInfo: Decodable {
    let id: String
    let height: Int
    let timestamp: TimeInterval
    let txCount: Int
    let size: Int
    let weight: Int
    let difficulty: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case height
        case timestamp
        case txCount = "tx_count"
        case size
        case weight
        case difficulty
    }
}

struct MempoolStats: Decodable {
    let count: Int
    let vsize: Int
}

struct PriceResponse: Decodable {
    let usd: Double?

    enum CodingKeys: String, CodingKey {
        case usd = "USD"
    }
}

struct FeesResponse: Decodable {
    let fastestFee: Int
    let halfHourFee: Int
    let hourFee: Int
}

struct DifficultyAdjustment: Decodable {
    let progressPercent: Double?
    let remainingBlocks: Int?
    let estimatedRetargetDate: TimeInterval?
    let estimatedDifficultyDelta: Double?
    let averageBlockTime: Double?

    enum CodingKeys: String, CodingKey {
        case progressPercent
        case remainingBlocks
        case estimatedRetargetDate
        case estimatedDifficultyDelta = "difficultyChange"
        case averageBlockTime = "timeAvg"
    }
}

struct BitcoinSnapshot {
    var block: BlockInfo?
    var mempool: MempoolStats?
    var priceUSD: Double?
    var fees: FeesResponse?
    var difficulty: DifficultyAdjustment?
    var fetchedAt: Date

    var hasData: Bool {
        block != nil || mempool != nil || priceUSD != nil || fees != nil || difficulty != nil
    }

    var satsPerDollar: Int? {
        guard let priceUSD else { return nil }
        let sats = 100_000_000 / priceUSD
        return Int(sats.rounded())
    }
}
