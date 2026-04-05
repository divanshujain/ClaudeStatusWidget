# Claude Status Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu bar widget that shows real-time Claude Code session status with colored folder pills and an Apple-themed dropdown.

**Architecture:** NSStatusItem with custom NSView for menu bar pills, NSPopover hosting SwiftUI views for the dropdown. A modified statusline script writes per-session JSON files to `~/.claude/session-status/`; the Swift app watches that directory via DispatchSource and updates the UI in real-time.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, Foundation. Built with Swift Package Manager. No Xcode IDE required — uses `swift build` and a manual `.app` bundle script.

---

### Task 1: Project Scaffolding

**Files:**
- Create: `Package.swift`
- Create: `Sources/ClaudeStatusWidget/main.swift`
- Create: `Sources/ClaudeStatusWidget/Info.plist`
- Create: `scripts/bundle.sh`

- [ ] **Step 1: Create Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeStatusWidget",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ClaudeStatusWidget",
            path: "Sources/ClaudeStatusWidget",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate",
                              "-Xlinker", "__TEXT",
                              "-Xlinker", "__info_plist",
                              "-Xlinker", "Sources/ClaudeStatusWidget/Info.plist"])
            ]
        ),
        .testTarget(
            name: "ClaudeStatusWidgetTests",
            dependencies: ["ClaudeStatusWidget"],
            path: "Tests/ClaudeStatusWidgetTests"
        )
    ]
)
```

- [ ] **Step 2: Create Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ClaudeStatusWidget</string>
    <key>CFBundleIdentifier</key>
    <string>com.divanshujain.ClaudeStatusWidget</string>
    <key>CFBundleName</key>
    <string>ClaudeStatusWidget</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
```

- [ ] **Step 3: Create minimal main.swift that launches an NSApplication**

```swift
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("ClaudeStatusWidget launched")
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // No dock icon
app.run()
```

- [ ] **Step 4: Create bundle script**

```bash
#!/usr/bin/env bash
set -euo pipefail

swift build -c release 2>&1

APP_DIR="build/ClaudeStatusWidget.app/Contents"
mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources"
cp .build/release/ClaudeStatusWidget "$APP_DIR/MacOS/"
cp Sources/ClaudeStatusWidget/Info.plist "$APP_DIR/"

echo "Built: build/ClaudeStatusWidget.app"
```

- [ ] **Step 5: Create empty test file so the package resolves**

Create `Tests/ClaudeStatusWidgetTests/PlaceholderTests.swift`:

```swift
import XCTest

final class PlaceholderTests: XCTestCase {
    func testProjectBuilds() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 6: Build and verify**

Run: `swift build 2>&1`
Expected: Build succeeds with no errors.

Run: `swift test 2>&1`
Expected: 1 test passes.

- [ ] **Step 7: Commit**

```bash
git add Package.swift Sources/ Tests/ scripts/
git commit -m "feat: project scaffolding with SPM and app bundle script"
```

---

### Task 2: Data Models

**Files:**
- Create: `Sources/ClaudeStatusWidget/Models/SessionData.swift`
- Create: `Sources/ClaudeStatusWidget/Models/RateLimitStatus.swift`
- Create: `Tests/ClaudeStatusWidgetTests/SessionDataTests.swift`
- Create: `Tests/ClaudeStatusWidgetTests/RateLimitStatusTests.swift`

- [ ] **Step 1: Write failing test for SessionData JSON decoding**

Create `Tests/ClaudeStatusWidgetTests/SessionDataTests.swift`:

```swift
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
        XCTAssertEqual(session.rateLimits.fiveHour.usedPercentage, 42.0)
        XCTAssertEqual(session.rateLimits.fiveHour.resetsAt, 1738425600)
        XCTAssertEqual(session.rateLimits.sevenDay.usedPercentage, 18.0)
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SessionDataTests 2>&1`
Expected: FAIL — `SessionData` type not found.

- [ ] **Step 3: Implement SessionData model**

Create `Sources/ClaudeStatusWidget/Models/SessionData.swift`:

```swift
import Foundation

struct ContextInfo: Codable {
    let usedTokens: Int
    let totalTokens: Int
    let usedPercentage: Int

    enum CodingKeys: String, CodingKey {
        case usedTokens = "used_tokens"
        case totalTokens = "total_tokens"
        case usedPercentage = "used_percentage"
    }

    var formattedUsed: String {
        formatTokenCount(usedTokens)
    }

    var formattedTotal: String {
        formatTokenCount(totalTokens)
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            let millions = Double(count) / 1_000_000.0
            if millions == millions.rounded() {
                return "\(Int(millions))M"
            }
            return String(format: "%.1fM", millions)
        }
        let thousands = Double(count) / 1000.0
        if thousands == thousands.rounded() {
            return "\(Int(thousands))k"
        }
        return String(format: "%.1fk", thousands)
    }
}

struct RateLimitWindow: Codable {
    let usedPercentage: Double
    let resetsAt: TimeInterval

    enum CodingKeys: String, CodingKey {
        case usedPercentage = "used_percentage"
        case resetsAt = "resets_at"
    }
}

