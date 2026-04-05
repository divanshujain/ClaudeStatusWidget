import AppKit
import SwiftUI

class DropdownPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    init<Content: View>(@ViewBuilder content: () -> Content) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 290, height: 400),
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        titlebarSeparatorStyle = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Hide window buttons
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        // NSVisualEffectView IS the content view — not a background layer
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .popover
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 10
        visualEffect.layer?.masksToBounds = true

        // Embed SwiftUI inside the visual effect view
        let hosting = NSHostingView(rootView:
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.clear)
        )
        hosting.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
        ])
        contentView = visualEffect
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
        panel = DropdownPanel {
            PopoverContentView(sessionManager: self.sessionManager)
        }

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

        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)

        let sessionHeight = max(sessionManager.sessions.count * 60, 80)
        let totalHeight = sessionHeight + 220
        let panelHeight = CGFloat(min(totalHeight, 500))
        let panelWidth: CGFloat = 290

        let x = screenRect.midX - panelWidth / 2
        let y = screenRect.minY - panelHeight - 4

        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        panel.makeKeyAndOrderFront(nil)

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

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
