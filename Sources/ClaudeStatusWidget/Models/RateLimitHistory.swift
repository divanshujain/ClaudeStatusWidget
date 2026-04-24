import Foundation

struct RateLimitHistoryEntry {
    let timestamp: TimeInterval
    let sessionId: String
    let fiveHourPct: Double
    let sevenDayPct: Double
    let fiveHourResetsAt: TimeInterval
    let sevenDayResetsAt: TimeInterval
}

struct QuotaStats {
    let fiveHourWindows: [Double]
    let fiveHourAvg: Double
    let fiveHourPeak: Double
    let sevenDayAvg: Double
    let sevenDayPeak: Double
    let sampleCount: Int
}

enum RateLimitHistoryParser {
    static func parse(csv: String) -> [RateLimitHistoryEntry] {
        csv.split(separator: "\n", omittingEmptySubsequences: true)
            .dropFirst()
            .compactMap { line in
                let fields = line.split(separator: ",", omittingEmptySubsequences: false)
                guard fields.count >= 6,
                      let ts = TimeInterval(fields[0]),
                      let fh = Double(fields[2]),
                      let sd = Double(fields[3]),
                      let fhReset = TimeInterval(fields[4]),
                      let sdReset = TimeInterval(fields[5]) else { return nil }
                return RateLimitHistoryEntry(
                    timestamp: ts,
                    sessionId: String(fields[1]),
                    fiveHourPct: fh,
                    sevenDayPct: sd,
                    fiveHourResetsAt: fhReset,
                    sevenDayResetsAt: sdReset
                )
            }
    }

    static func compute(from entries: [RateLimitHistoryEntry], now: TimeInterval = Date().timeIntervalSince1970) -> QuotaStats {
        let sevenDaysAgo = now - 7 * 86400
        let fourteenDaysAgo = now - 14 * 86400

        let recentFiveHour = entries.filter { $0.fiveHourResetsAt >= sevenDaysAgo }
        let windowGroups = Dictionary(grouping: recentFiveHour, by: { $0.fiveHourResetsAt })
        let windowPeaks: [Double] = windowGroups
            .sorted { $0.key < $1.key }
            .map { $0.value.map(\.fiveHourPct).max() ?? 0 }

        let fiveHourAvg = windowPeaks.isEmpty ? 0 : windowPeaks.reduce(0, +) / Double(windowPeaks.count)
        let fiveHourPeak = windowPeaks.max() ?? 0

        let recentSevenDay = entries.filter { $0.timestamp >= fourteenDaysAgo }
        let sevenDayValues = recentSevenDay.map(\.sevenDayPct)
        let sevenDayAvg = sevenDayValues.isEmpty ? 0 : sevenDayValues.reduce(0, +) / Double(sevenDayValues.count)
        let sevenDayPeak = sevenDayValues.max() ?? 0

        return QuotaStats(
            fiveHourWindows: windowPeaks,
            fiveHourAvg: fiveHourAvg,
            fiveHourPeak: fiveHourPeak,
            sevenDayAvg: sevenDayAvg,
            sevenDayPeak: sevenDayPeak,
            sampleCount: entries.count
        )
    }
}