struct RateLimits: Codable {
    let fiveHour: RateLimitWindow
    let sevenDay: RateLimitWindow

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }
}

struct SessionData: Codable {
    let sessionId: String
    let pid: Int
    let folderName: String
    let folderPath: String
    let model: String
    let context: ContextInfo
    let rateLimits: RateLimits?
    let costUsd: Double
    let linesAdded: Int
    let linesRemoved: Int
    let timestamp: TimeInterval

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case pid
        case folderName = "folder_name"
        case folderPath = "folder_path"
        case model
        case context
        case rateLimits = "rate_limits"
        case costUsd = "cost_usd"
        case linesAdded = "lines_added"
        case linesRemoved = "lines_removed"
        case timestamp
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter SessionDataTests 2>&1`
Expected: All 4 tests PASS.

- [ ] **Step 5: Write failing test for RateLimitStatus**

Create `Tests/ClaudeStatusWidgetTests/RateLimitStatusTests.swift`:

```swift
import XCTest
@testable import ClaudeStatusWidget

final class RateLimitStatusTests: XCTestCase {
    func testSafeStatus() {
        // 20% used, resets in 3 hours, 5h window
        let now = Date().timeIntervalSince1970
        let window = RateLimitWindow(usedPercentage: 20.0, resetsAt: now + 10800)
        let status = RateLimitCalculator.status(for: window, windowDuration: 18000, now: now)

        XCTAssertEqual(status.severity, .safe)
        XCTAssertTrue(status.burnRate < 10.0)
        XCTAssertTrue(status.resetCountdown > 0)
        XCTAssertTrue(status.label.contains("safe"))
    }

    func testDangerStatus() {
        // 85% used, resets in 4 hours, 5h window (started 1h ago)
        let now = Date().timeIntervalSince1970
        let window = RateLimitWindow(usedPercentage: 85.0, resetsAt: now + 14400)
        let status = RateLimitCalculator.status(for: window, windowDuration: 18000, now: now)

        XCTAssertEqual(status.severity, .danger)
    }

    func testModerateStatus() {
        // 55% used, resets in 2h, 5h window (3h elapsed)
        let now = Date().timeIntervalSince1970
        let window = RateLimitWindow(usedPercentage: 55.0, resetsAt: now + 7200)
        let status = RateLimitCalculator.status(for: window, windowDuration: 18000, now: now)

        // At 55%, burn rate ~18.3%/h, would hit 100% in ~2.45h which is after reset (2h)
        // So this should be safe. Let's just check it's not danger.
        XCTAssertNotEqual(status.severity, .danger)
    }

    func testFormatDuration() {
        XCTAssertEqual(RateLimitCalculator.formatDuration(3661), "1h 1m")
        XCTAssertEqual(RateLimitCalculator.formatDuration(90000), "1d 1h")
        XCTAssertEqual(RateLimitCalculator.formatDuration(300), "5m")
        XCTAssertEqual(RateLimitCalculator.formatDuration(0), "now")
    }
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `swift test --filter RateLimitStatusTests 2>&1`
Expected: FAIL — `RateLimitCalculator` not found.

- [ ] **Step 7: Implement RateLimitStatus and RateLimitCalculator**

Create `Sources/ClaudeStatusWidget/Models/RateLimitStatus.swift`:

```swift
import Foundation
import SwiftUI

enum LimitSeverity: Equatable {
    case safe
    case moderate
    case danger
}

struct RateLimitStatusInfo {
    let severity: LimitSeverity
    let burnRate: Double        // %/h
    let resetCountdown: TimeInterval
    let label: String           // "safe" or "~1h 12m to full"
    let timeToFull: TimeInterval?

    var color: Color {
        switch severity {
        case .safe: return .green
        case .moderate: return .yellow
        case .danger: return .red
        }
    }
}

enum RateLimitCalculator {
    static func status(
        for window: RateLimitWindow,
        windowDuration: TimeInterval,
        now: TimeInterval = Date().timeIntervalSince1970
    ) -> RateLimitStatusInfo {
        let timeToReset = window.resetsAt - now
        let windowStart = window.resetsAt - windowDuration
        let elapsed = now - windowStart

        // No meaningful usage or time
        guard elapsed > 0, window.usedPercentage > 0 else {
            return RateLimitStatusInfo(
                severity: .safe,
                burnRate: 0,
                resetCountdown: max(timeToReset, 0),
                label: "safe",
                timeToFull: nil
            )
        }

        let burnRatePerHour = window.usedPercentage / (elapsed / 3600.0)
        let burnRatePerSec = window.usedPercentage / elapsed
        let remainingPct = 100.0 - window.usedPercentage
        let timeToFull = remainingPct / burnRatePerSec

        let willHitBeforeReset = timeToFull < timeToReset

        let severity: LimitSeverity
        let label: String

        if willHitBeforeReset {
            let durationStr = formatDuration(timeToFull)
            label = "~\(durationStr) to full"
            severity = .danger
        } else if window.usedPercentage > 60 {
            label = "safe"
            severity = .moderate
        } else {
            label = "safe"
            severity = .safe
        }

        return RateLimitStatusInfo(
            severity: severity,
            burnRate: burnRatePerHour,
            resetCountdown: max(timeToReset, 0),
            label: label,
            timeToFull: willHitBeforeReset ? timeToFull : nil
        )
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let secs = Int(seconds)
        guard secs > 0 else { return "now" }

        let days = secs / 86400
        let hours = (secs % 86400) / 3600
        let mins = (secs % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `swift test --filter RateLimitStatusTests 2>&1`
Expected: All 4 tests PASS.

- [ ] **Step 9: Commit**

```bash
git add Sources/ClaudeStatusWidget/Models/ Tests/ClaudeStatusWidgetTests/
git commit -m "feat: add SessionData and RateLimitCalculator models with tests"
```

---

### Task 3: Session Manager

**Files:**
- Create: `Sources/ClaudeStatusWidget/Services/SessionManager.swift`
- Create: `Tests/ClaudeStatusWidgetTests/SessionManagerTests.swift`

- [ ] **Step 1: Write failing tests for SessionManager**

Create `Tests/ClaudeStatusWidgetTests/SessionManagerTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter SessionManagerTests 2>&1`
Expected: FAIL — `SessionManager` not found.

- [ ] **Step 3: Implement SessionManager**

Create `Sources/ClaudeStatusWidget/Services/SessionManager.swift`:

```swift
import Foundation

class SessionManager: ObservableObject {
    @Published var sessions: [SessionData] = []

