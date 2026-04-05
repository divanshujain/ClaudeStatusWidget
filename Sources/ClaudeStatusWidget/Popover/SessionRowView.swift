import SwiftUI
import AppKit

struct SessionRowView: View {
    let session: SessionData
    let isStale: Bool
    let dotColor: Color

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(dotColor.opacity(isStale ? 0.3 : 1.0))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.folderName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isStale ? .secondary : .primary)

                if isStale {
                    Text("idle")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    Text("\(session.model) · \(session.context.formattedUsed) / \(session.context.formattedTotal)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Circular progress ring
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.1), lineWidth: 3)
                    .frame(width: 30, height: 30)
                Circle()
                    .trim(from: 0, to: Double(session.context.usedPercentage) / 100.0)
                    .stroke(
                        dotColor.opacity(isStale ? 0.3 : 0.8),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 30, height: 30)
                    .rotationEffect(.degrees(-90))
                Text("\(session.context.usedPercentage)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
