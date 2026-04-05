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
