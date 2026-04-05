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
