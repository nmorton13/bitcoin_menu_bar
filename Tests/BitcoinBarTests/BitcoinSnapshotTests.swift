import Foundation
import XCTest
@testable import BitcoinBar

final class BitcoinSnapshotTests: XCTestCase {
    func testPreservingMissingValuesRetainsPriorFieldsAndUsesFreshValues() {
        let oldDate = Date(timeIntervalSince1970: 100)
        let newDate = Date(timeIntervalSince1970: 200)
        let previous = BitcoinSnapshot(
            block: block(height: 100),
            mempool: MempoolStats(count: 10, vsize: 20),
            priceUSD: 60_000,
            priceChange24h: 1.5,
            priceSource: .coinGecko,
            priceDetails: priceDetails(price: 60_000),
            fees: FeesResponse(fastestFee: 5, halfHourFee: 3, hourFee: 1),
            difficulty: nil,
            fetchedAt: oldDate
        )
        let partial = BitcoinSnapshot(
            block: block(height: 101),
            mempool: nil,
            priceUSD: nil,
            priceChange24h: nil,
            priceSource: nil,
            priceDetails: nil,
            fees: nil,
            difficulty: DifficultyAdjustment(
                progressPercent: 50,
                remainingBlocks: 1_000,
                estimatedRetargetDate: nil,
                estimatedDifficultyDelta: 2,
                averageBlockTime: nil
            ),
            fetchedAt: newDate
        )

        let merged = partial.preservingMissingValues(from: previous)

        XCTAssertEqual(merged.block?.height, 101)
        XCTAssertEqual(merged.mempool?.count, 10)
        XCTAssertEqual(merged.priceUSD, 60_000)
        XCTAssertEqual(merged.priceChange24h, 1.5)
        XCTAssertEqual(merged.priceSource, .coinGecko)
        XCTAssertEqual(merged.priceDetails?.currentPrice?["usd"], 60_000)
        XCTAssertEqual(merged.fees?.fastestFee, 5)
        XCTAssertEqual(merged.difficulty?.progressPercent, 50)
        XCTAssertEqual(merged.fetchedAt, newDate)
    }

    func testFreshPriceReplacesEntirePriorPricePayload() {
        let previous = BitcoinSnapshot(
            block: nil,
            mempool: nil,
            priceUSD: 60_000,
            priceChange24h: 1.5,
            priceSource: .coinGecko,
            priceDetails: priceDetails(price: 60_000),
            fees: nil,
            difficulty: nil,
            fetchedAt: Date(timeIntervalSince1970: 100)
        )
        let fallbackPrice = BitcoinSnapshot(
            block: nil,
            mempool: nil,
            priceUSD: 61_000,
            priceChange24h: nil,
            priceSource: .mempool,
            priceDetails: nil,
            fees: nil,
            difficulty: nil,
            fetchedAt: Date(timeIntervalSince1970: 200)
        )

        let merged = fallbackPrice.preservingMissingValues(from: previous)

        XCTAssertEqual(merged.priceUSD, 61_000)
        XCTAssertEqual(merged.priceSource, .mempool)
        XCTAssertNil(merged.priceChange24h)
        XCTAssertNil(merged.priceDetails)
    }

    func testBlockExtrasDecodesLegacyKeysAndStringPool() throws {
        let data = Data(#"""
        {
          "fee_range": [1.0, 2.5],
          "median_fee": 1.5,
          "total_fees": 12500000,
          "subsidy": 312500000,
          "miner": "Example Pool"
        }
        """#.utf8)

        let extras = try JSONDecoder().decode(BlockExtras.self, from: data)

        XCTAssertEqual(extras.feeRange ?? [], [1.0, 2.5])
        XCTAssertEqual(extras.medianFee, 1.5)
        XCTAssertEqual(extras.totalFeesBTC, 0.125)
        XCTAssertEqual(extras.rewardBTC, 3.125)
        XCTAssertEqual(extras.poolName, "Example Pool")
    }

    private func block(height: Int) -> BlockInfo {
        BlockInfo(
            id: "block-\(height)",
            height: height,
            timestamp: 0,
            txCount: 1,
            size: 1,
            weight: 1,
            difficulty: nil,
            extras: nil
        )
    }

    private func priceDetails(price: Double) -> PriceDetails {
        PriceDetails(
            currentPrice: ["usd": price],
            change24h: 1.5,
            change7d: 2,
            change30d: 3,
            high24h: price + 1,
            low24h: price - 1,
            ath: nil,
            athDate: nil,
            atl: nil,
            atlDate: nil,
            lastUpdated: nil,
            sparkline7d: [price]
        )
    }
}
