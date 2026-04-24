import Foundation

// Observes ~/.claude/session-status/ for changes; appends a row to
// ~/.claude/rate-limit-history.csv whenever 5h/7d pct or reset timestamps
// change for any session. Deduplicates identical consecutive samples per
// session. Caps the file at maxRows to prevent unbounded growth.
class RateLimitHistoryWriter {
    private let statusDir: URL
    private let csvFile: URL
    private var pollTimer: Timer?
    private var watcher: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private let maxRows: Int = 10000

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        statusDir = home.appendingPathComponent(".claude/session-status")
        csvFile = home.appendingPathComponent(".claude/rate-limit-history.csv")
    }

    func start() {
        ensureHeaderExists()
        scanAndAppend()

        let fm = FileManager.default
        if !fm.fileExists(atPath: statusDir.path) {
            try? fm.createDirectory(at: statusDir, withIntermediateDirectories: true)
        }

        // Directory watcher catches new/deleted session files. In-place content
        // updates (statusline's `cat > file.json`) don't reliably trigger this,
        // so a 30s Timer is the primary sampling mechanism.
        fileDescriptor = open(statusDir.path, O_EVTONLY)
        if fileDescriptor >= 0 {
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fileDescriptor,
                eventMask: [.write, .delete, .rename],
                queue: .main
            )
            source.setEventHandler { [weak self] in
                self?.scanAndAppend()
            }
            source.setCancelHandler { [weak self] in
                if let fd = self?.fileDescriptor, fd >= 0 {
                    close(fd)
                    self?.fileDescriptor = -1
                }
            }
            source.resume()
            watcher = source
        }

        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.scanAndAppend()
        }
    }

    func stop() {
        watcher?.cancel()
        watcher = nil
        pollTimer?.invalidate()
        pollTimer = nil
    }

    deinit {
        stop()
    }

    private func ensureHeaderExists() {
        if !FileManager.default.fileExists(atPath: csvFile.path) {
            let header = "timestamp,session_id,five_hour_pct,seven_day_pct,five_hour_resets_at,seven_day_resets_at\n"
            try? header.write(to: csvFile, atomically: true, encoding: .utf8)
        }
    }

    private func scanAndAppend() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: statusDir, includingPropertiesForKeys: nil) else { return }

        let existingCsv = (try? String(contentsOf: csvFile, encoding: .utf8)) ?? ""
        let existingEntries = RateLimitHistoryParser.parse(csv: existingCsv)
        var lastPerSession: [String: RateLimitHistoryEntry] = [:]
        for e in existingEntries { lastPerSession[e.sessionId] = e }

        let now = Int(Date().timeIntervalSince1970)
        var newLines: [String] = []

        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let sid = obj["session_id"] as? String,
                  let rl = obj["rate_limits"] as? [String: Any],
                  let fh = rl["five_hour"] as? [String: Any],
                  let sd = rl["seven_day"] as? [String: Any] else { continue }

            let fhPct = asDouble(fh["used_percentage"])
            let sdPct = asDouble(sd["used_percentage"])
            let fhReset = asDouble(fh["resets_at"])
            let sdReset = asDouble(sd["resets_at"])

            // Tolerance compare: JSON gives values like 28.000000000000004; the
            // CSV round-trip loses that precision and stores 28.00. Without epsilon,
            // every 30s tick would append a duplicate row.
            let eps = 0.005
            if let last = lastPerSession[sid],
               abs(last.fiveHourPct - fhPct) < eps,
               abs(last.sevenDayPct - sdPct) < eps,
               last.fiveHourResetsAt == fhReset,
               last.sevenDayResetsAt == sdReset {
                continue
            }

            newLines.append("\(now),\(sid),\(format(fhPct)),\(format(sdPct)),\(Int(fhReset)),\(Int(sdReset))")
        }

        guard !newLines.isEmpty else { return }
        appendLines(newLines)
        rotateIfNeeded()
    }

    private func asDouble(_ v: Any?) -> Double {
        if let d = v as? Double { return d }
        if let i = v as? Int { return Double(i) }
        if let n = v as? NSNumber { return n.doubleValue }
        return 0
    }

    private func format(_ v: Double) -> String {
        if v == v.rounded() { return String(Int(v)) }
        return String(format: "%.2f", v)
    }

    private func appendLines(_ lines: [String]) {
        guard let handle = try? FileHandle(forWritingTo: csvFile) else { return }
        handle.seekToEndOfFile()
        let data = (lines.joined(separator: "\n") + "\n").data(using: .utf8) ?? Data()
        handle.write(data)
        try? handle.close()
    }

    private func rotateIfNeeded() {
        guard let content = try? String(contentsOf: csvFile, encoding: .utf8) else { return }
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        guard lines.count > maxRows else { return }
        let header = String(lines.first ?? "")
        let tail = lines.suffix(maxRows - 1).map(String.init)
        let combined = ([header] + tail).joined(separator: "\n") + "\n"
        try? combined.write(to: csvFile, atomically: true, encoding: .utf8)
    }
}
