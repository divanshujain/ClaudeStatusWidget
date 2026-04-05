import SwiftUI

struct RateLimitRow: View {
    let label: String
    let percentage: Double
    let status: RateLimitStatusInfo

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text(status.label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(status.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(status.color.opacity(0.15))
                    )
            }

            // Progress bar with rounded ends
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 5)
                    Capsule()
                        .fill(status.color.opacity(0.8))
                        .frame(width: max(geo.size.width * percentage / 100, 4), height: 5)
                }
            }
            .frame(height: 5)

            HStack {
                Text("\(Int(percentage))% used")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(formattedBurnRate) · resets \(formattedReset)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
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
        VStack(alignment: .leading, spacing: 10) {
            Text("USAGE LIMITS")
                .font(.system(size: 10, weight: .semibold))
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
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
    }
}
