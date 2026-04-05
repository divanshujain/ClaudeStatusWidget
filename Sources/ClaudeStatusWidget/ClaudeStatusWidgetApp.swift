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

func loadMenuBarIcon() -> NSImage? {
    // Try Bundle.module first (SPM resource bundle), then main bundle
    let bundles = [Bundle.module, Bundle.main]
    for bundle in bundles {
        if let url = bundle.url(forResource: "claudecode", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            return image
        }
        // Check inside nested resource bundles
        if let resourceURL = bundle.resourceURL {
            let nestedBundles = (try? FileManager.default.contentsOfDirectory(at: resourceURL, includingPropertiesForKeys: nil))?.filter { $0.pathExtension == "bundle" } ?? []
            for nested in nestedBundles {
                if let nestedBundle = Bundle(url: nested),
                   let url = nestedBundle.url(forResource: "claudecode", withExtension: "png"),
                   let image = NSImage(contentsOf: url) {
                    image.isTemplate = true
                    image.size = NSSize(width: 18, height: 18)
                    return image
                }
            }
        }
    }
    return nil
}

@main
struct ClaudeStatusWidgetApp: App {
    @StateObject private var global = SessionManagerGlobal.shared.manager

    var body: some Scene {
        MenuBarExtra {
            PopoverContentView(sessionManager: SessionManagerGlobal.shared.manager)
        } label: {
            let sessions = SessionManagerGlobal.shared.manager.sessions
            if let img = loadMenuBarIcon() {
                Image(nsImage: img)
                    .renderingMode(.template)
            }
            if sessions.isEmpty {
                Text("  Claude")
            } else {
                let first = sessions.first!
                let pct = first.context.usedPercentage
                let name = first.folderName
                if let limits = SessionManagerGlobal.shared.manager.latestRateLimits {
                    Text(" \(name) \(pct)%  ·  5h: \(Int(limits.fiveHour.usedPercentage))%")
                } else {
                    Text(" \(name) \(pct)%")
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
