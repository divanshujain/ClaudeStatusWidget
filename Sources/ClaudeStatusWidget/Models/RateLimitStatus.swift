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
