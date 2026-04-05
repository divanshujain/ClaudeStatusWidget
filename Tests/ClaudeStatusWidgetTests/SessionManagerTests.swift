import XCTest
@testable import ClaudeStatusWidget

final class SessionManagerTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("session-status-test-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func writeSession(_ data: [String: Any], id: String) {
        let fileURL = tempDir.appendingPathComponent("\(id).json")
        let jsonData = try! JSONSerialization.data(withJSONObject: data)
        try! jsonData.write(to: fileURL)
    }

    private func sampleSessionDict(
        id: String = "s1",
        pid: Int = 99999,
        folder: String = "TestProject",
        model: String = "Opus",
        usedPct: Int = 50,
        timestamp: TimeInterval? = nil
    ) -> [String: Any] {
        [
            "session_id": id,
            "pid": pid,
            "folder_name": folder,
            "folder_path": "/tmp/\(folder)",
            "model": model,
            "context": [
                "used_tokens": 500000,
                "total_tokens": 1000000,
                "used_percentage": usedPct
            ],
            "cost_usd": 0.10,
            "lines_added": 10,
            "lines_removed": 5,
            "timestamp": timestamp ?? Date().timeIntervalSince1970
        ]
    }

    func testLoadSessionsFromDirectory() {
        writeSession(sampleSessionDict(id: "s1", folder: "ProjectA"), id: "s1")
        writeSession(sampleSessionDict(id: "s2", folder: "ProjectB"), id: "s2")

        let manager = SessionManager(directory: tempDir)
        manager.reload()

        XCTAssertEqual(manager.sessions.count, 2)
        let folders = Set(manager.sessions.map { $0.folderName })
        XCTAssertTrue(folders.contains("ProjectA"))
        XCTAssertTrue(folders.contains("ProjectB"))
    }

    func testStaleSessionDetection() {
        let staleTime = Date().timeIntervalSince1970 - 600 // 10 min ago
        writeSession(sampleSessionDict(id: "s1", timestamp: staleTime), id: "s1")

        let manager = SessionManager(directory: tempDir, staleThreshold: 300)
        manager.reload()

        XCTAssertEqual(manager.sessions.count, 1)
        XCTAssertTrue(manager.isStale(sessionId: "s1"))
    }

    func testActiveSessionNotStale() {
        writeSession(sampleSessionDict(id: "s1"), id: "s1")

        let manager = SessionManager(directory: tempDir, staleThreshold: 300)
        manager.reload()

        XCTAssertFalse(manager.isStale(sessionId: "s1"))
    }

    func testLatestRateLimits() {
        let older: [String: Any] = {
            var d = sampleSessionDict(id: "s1", timestamp: Date().timeIntervalSince1970 - 60)
            d["rate_limits"] = [
                "five_hour": ["used_percentage": 30.0, "resets_at": 1738425600],
                "seven_day": ["used_percentage": 10.0, "resets_at": 1738857600]
            ]
            return d
        }()
        let newer: [String: Any] = {
            var d = sampleSessionDict(id: "s2", timestamp: Date().timeIntervalSince1970)
            d["rate_limits"] = [
                "five_hour": ["used_percentage": 45.0, "resets_at": 1738425600],
                "seven_day": ["used_percentage": 15.0, "resets_at": 1738857600]
            ]
            return d
        }()

        writeSession(older, id: "s1")
        writeSession(newer, id: "s2")

        let manager = SessionManager(directory: tempDir)
        manager.reload()

        let limits = manager.latestRateLimits
        XCTAssertNotNil(limits)
        XCTAssertEqual(limits!.fiveHour.usedPercentage, 45.0)
    }

    func testRemovesDeletedFiles() {
        writeSession(sampleSessionDict(id: "s1"), id: "s1")

        let manager = SessionManager(directory: tempDir)
        manager.reload()
        XCTAssertEqual(manager.sessions.count, 1)

        try! FileManager.default.removeItem(
            at: tempDir.appendingPathComponent("s1.json")
        )
        manager.reload()
        XCTAssertEqual(manager.sessions.count, 0)
    }
}
