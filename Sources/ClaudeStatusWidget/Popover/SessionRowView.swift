import SwiftUI
import AppKit

struct SessionRowView: View {
    let session: SessionData
    let isStale: Bool
    let dotColor: Color

    var body: some View {
        HStack(spacing: 10) {
            // Colored icon circle (like Control Center icons)
            ZStack {
                Circle()
                    .fill(dotColor.opacity(isStale ? 0.15 : 0.25))
                    .frame(width: 28, height: 28)
                Circle()
                    .fill(dotColor.opacity(isStale ? 0.3 : 1.0))
                    .frame(width: 10, height: 10)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(session.folderName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isStale ? .secondary : .primary)

                if isStale {
                    Text("idle")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    Text("\(session.model) · \(session.context.formattedUsed) / \(session.context.formattedTotal)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Context usage as a ring instead of linear bar
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 3)
                    .frame(width: 28, height: 28)
                Circle()
                    .trim(from: 0, to: Double(session.context.usedPercentage) / 100.0)
                    .stroke(
                        dotColor.opacity(isStale ? 0.3 : 0.8),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(-90))
                Text("\(session.context.usedPercentage)")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(isStale ? 0.03 : 0.06))
        )
        .contentShape(Rectangle())
        .contextMenu {
            Button("Copy Session Info") {
                let info = """
                \(session.folderName) (\(session.model))
                Context: \(session.context.formattedUsed) / \(session.context.formattedTotal) (\(session.context.usedPercentage)%)
                Cost: $\(String(format: "%.2f", session.costUsd))
                Lines: +\(session.linesAdded) / -\(session.linesRemoved)
                """
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(info, forType: .string)
            }
            Button("Open in Finder") {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: session.folderPath)
            }
        }
    }
}
