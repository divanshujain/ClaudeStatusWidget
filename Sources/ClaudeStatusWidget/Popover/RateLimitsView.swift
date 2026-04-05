import SwiftUI

struct RateLimitRow: View {
    let label: String
    let percentage: Double
    let status: RateLimitStatusInfo

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text(status.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(status.color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: 4)
                    Capsule()
                        .fill(status.color)
                        .frame(width: max(geo.size.width * percentage / 100, 4), height: 4)
                }
            }
            .frame(height: 4)

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
        VStack(spacing: 0) {
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
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Divider()

                RateLimitRow(
                    label: "7-day",
                    percentage: limits.sevenDay.usedPercentage,
                    status: sevenDStatus
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            } else {
                Text("No usage data yet")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
        }
    }
}
