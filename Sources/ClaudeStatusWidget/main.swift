import AppKit
import SwiftUI

class DropdownPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private var sessionManager: SessionManager!
    private var sessionWatcher: SessionWatcher!
    private var panel: DropdownPanel!
    private var staleTimer: Timer?
    private var rateLimitTimer: Timer?
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        sessionManager = SessionManager()
        sessionManager.ensureDirectoryExists()

        statusBarController = StatusBarController()
        statusBarController.onClicked = { [weak self] in
            self?.togglePanel()
        }

        // Set up panel with SwiftUI content
        panel = DropdownPanel(contentRect: NSRect(x: 0, y: 0, width: 290, height: 400))
        let hostingView = NSHostingView(
            rootView: PopoverContentView(sessionManager: sessionManager)
                .background(
                    VisualEffectBackground()
                )
        )
        panel.contentView = hostingView

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

    private func togglePanel() {
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let button = statusBarController.button,
              let buttonWindow = button.window else { return }

        // Get button position in screen coordinates
        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)

        // Resize panel to fit content
        let sessionHeight = max(sessionManager.sessions.count * 56, 80)
        let totalHeight = sessionHeight + 200
        let panelHeight = CGFloat(min(totalHeight, 500))
        let panelWidth: CGFloat = 290

        // Position: centered under the button, 4pt gap below menu bar
        let x = screenRect.midX - panelWidth / 2
        let y = screenRect.minY - panelHeight - 4

        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        panel.makeKeyAndOrderFront(nil)

        // Close when clicking outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hidePanel()
        }
    }

    private func hidePanel() {
        panel.orderOut(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        sessionWatcher.stop()
        staleTimer?.invalidate()
        rateLimitTimer?.invalidate()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

// NSVisualEffectView wrapper for SwiftUI
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 14
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