    private let directory: URL
    private let staleThreshold: TimeInterval

    init(
        directory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/session-status"),
        staleThreshold: TimeInterval = 300 // 5 minutes
    ) {
        self.directory = directory
        self.staleThreshold = staleThreshold
    }

    func reload() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            sessions = []
            return
        }

        let decoder = JSONDecoder()
        var loaded: [SessionData] = []

        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let session = try? decoder.decode(SessionData.self, from: data) else {
                continue
            }
            loaded.append(session)
        }

        // Sort by timestamp descending (most recent first)
        loaded.sort { $0.timestamp > $1.timestamp }
        sessions = loaded
    }

    func isStale(sessionId: String) -> Bool {
        guard let session = sessions.first(where: { $0.sessionId == sessionId }) else {
            return true
        }
        let age = Date().timeIntervalSince1970 - session.timestamp
        return age > staleThreshold
    }

    func isProcessAlive(pid: Int) -> Bool {
        kill(Int32(pid), 0) == 0
    }

    /// Returns the rate limits from the most recently updated session that has them.
    var latestRateLimits: RateLimits? {
        sessions
            .sorted { $0.timestamp > $1.timestamp }
            .compactMap { $0.rateLimits }
            .first
    }

    /// Removes JSON files for sessions whose process is dead and older than 30 min.
    func cleanupDeadSessions() {
        let fm = FileManager.default
        let now = Date().timeIntervalSince1970
        let deadTimeout: TimeInterval = 1800 // 30 min

        for session in sessions {
            if !isProcessAlive(pid: session.pid) && (now - session.timestamp) > deadTimeout {
                let file = directory.appendingPathComponent("\(session.sessionId).json")
                try? fm.removeItem(at: file)
            }
        }
        reload()
    }

    func ensureDirectoryExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: directory.path) {
            try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter SessionManagerTests 2>&1`
Expected: All 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeStatusWidget/Services/ Tests/ClaudeStatusWidgetTests/SessionManagerTests.swift
git commit -m "feat: add SessionManager with staleness detection and cleanup"
```

---

### Task 4: Session File Watcher

**Files:**
- Create: `Sources/ClaudeStatusWidget/Services/SessionWatcher.swift`

No unit test for this one — it wraps OS-level DispatchSource which requires real filesystem events. Tested via integration in Task 10.

- [ ] **Step 1: Implement SessionWatcher**

Create `Sources/ClaudeStatusWidget/Services/SessionWatcher.swift`:

```swift
import Foundation

class SessionWatcher {
    private var directorySource: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private let directory: URL
    private let onChange: () -> Void

    init(directory: URL, onChange: @escaping () -> Void) {
        self.directory = directory
        self.onChange = onChange
    }

    func start() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: directory.path) {
            try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        fileDescriptor = open(directory.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("SessionWatcher: failed to open directory \(directory.path)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.onChange()
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
                self?.fileDescriptor = -1
            }
        }

        source.resume()
        directorySource = source
    }

    func stop() {
        directorySource?.cancel()
        directorySource = nil
    }

    deinit {
        stop()
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `swift build 2>&1`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/ClaudeStatusWidget/Services/SessionWatcher.swift
git commit -m "feat: add SessionWatcher with DispatchSource directory monitoring"
```

---

### Task 5: Color Palette for Sessions

**Files:**
- Create: `Sources/ClaudeStatusWidget/Models/SessionColorPalette.swift`

- [ ] **Step 1: Implement color palette**

Create `Sources/ClaudeStatusWidget/Models/SessionColorPalette.swift`:

```swift
import AppKit
import SwiftUI

enum SessionColorPalette {
    private static let colors: [NSColor] = [
        .systemPurple,
        .systemBlue,
        .systemGreen,
        .systemTeal,
        .systemOrange,
        .systemPink,
        .systemIndigo,
    ]

    /// Maps used to persist color assignments per session_id across reloads.
    private static var assignments: [String: Int] = [:]
    private static var nextIndex: Int = 0

    static func color(for sessionId: String) -> NSColor {
        if let idx = assignments[sessionId] {
            return colors[idx % colors.count]
        }
        let idx = nextIndex
        assignments[sessionId] = idx
        nextIndex += 1
        return colors[idx % colors.count]
    }

    static func swiftUIColor(for sessionId: String) -> Color {
        Color(nsColor: color(for: sessionId))
    }

    static func reset() {
        assignments.removeAll()
        nextIndex = 0
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `swift build 2>&1`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/ClaudeStatusWidget/Models/SessionColorPalette.swift
git commit -m "feat: add session color palette with persistent assignments"
```

---

### Task 6: Menu Bar Pill View (NSStatusItem)

**Files:**
- Create: `Sources/ClaudeStatusWidget/MenuBar/StatusBarController.swift`
- Create: `Sources/ClaudeStatusWidget/MenuBar/PillView.swift`

- [ ] **Step 1: Implement PillView (NSView subclass for a single pill)**

Create `Sources/ClaudeStatusWidget/MenuBar/PillView.swift`:

```swift
import AppKit

class PillView: NSView {
    var label: String = ""
    var percentage: Int = 0
    var pillColor: NSColor = .systemPurple
    var isDimmed: Bool = false

    override var intrinsicContentSize: NSSize {
        let text = "\(label) \(percentage)%"
        let font = NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (text as NSString).size(withAttributes: attrs)
        return NSSize(width: textSize.width + 12, height: 18)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rect = bounds.insetBy(dx: 1, dy: 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)

        let alpha: CGFloat = isDimmed ? 0.3 : 0.85
        pillColor.withAlphaComponent(alpha).setFill()
        path.fill()

        let text = "\(label) \(percentage)%"
        let font = NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        let textColor: NSColor = isDimmed ? .secondaryLabelColor : .white
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
        ]
        let textSize = (text as NSString).size(withAttributes: attrs)
        let textRect = NSRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        (text as NSString).draw(in: textRect, withAttributes: attrs)
    }
}
```

- [ ] **Step 2: Implement StatusBarController**

Create `Sources/ClaudeStatusWidget/MenuBar/StatusBarController.swift`:

```swift
import AppKit

class StatusBarController {
    private let statusItem: NSStatusItem
    private let containerView: NSView
    private var pillViews: [PillView] = []
    private var rateLimitLabel: NSTextField?

    var onClicked: (() -> Void)?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        containerView = NSView()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusBarClicked(_:))
        }
    }

    @objc private func statusBarClicked(_ sender: Any?) {
        onClicked?()
    }

    func update(sessions: [SessionData], staleSessions: Set<String>, rateLimitText: String, rateLimitColor: NSColor) {
        // Remove old subviews
        containerView.subviews.forEach { $0.removeFromSuperview() }
        pillViews.removeAll()

        var xOffset: CGFloat = 4
        let maxPills = 4
        let visibleSessions = Array(sessions.prefix(maxPills))

        // Create pills
        for session in visibleSessions {
            let pill = PillView()
            pill.label = truncate(session.folderName, max: 10)
            pill.percentage = session.context.usedPercentage
            pill.pillColor = SessionColorPalette.color(for: session.sessionId)
            pill.isDimmed = staleSessions.contains(session.sessionId)

            let size = pill.intrinsicContentSize
            pill.frame = NSRect(x: xOffset, y: 1, width: size.width, height: size.height)
            containerView.addSubview(pill)
            pillViews.append(pill)
            xOffset += size.width + 4
        }

        // "+N" badge if more sessions
        if sessions.count > maxPills {
            let badge = NSTextField(labelWithString: "+\(sessions.count - maxPills)")
            badge.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
            badge.textColor = .secondaryLabelColor
            badge.sizeToFit()
            badge.frame.origin = NSPoint(x: xOffset, y: 3)
            containerView.addSubview(badge)
            xOffset += badge.frame.width + 4
        }

        // Separator + rate limit
        if !sessions.isEmpty {
            let sep = NSTextField(labelWithString: "·")
            sep.font = NSFont.systemFont(ofSize: 11)
            sep.textColor = .tertiaryLabelColor
            sep.sizeToFit()
            sep.frame.origin = NSPoint(x: xOffset, y: 2)
            containerView.addSubview(sep)
            xOffset += sep.frame.width + 4
        }

        let rlLabel = NSTextField(labelWithString: rateLimitText)
        rlLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        rlLabel.textColor = rateLimitColor
        rlLabel.sizeToFit()
        rlLabel.frame.origin = NSPoint(x: xOffset, y: 2)
        containerView.addSubview(rlLabel)
        xOffset += rlLabel.frame.width + 4

        // Update container size
        containerView.frame = NSRect(x: 0, y: 0, width: xOffset, height: 22)

        // Show icon only if no sessions
        if sessions.isEmpty {
            statusItem.button?.title = "◆"
            statusItem.button?.image = nil
            statusItem.length = NSStatusItem.variableLength
            statusItem.button?.subviews.forEach { $0.removeFromSuperview() }
        } else {
            statusItem.button?.title = ""
            statusItem.length = xOffset
            statusItem.button?.subviews.forEach { $0.removeFromSuperview() }
            statusItem.button?.addSubview(containerView)
        }
    }

    var button: NSStatusBarButton? {
        statusItem.button
    }

    private func truncate(_ str: String, max: Int) -> String {
        if str.count <= max { return str }
        return String(str.prefix(max - 1)) + "…"
    }
}
```

- [ ] **Step 3: Build to verify**

Run: `swift build 2>&1`
Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Sources/ClaudeStatusWidget/MenuBar/
git commit -m "feat: add StatusBarController with colored pill rendering"
```

---

### Task 7: Popover SwiftUI Views

**Files:**
- Create: `Sources/ClaudeStatusWidget/Popover/PopoverContentView.swift`
- Create: `Sources/ClaudeStatusWidget/Popover/SessionRowView.swift`
- Create: `Sources/ClaudeStatusWidget/Popover/RateLimitsView.swift`

- [ ] **Step 1: Implement SessionRowView**

Create `Sources/ClaudeStatusWidget/Popover/SessionRowView.swift`:

```swift
import SwiftUI
import AppKit

struct SessionRowView: View {
    let session: SessionData
    let isStale: Bool
    let dotColor: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor.opacity(isStale ? 0.3 : 1.0))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.folderName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isStale ? .secondary : .primary)

                if isStale {
                    Text("idle")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    Text("\(session.model) · \(session.context.formattedUsed) / \(session.context.formattedTotal)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            ProgressView(value: Double(session.context.usedPercentage), total: 100)
                .progressViewStyle(.linear)
                .frame(width: 50)
                .tint(dotColor.opacity(isStale ? 0.3 : 1.0))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Copy Session Info") {
                let info = """
                \(session.folderName) (\(session.model))
                Context: \(session.context.formattedUsed) / \(session.context.formattedTotal) (\(session.context.usedPercentage)%)
                Cost: $\(String(format: "%.2f", session.costUsd))
                Lines: +\(session.linesAdded) / -\(session.linesRemoved)
                """
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(info, forType: .string)
            }
            Button("Open in Finder") {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: session.folderPath)
            }
        }
    }
}
```

- [ ] **Step 2: Implement RateLimitsView**

Create `Sources/ClaudeStatusWidget/Popover/RateLimitsView.swift`:

```swift
import SwiftUI

