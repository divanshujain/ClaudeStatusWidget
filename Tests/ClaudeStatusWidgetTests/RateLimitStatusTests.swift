import XCTest
@testable import ClaudeStatusWidget

final class RateLimitStatusTests: XCTestCase {
    func testSafeStatus() {
        let now = Date().timeIntervalSince1970
        let window = RateLimitWindow(usedPercentage: 20.0, resetsAt: now + 10800)
        let status = RateLimitCalculator.status(for: window, windowDuration: 18000, now: now)

        XCTAssertEqual(status.severity, .safe)
        XCTAssertTrue(status.burnRate < 10.0)
        XCTAssertTrue(status.resetCountdown > 0)
        XCTAssertTrue(status.label.contains("safe"))
    }

    func testDangerStatus() {
        let now = Date().timeIntervalSince1970
        let window = RateLimitWindow(usedPercentage: 85.0, resetsAt: now + 14400)
        let status = RateLimitCalculator.status(for: window, windowDuration: 18000, now: now)

        XCTAssertEqual(status.severity, .danger)
    }

    func testModerateStatus() {
        let now = Date().timeIntervalSince1970
        let window = RateLimitWindow(usedPercentage: 55.0, resetsAt: now + 7200)
        let status = RateLimitCalculator.status(for: window, windowDuration: 18000, now: now)

        XCTAssertNotEqual(status.severity, .danger)
    }

    func testFormatDuration() {
        XCTAssertEqual(RateLimitCalculator.formatDuration(3661), "1h 1m")
        XCTAssertEqual(RateLimitCalculator.formatDuration(90000), "1d 1h")
        XCTAssertEqual(RateLimitCalculator.formatDuration(300), "5m")
        XCTAssertEqual(RateLimitCalculator.formatDuration(0), "now")
    }
}
