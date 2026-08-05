import Foundation
import XCTest
@testable import BitcoinBar

@MainActor
final class BlockStoreTests: XCTestCase {
    func testRefreshPreservesFieldsMissingFromPartialResponse() async {
        let responses = SnapshotResponses([
            BitcoinSnapshot(
                block: nil,
                mempool: MempoolStats(count: 10, vsize: 20),
                priceUSD: 60_000,
                priceChange24h: 1,
                priceSource: .coinGecko,
                priceDetails: PriceDetails(
                    currentPrice: ["usd": 60_000],
                    change24h: 1,
                    change7d: 2,
                    change30d: 3,
                    high24h: nil,
                    low24h: nil,
                    ath: nil,
                    athDate: nil,
                    atl: nil,
                    atlDate: nil,
                    lastUpdated: nil,
                    sparkline7d: nil
                ),
                fees: FeesResponse(fastestFee: 5, halfHourFee: 3, hourFee: 1),
                difficulty: nil,
                fetchedAt: Date(timeIntervalSince1970: 100)
            ),
            BitcoinSnapshot(
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
        ])
        let store = BlockStore(fetchSnapshot: { await responses.next() })

        await store.refresh()
        await store.refresh()

        XCTAssertEqual(store.snapshot?.priceUSD, 61_000)
        XCTAssertEqual(store.snapshot?.priceSource, .mempool)
        XCTAssertNil(store.snapshot?.priceChange24h)
        XCTAssertNil(store.snapshot?.priceDetails)
        XCTAssertEqual(store.snapshot?.mempool?.count, 10)
        XCTAssertEqual(store.snapshot?.fees?.fastestFee, 5)
        XCTAssertEqual(store.snapshot?.fetchedAt, Date(timeIntervalSince1970: 200))
    }
}

private actor SnapshotResponses {
    private var snapshots: [BitcoinSnapshot]

    init(_ snapshots: [BitcoinSnapshot]) {
        self.snapshots = snapshots
    }

    func next() -> BitcoinSnapshot {
        snapshots.removeFirst()
    }
}