struct RateLimitRow: View {
    let label: String
    let percentage: Double
    let status: RateLimitStatusInfo

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 12))
                Spacer()
                Text("\(Int(percentage))% · \(formattedBurnRate) · resets \(formattedReset)")
                    .font(.system(size: 11))
                    .foregroundColor(status.color)
            }

            ProgressView(value: percentage, total: 100)
                .progressViewStyle(.linear)
                .tint(status.color)

            HStack {
                Spacer()
                Text(status.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(status.color)
            }
        }
    }

    private var formattedBurnRate: String {
        let rate = status.burnRate
        if rate < 0.1 { return "0%/h" }
        if rate == rate.rounded() {
            return "\(Int(rate))%/h"
        }
        return String(format: "%.1f%%/h", rate)
    }

    private var formattedReset: String {
        RateLimitCalculator.formatDuration(status.resetCountdown)
    }
}

struct RateLimitsView: View {
    let rateLimits: RateLimits?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("USAGE LIMITS")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .tracking(0.5)

            if let limits = rateLimits {
                let now = Date().timeIntervalSince1970
                let fiveHStatus = RateLimitCalculator.status(
                    for: limits.fiveHour, windowDuration: 18000, now: now
                )
                let sevenDStatus = RateLimitCalculator.status(
                    for: limits.sevenDay, windowDuration: 604800, now: now
                )

                RateLimitRow(
                    label: "5-hour",
                    percentage: limits.fiveHour.usedPercentage,
                    status: fiveHStatus
                )

                RateLimitRow(
                    label: "7-day",
                    percentage: limits.sevenDay.usedPercentage,
                    status: sevenDStatus
                )
            } else {
                Text("No usage data yet")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
```

- [ ] **Step 3: Implement PopoverContentView**

Create `Sources/ClaudeStatusWidget/Popover/PopoverContentView.swift`:

```swift
import SwiftUI

struct PopoverContentView: View {
    @ObservedObject var sessionManager: SessionManager

    var body: some View {
        VStack(spacing: 0) {
            // Sessions list
            if sessionManager.sessions.isEmpty {
                VStack(spacing: 8) {
                    Text("No active sessions")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("Start a Claude Code session to see it here")
                        .font(.system(size: 11))
                        .foregroundColor(.tertiaryLabel)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(sessionManager.sessions, id: \.sessionId) { session in
                            SessionRowView(
                                session: session,
                                isStale: sessionManager.isStale(sessionId: session.sessionId),
                                dotColor: SessionColorPalette.swiftUIColor(for: session.sessionId)
                            )
                            .onTapGesture {
                                openInFinder(path: session.folderPath)
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }

            Divider()
                .padding(.horizontal, 12)

            // Rate limits
            RateLimitsView(rateLimits: sessionManager.latestRateLimits)

            Divider()
                .padding(.horizontal, 12)

            // Footer: total cost
            HStack {
                Text("Total cost: $\(totalCost, specifier: "%.2f")")
                    .font(.system(size: 10))
                    .foregroundColor(.tertiaryLabel)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(width: 280)
    }

    private var totalCost: Double {
        sessionManager.sessions.reduce(0) { $0 + $1.costUsd }
    }

    private func openInFinder(path: String) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }
}
```

- [ ] **Step 4: Build to verify**

Run: `swift build 2>&1`
Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeStatusWidget/Popover/
git commit -m "feat: add SwiftUI popover views for sessions and rate limits"
```

---

### Task 8: App Delegate — Wire Everything Together

**Files:**
- Modify: `Sources/ClaudeStatusWidget/main.swift`

- [ ] **Step 1: Replace main.swift with full AppDelegate**

Replace the contents of `Sources/ClaudeStatusWidget/main.swift` with:

```swift
import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private var sessionManager: SessionManager!
    private var sessionWatcher: SessionWatcher!
    private var popover: NSPopover!
    private var staleTimer: Timer?
    private var rateLimitTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        sessionManager = SessionManager()
        sessionManager.ensureDirectoryExists()

        statusBarController = StatusBarController()
        statusBarController.onClicked = { [weak self] in
            self?.togglePopover()
        }

        // Set up popover with SwiftUI content
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverContentView(sessionManager: sessionManager)
        )

        // Watch session-status directory
        let sessionDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/session-status")
        sessionWatcher = SessionWatcher(directory: sessionDir) { [weak self] in
            self?.sessionManager.reload()
            self?.updateMenuBar()
        }
        sessionWatcher.start()

        // Initial load
        sessionManager.reload()
        updateMenuBar()

        // 30s heartbeat: staleness + dead process cleanup
        staleTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sessionManager.cleanupDeadSessions()
            self?.updateMenuBar()
        }

        // 60s rate limit countdown refresh
        rateLimitTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateMenuBar()
        }
    }

    private func updateMenuBar() {
        let staleSessions = Set(
            sessionManager.sessions
                .filter { sessionManager.isStale(sessionId: $0.sessionId) }
                .map { $0.sessionId }
        )

        let (rateLimitText, rateLimitColor) = formatRateLimitForMenuBar()

        statusBarController.update(
            sessions: sessionManager.sessions,
            staleSessions: staleSessions,
            rateLimitText: rateLimitText,
            rateLimitColor: rateLimitColor
        )
    }

    private func formatRateLimitForMenuBar() -> (String, NSColor) {
        guard let limits = sessionManager.latestRateLimits else {
            return ("", .secondaryLabelColor)
        }

        let now = Date().timeIntervalSince1970
        let status = RateLimitCalculator.status(
            for: limits.fiveHour, windowDuration: 18000, now: now
        )
        let pct = Int(limits.fiveHour.usedPercentage)
        let text = "5h: \(pct)%"

        let color: NSColor
        switch status.severity {
        case .safe: color = .systemGreen
        case .moderate: color = .systemYellow
        case .danger: color = .systemRed
        }

        return (text, color)
    }

    private func togglePopover() {
        guard let button = statusBarController.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Refresh content size based on session count
            let sessionHeight = max(sessionManager.sessions.count * 40, 60)
            let totalHeight = sessionHeight + 160 // rate limits + footer
            popover.contentSize = NSSize(width: 280, height: min(totalHeight, 500))

            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        sessionWatcher.stop()
        staleTimer?.invalidate()
        rateLimitTimer?.invalidate()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
```

- [ ] **Step 2: Build to verify**

Run: `swift build 2>&1`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/ClaudeStatusWidget/main.swift
git commit -m "feat: wire up AppDelegate with session watcher, timers, and popover"
```

---

### Task 9: Modified Statusline Script

**Files:**
- Create: `Scripts/statusline-command.sh`
- Create: `Scripts/install.sh`

- [ ] **Step 1: Create the modified statusline script**

Create `Scripts/statusline-command.sh`:

```bash
#!/usr/bin/env bash
input=$(cat)

dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
dirname=$(basename "$dir")

# Extract just the base model name (Opus/Sonnet/Haiku)
model=$(echo "$input" | jq -r '.model.display_name // ""' | awk '{print $1}')

# Context window usage
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
cache_create=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
input_tokens=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
total=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

# Rate limits
five_h_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_h_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_d_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_d_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# Session info
session_id=$(echo "$input" | jq -r '.session_id // ""')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

# Format seconds into human-readable duration
format_duration() {
  local seconds=$1
  if [ "$seconds" -le 0 ]; then
    echo "now"
    return
  fi
  local days=$((seconds / 86400))
  local hours=$(( (seconds % 86400) / 3600 ))
  local mins=$(( (seconds % 3600) / 60 ))
  if [ "$days" -gt 0 ]; then
    echo "${days}d ${hours}h"
  elif [ "$hours" -gt 0 ]; then
    echo "${hours}h ${mins}m"
  else
    echo "${mins}m"
  fi
}

# Calculate burn rate and projection
calc_burn_info() {
  local used_pct=$1
  local reset_epoch=$2
  local window_seconds=$3
  local now
  now=$(date +%s)

  local time_to_reset=$((reset_epoch - now))
  local reset_fmt
  reset_fmt=$(format_duration "$time_to_reset")

  local window_start=$((reset_epoch - window_seconds))
  local elapsed=$((now - window_start))

  if [ "$elapsed" -le 0 ] || [ "$(awk "BEGIN {print ($used_pct <= 0)}")" = "1" ]; then
    echo "0%/h safe (${reset_fmt})"
    return
  fi

  local rate
  rate=$(awk "BEGIN {printf \"%.1f\", $used_pct / ($elapsed / 3600.0)}")
  rate=$(echo "$rate" | sed 's/\.0$//')

  local rate_per_sec
  rate_per_sec=$(awk "BEGIN {print $used_pct / $elapsed}")

  if [ "$(awk "BEGIN {print ($rate_per_sec <= 0)}")" = "1" ]; then
    echo "${rate}%/h safe (${reset_fmt})"
    return
  fi

  local remaining_pct
  remaining_pct=$(awk "BEGIN {print 100 - $used_pct}")
  local time_to_full
  time_to_full=$(awk "BEGIN {printf \"%.0f\", $remaining_pct / $rate_per_sec}")

  if [ "$time_to_full" -ge "$time_to_reset" ]; then
    echo "${rate}%/h safe (${reset_fmt})"
  else
    local full_fmt
    full_fmt=$(format_duration "$time_to_full")
    echo "${rate}%/h ~${full_fmt} (${reset_fmt})"
  fi
}

# ── Original statusline output (unchanged) ──────────────────────────
parts=""
[ -n "$dirname" ] && parts="📁 ${dirname}"

if [ -n "$total" ]; then
  used=$(awk "BEGIN {printf \"%.0f\", $cache_read + $cache_create + $input_tokens}")
  used_k=$(awk "BEGIN {printf \"%.1fk\", $used/1000}")
  total_k=$(awk "BEGIN {printf \"%.0fk\", $total/1000}")
  pct=$(awk "BEGIN {printf \"%.0f\", $used * 100 / $total}")
  parts="${parts} | 📊 ${used_k}/${total_k} (${pct}%)"
fi

if [ -n "$five_h_pct" ] || [ -n "$seven_d_pct" ]; then
  limits=""
  if [ -n "$five_h_pct" ]; then
    five_h_rounded=$(awk "BEGIN {printf \"%.0f\", $five_h_pct}")
    five_h_info=$(calc_burn_info "$five_h_pct" "$five_h_reset" 18000)
    limits="5h: ${five_h_rounded}% ${five_h_info}"
  fi
  if [ -n "$seven_d_pct" ]; then
    seven_d_rounded=$(awk "BEGIN {printf \"%.0f\", $seven_d_pct}")
    seven_d_info=$(calc_burn_info "$seven_d_pct" "$seven_d_reset" 604800)
    [ -n "$limits" ] && limits="${limits}, "
    limits="${limits}7d: ${seven_d_rounded}% ${seven_d_info}"
  fi
  parts="${parts} | 🔒 ${limits}"
fi

[ -n "$model" ] && parts="${parts} | 🚀 ${model}"

echo "$parts"

# ── Write per-session JSON for ClaudeStatusWidget ────────────────────
if [ -n "$session_id" ]; then
  SESSION_DIR="$HOME/.claude/session-status"
  mkdir -p "$SESSION_DIR"
  NOW=$(date +%s)

  # Build rate_limits JSON fragment (may be empty)
  rl_json=""
  if [ -n "$five_h_pct" ] && [ -n "$seven_d_pct" ]; then
    rl_json=$(cat <<RLJSON
  "rate_limits": {
    "five_hour": {
      "used_percentage": $five_h_pct,
      "resets_at": $five_h_reset
    },
    "seven_day": {
      "used_percentage": $seven_d_pct,
      "resets_at": $seven_d_reset
    }
  },
RLJSON
)
  fi

  cat > "$SESSION_DIR/${session_id}.json" <<SESSIONEOF
{
  "session_id": "$session_id",
  "pid": $PPID,
  "folder_name": "$dirname",
  "folder_path": "$dir",
  "model": "$model",
  "context": {
    "used_tokens": ${used:-0},
    "total_tokens": ${total:-0},
    "used_percentage": ${pct:-0}
  },
  $rl_json
  "cost_usd": $cost,
  "lines_added": $lines_added,
  "lines_removed": $lines_removed,
  "timestamp": $NOW
}
SESSIONEOF
fi

# ── Write health file for Rocket watchdog (existing behavior) ────────
NOW=$(date +%s)
HEALTH_FILE="$HOME/.rocket/mark2-health.json"
mkdir -p "$(dirname "$HEALTH_FILE")"
cat > "$HEALTH_FILE" <<EOF
{
  "context_pct": ${pct:-0},
  "session_id": "$session_id",
  "model": "$model",
  "cost_usd": $cost,
  "timestamp": $NOW
}
EOF
```

- [ ] **Step 2: Create install script**

Create `Scripts/install.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== ClaudeStatusWidget Installer ==="

# 1. Build the app
echo "Building..."
cd "$PROJECT_DIR"
swift build -c release 2>&1

# 2. Create .app bundle
APP_DIR="$HOME/Applications/ClaudeStatusWidget.app/Contents"
mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources"
cp .build/release/ClaudeStatusWidget "$APP_DIR/MacOS/"
cp Sources/ClaudeStatusWidget/Info.plist "$APP_DIR/"
echo "Installed app to ~/Applications/ClaudeStatusWidget.app"

# 3. Install statusline script
cp "$SCRIPT_DIR/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
chmod +x "$HOME/.claude/statusline-command.sh"
echo "Updated statusline script at ~/.claude/statusline-command.sh"

# 4. Create session-status directory
mkdir -p "$HOME/.claude/session-status"
echo "Created ~/.claude/session-status/"

echo ""
echo "=== Installation complete ==="
echo "  - Open ~/Applications/ClaudeStatusWidget.app to start"
echo "  - To auto-start on login: System Settings > General > Login Items"
echo ""
```

- [ ] **Step 3: Make scripts executable**

Run: `chmod +x Scripts/statusline-command.sh Scripts/install.sh Scripts/bundle.sh`

- [ ] **Step 4: Commit**

```bash
git add Scripts/
git commit -m "feat: add modified statusline script and install script"
```

---

### Task 10: Build, Bundle, and Smoke Test

**Files:** No new files — integration testing.

- [ ] **Step 1: Run full test suite**

Run: `swift test 2>&1`
Expected: All tests pass (SessionData, RateLimitStatus, SessionManager tests).

- [ ] **Step 2: Build release binary**

Run: `swift build -c release 2>&1`
Expected: Build succeeds, binary at `.build/release/ClaudeStatusWidget`.

- [ ] **Step 3: Create app bundle**

Run: `bash Scripts/bundle.sh`
Expected: `build/ClaudeStatusWidget.app` created.

- [ ] **Step 4: Write test session data and launch**

```bash
mkdir -p ~/.claude/session-status
NOW=$(date +%s)
cat > ~/.claude/session-status/test-session-1.json <<EOF
{
  "session_id": "test-session-1",
  "pid": $$,
  "folder_name": "TestProject",
  "folder_path": "/tmp/TestProject",
  "model": "Opus",
  "context": {
    "used_tokens": 670000,
    "total_tokens": 1000000,
    "used_percentage": 67
  },
  "rate_limits": {
    "five_hour": {
      "used_percentage": 42.0,
      "resets_at": $((NOW + 8000))
    },
    "seven_day": {
      "used_percentage": 18.0,
      "resets_at": $((NOW + 500000))
    }
  },
  "cost_usd": 0.42,
  "lines_added": 156,
  "lines_removed": 23,
  "timestamp": $NOW
}
EOF
```

Run: `open build/ClaudeStatusWidget.app`
Expected: App launches, menu bar shows a purple pill "TestProje… 67%" and "5h: 42%". Clicking opens popover with session details and rate limits.

- [ ] **Step 5: Clean up test data**

Run: `rm ~/.claude/session-status/test-session-1.json`

- [ ] **Step 6: Final commit**

```bash
git add -A
git commit -m "chore: final build verification"
```

---

### Task 11: Claude Init and CLAUDE.md

**Files:**
- Create: `CLAUDE.md`

- [ ] **Step 1: Create CLAUDE.md for the project**

Create `CLAUDE.md`:

```markdown
# ClaudeStatusWidget

macOS menu bar widget displaying real-time Claude Code session status.

## Build

```bash
swift build            # Debug build
swift build -c release # Release build
swift test             # Run tests
bash Scripts/bundle.sh # Create .app bundle
bash Scripts/install.sh # Build + install to ~/Applications
```

## Architecture

- **Swift 6.2 + SPM** — no Xcode IDE required
- **AppKit** (`NSStatusItem` + custom `NSView`) for menu bar pill rendering
- **SwiftUI** (hosted in `NSPopover`) for the dropdown
- **DispatchSource** for real-time file watching on `~/.claude/session-status/`

## Data Flow

Each Claude Code session's statusline script writes a JSON file to `~/.claude/session-status/<session_id>.json`. The Swift app watches that directory and updates the UI on each change.

## Key Files

- `Sources/ClaudeStatusWidget/main.swift` — App entry + AppDelegate
- `Sources/ClaudeStatusWidget/Services/SessionManager.swift` — Session lifecycle
- `Sources/ClaudeStatusWidget/Services/SessionWatcher.swift` — DispatchSource watcher
- `Sources/ClaudeStatusWidget/MenuBar/StatusBarController.swift` — Menu bar pills
- `Sources/ClaudeStatusWidget/Popover/PopoverContentView.swift` — Dropdown UI
- `Scripts/statusline-command.sh` — Modified statusline that writes per-session JSON
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add CLAUDE.md with build and architecture overview"
```
