import SwiftUI
import AppKit

struct SessionRowView: View {
    let session: SessionData
    let isStale: Bool
    let dotColor: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor.opacity(isStale ? 0.3 : 1.0))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.folderName)
                    .font(.system(size: 12, weight: .medium))
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

            ProgressView(value: Double(session.context.usedPercentage), total: 100)
                .progressViewStyle(.linear)
                .frame(width: 50)
                .tint(dotColor.opacity(isStale ? 0.3 : 1.0))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
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
