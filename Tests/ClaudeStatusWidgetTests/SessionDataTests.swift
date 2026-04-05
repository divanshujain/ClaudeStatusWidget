import XCTest
@testable import ClaudeStatusWidget

final class SessionDataTests: XCTestCase {
    let sampleJSON = """
    {
        "session_id": "abc123",
        "pid": 12345,
        "folder_name": "MyProject",
        "folder_path": "/Users/test/MyProject",
        "model": "Opus",
        "context": {
            "used_tokens": 670000,
            "total_tokens": 1000000,
            "used_percentage": 67
        },
        "rate_limits": {
            "five_hour": {
                "used_percentage": 42.0,
                "resets_at": 1738425600
            },
            "seven_day": {
                "used_percentage": 18.0,
                "resets_at": 1738857600
            }
        },
        "cost_usd": 0.42,
        "lines_added": 156,
        "lines_removed": 23,
        "timestamp": 1738420000
    }
    """.data(using: .utf8)!

    func testDecodesFullJSON() throws {
        let session = try JSONDecoder().decode(SessionData.self, from: sampleJSON)
        XCTAssertEqual(session.sessionId, "abc123")
        XCTAssertEqual(session.pid, 12345)
        XCTAssertEqual(session.folderName, "MyProject")
        XCTAssertEqual(session.folderPath, "/Users/test/MyProject")
        XCTAssertEqual(session.model, "Opus")
        XCTAssertEqual(session.context.usedTokens, 670000)
        XCTAssertEqual(session.context.totalTokens, 1000000)
        XCTAssertEqual(session.context.usedPercentage, 67)
        XCTAssertEqual(session.rateLimits?.fiveHour.usedPercentage, 42.0)
        XCTAssertEqual(session.rateLimits?.fiveHour.resetsAt, 1738425600)
        XCTAssertEqual(session.rateLimits?.sevenDay.usedPercentage, 18.0)
        XCTAssertEqual(session.costUsd, 0.42)
        XCTAssertEqual(session.linesAdded, 156)
        XCTAssertEqual(session.linesRemoved, 23)
        XCTAssertEqual(session.timestamp, 1738420000)
    }

    func testDecodesWithMissingOptionalRateLimits() throws {
        let json = """
        {
            "session_id": "abc123",
            "pid": 12345,
            "folder_name": "MyProject",
            "folder_path": "/Users/test/MyProject",
            "model": "Opus",
            "context": {
                "used_tokens": 100,
                "total_tokens": 200000,
                "used_percentage": 0
            },
            "cost_usd": 0.0,
            "lines_added": 0,
            "lines_removed": 0,
            "timestamp": 1738420000
        }
        """.data(using: .utf8)!

        let session = try JSONDecoder().decode(SessionData.self, from: json)
        XCTAssertNil(session.rateLimits)
    }

    func testFormattedTokens() throws {
        let session = try JSONDecoder().decode(SessionData.self, from: sampleJSON)
        XCTAssertEqual(session.context.formattedUsed, "670k")
        XCTAssertEqual(session.context.formattedTotal, "1M")
    }

    func testFormattedTokensSmall() throws {
        let json = """
        {
            "session_id": "x",
            "pid": 1,
            "folder_name": "X",
            "folder_path": "/x",
            "model": "Haiku",
            "context": {
                "used_tokens": 16000,
                "total_tokens": 200000,
                "used_percentage": 8
            },
            "cost_usd": 0.01,
            "lines_added": 0,
            "lines_removed": 0,
            "timestamp": 1738420000
        }
        """.data(using: .utf8)!

        let session = try JSONDecoder().decode(SessionData.self, from: json)
        XCTAssertEqual(session.context.formattedUsed, "16k")
        XCTAssertEqual(session.context.formattedTotal, "200k")
    }
}
