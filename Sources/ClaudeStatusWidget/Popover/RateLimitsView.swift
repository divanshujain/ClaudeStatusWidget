import SwiftUI

struct RateLimitRow: View {
    let label: String
    let percentage: Double
    let status: RateLimitStatusInfo

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 12))
                Spacer()
                Text("\(Int(percentage))% · \(formattedBurnRate) · resets \(formattedReset)")
                    .font(.system(size: 11))
                    .foregroundColor(status.color)
            }

            ProgressView(value: percentage, total: 100)
                .progressViewStyle(.linear)
                .tint(status.color)

            HStack {
                Spacer()
                Text(status.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(status.color)
            }
        }
    }

    private var formattedBurnRate: String {
        let rate = status.burnRate
        if rate < 0.1 { return "0%/h" }
        if rate == rate.rounded() {
            return "\(Int(rate))%/h"
        }
        return String(format: "%.1f%%/h", rate)
    }

    private var formattedReset: String {
        RateLimitCalculator.formatDuration(status.resetCountdown)
    }
}

struct RateLimitsView: View {
    let rateLimits: RateLimits?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("USAGE LIMITS")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .tracking(0.5)

            if let limits = rateLimits {
                let now = Date().timeIntervalSince1970
                let fiveHStatus = RateLimitCalculator.status(
                    for: limits.fiveHour, windowDuration: 18000, now: now
                )
                let sevenDStatus = RateLimitCalculator.status(
                    for: limits.sevenDay, windowDuration: 604800, now: now
                )

                RateLimitRow(
                    label: "5-hour",
                    percentage: limits.fiveHour.usedPercentage,
                    status: fiveHStatus
                )

                RateLimitRow(
                    label: "7-day",
                    percentage: limits.sevenDay.usedPercentage,
                    status: sevenDStatus
                )
            } else {
                Text("No usage data yet")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
