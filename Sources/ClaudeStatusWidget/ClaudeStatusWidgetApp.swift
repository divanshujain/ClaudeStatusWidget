import SwiftUI
import AppKit

class SessionManagerGlobal: ObservableObject {
    static let shared = SessionManagerGlobal()
    let manager = SessionManager()
    var watcher: SessionWatcher?
    var staleTimer: Timer?
    var rateLimitTimer: Timer?

    init() {
        manager.ensureDirectoryExists()
        let sessionDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/session-status")
        watcher = SessionWatcher(directory: sessionDir) { [weak self] in
            self?.manager.reload()
        }
        watcher?.start()
        manager.reload()

        staleTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.manager.cleanupDeadSessions()
        }
        rateLimitTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.manager.objectWillChange.send()
        }
    }
}

@main
struct ClaudeStatusWidgetApp: App {
    @StateObject private var global = SessionManagerGlobal.shared.manager

    var body: some Scene {
        MenuBarExtra {
            PopoverContentView(sessionManager: SessionManagerGlobal.shared.manager)
        } label: {
            let sessions = SessionManagerGlobal.shared.manager.sessions
            if sessions.isEmpty {
                Text("◆")
            } else {
                let first = sessions.first!
                let pct = first.context.usedPercentage
                let name = first.folderName
                if let limits = SessionManagerGlobal.shared.manager.latestRateLimits {
                    Text("\(name) \(pct)%  ·  5h: \(Int(limits.fiveHour.usedPercentage))%")
                } else {
                    Text("\(name) \(pct)%")
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
