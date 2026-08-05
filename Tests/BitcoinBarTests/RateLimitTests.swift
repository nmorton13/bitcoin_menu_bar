import Foundation
import XCTest
@testable import BitcoinBar

final class RateLimitTests: XCTestCase {
    func testRetryAfterParsesSeconds() {
        let now = Date(timeIntervalSince1970: 1_000)

        XCTAssertEqual(RetryAfterParser.delay(from: "120", now: now), 120)
    }

    func testRetryAfterParsesHTTPDate() {
        let now = Date(timeIntervalSince1970: 784_111_777)

        XCTAssertEqual(
            RetryAfterParser.delay(from: "Sun, 06 Nov 1994 08:51:37 GMT", now: now),
            120
        )
    }

    func testRateLimiterUsesExponentialCooldownAndResetsAfterSuccess() async {
        let limiter = HostRateLimiter(jitter: { _ in 0 })
        let host = "api.example.com"
        let start = Date(timeIntervalSince1970: 10_000)

        await limiter.recordRateLimit(for: host, retryAfter: nil, now: start)
        let allowedBeforeFirstCooldown = await limiter.shouldStartRequest(
            to: host,
            now: start.addingTimeInterval(59)
        )
        let allowedAfterFirstCooldown = await limiter.shouldStartRequest(
            to: host,
            now: start.addingTimeInterval(60)
        )
        XCTAssertFalse(allowedBeforeFirstCooldown)
        XCTAssertTrue(allowedAfterFirstCooldown)

        let secondLimit = start.addingTimeInterval(60)
        await limiter.recordRateLimit(for: host, retryAfter: nil, now: secondLimit)
        let allowedBeforeSecondCooldown = await limiter.shouldStartRequest(
            to: host,
            now: secondLimit.addingTimeInterval(119)
        )
        let allowedAfterSecondCooldown = await limiter.shouldStartRequest(
            to: host,
            now: secondLimit.addingTimeInterval(120)
        )
        XCTAssertFalse(allowedBeforeSecondCooldown)
        XCTAssertTrue(allowedAfterSecondCooldown)

        let recovered = secondLimit.addingTimeInterval(120)
        await limiter.recordSuccess(for: host, now: recovered)
        await limiter.recordRateLimit(for: host, retryAfter: nil, now: recovered)
        let allowedAfterResetCooldown = await limiter.shouldStartRequest(
            to: host,
            now: recovered.addingTimeInterval(60)
        )
        XCTAssertTrue(allowedAfterResetCooldown)
    }

    func testRetryAfterCanExtendExponentialCooldown() async {
        let limiter = HostRateLimiter(jitter: { _ in 0 })
        let start = Date(timeIntervalSince1970: 20_000)

        await limiter.recordRateLimit(for: "api.example.com", retryAfter: "300", now: start)

        let allowedBeforeRetryAfter = await limiter.shouldStartRequest(
            to: "api.example.com",
            now: start.addingTimeInterval(299)
        )
        let allowedAfterRetryAfter = await limiter.shouldStartRequest(
            to: "api.example.com",
            now: start.addingTimeInterval(300)
        )
        XCTAssertFalse(allowedBeforeRetryAfter)
        XCTAssertTrue(allowedAfterRetryAfter)
    }
}
