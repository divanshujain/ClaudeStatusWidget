import SwiftUI

struct QuotaView: View {
    @ObservedObject var loader: RateLimitHistoryLoader

    var body: some View {
        VStack(spacing: 10) {
            header
            if let stats = loader.stats, !stats.fiveHourWindows.isEmpty {
                BarChart(values: stats.fiveHourWindows)
                    .frame(height: 52)
                    .padding(.horizontal, 16)
                HStack(spacing: 0) {
                    Text("7d ago").font(.system(size: 9)).foregroundColor(.secondary)
                    Spacer()
                    Text("now").font(.system(size: 9)).foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                Divider().padding(.horizontal, 16)
                GaugeRow(label: "5h (7d avg)", value: stats.fiveHourAvg, peak: stats.fiveHourPeak, color: Color(red: 0.39, green: 0.82, blue: 1.0))
                    .padding(.horizontal, 16)
                GaugeRow(label: "7d (14d avg)", value: stats.sevenDayAvg, peak: stats.sevenDayPeak, color: Color(red: 0.75, green: 0.35, blue: 0.95))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            } else {
                Text(loader.stats == nil ? "No history yet" : "Collecting… bars fill as 5h windows complete")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 14)
            }
        }
        .padding(.top, 8)
    }

    private var header: some View {
        HStack {
            Text("Quota · past 7 days")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Spacer()
            if let stats = loader.stats, !stats.fiveHourWindows.isEmpty {
                Text("avg \(Int(stats.fiveHourAvg))% · peak \(Int(stats.fiveHourPeak))%")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
    }
}

private struct BarChart: View {
    let values: [Double]

    var body: some View {
        Canvas { context, size in
            guard !values.isEmpty else { return }
            let n = CGFloat(values.count)
            let slot = size.width / n
            let barWidth = slot * 0.82
            let gap = slot * 0.18

            for (i, v) in values.enumerated() {
                let x = CGFloat(i) * (barWidth + gap) + gap / 2
                let bgRect = CGRect(x: x, y: 0, width: barWidth, height: size.height)
                context.fill(Path(roundedRect: bgRect, cornerRadius: 1.5), with: .color(Color.gray.opacity(0.25)))

                let h = size.height * CGFloat(max(0, min(100, v)) / 100.0)
                let filledRect = CGRect(x: x, y: size.height - h, width: barWidth, height: h)
                context.fill(Path(roundedRect: filledRect, cornerRadius: 1.5), with: .color(barColor(for: v)))
            }
        }
    }

    private func barColor(for pct: Double) -> Color {
        if pct < 50 { return Color(red: 0.19, green: 0.82, blue: 0.35) }
        if pct < 80 { return Color(red: 1.0, green: 0.84, blue: 0.04) }
        return Color(red: 1.0, green: 0.27, blue: 0.23)
    }
}

private struct GaugeRow: View {
    let label: String
    let value: Double
    let peak: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                Spacer()
                Text("\(Int(value))%")
                    .font(.system(size: 14, weight: .bold))
            }
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.25))
                        .frame(height: 8)
                        .offset(y: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: max(0, geo.size.width * CGFloat(min(100, value) / 100)), height: 8)
                        .offset(y: 4)
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: 1.5, height: 14)
                        .offset(x: max(0, geo.size.width * CGFloat(min(100, peak) / 100) - 0.75), y: 1)
                    Text("peak \(Int(peak))%")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .fixedSize()
                        .offset(x: peakLabelX(width: geo.size.width), y: 18)
                }
            }
            .frame(height: 32)
        }
    }

    private func peakLabelX(width: CGFloat) -> CGFloat {
        let raw = width * CGFloat(min(100, peak) / 100) - 22
        return max(0, min(width - 44, raw))
    }
}
