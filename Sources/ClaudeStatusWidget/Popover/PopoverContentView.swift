import SwiftUI
import AppKit

extension Color {
    static let tertiaryLabel = Color(nsColor: .tertiaryLabelColor)
    static let cardBackground = Color(nsColor: NSColor(white: 1.0, alpha: 0.07))
}

struct PopoverContentView: View {
    @ObservedObject var sessionManager: SessionManager

    var body: some View {
        VStack(spacing: 8) {
            // Sessions list
            if sessionManager.sessions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "terminal")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text("No active sessions")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("Start a Claude Code session to see it here")
                        .font(.system(size: 11))
                        .foregroundColor(.tertiaryLabel)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.cardBackground)
                )
            } else {
                VStack(spacing: 4) {
                    ForEach(sessionManager.sessions, id: \.sessionId) { session in
                        SessionRowView(
                            session: session,
                            isStale: sessionManager.isStale(sessionId: session.sessionId),
                            dotColor: SessionColorPalette.swiftUIColor(for: session.sessionId)
                        )
                        .onTapGesture {
                            openInFinder(path: session.folderPath)
                        }
                    }
                }
            }

            // Rate limits card
            RateLimitsView(rateLimits: sessionManager.latestRateLimits)

            // Footer
            HStack {
                Text("Total cost: $\(totalCost, specifier: "%.2f")")
                    .font(.system(size: 10))
                    .foregroundColor(.tertiaryLabel)
                Spacer()
            }
            .padding(.horizontal, 4)
        }
        .padding(10)
        .frame(width: 290)
        .background(Color.clear)
    }

    private var totalCost: Double {
        sessionManager.sessions.reduce(0) { $0 + $1.costUsd }
    }

    private func openInFinder(path: String) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }
}
