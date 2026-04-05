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
