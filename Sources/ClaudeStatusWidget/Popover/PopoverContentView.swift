import SwiftUI
import AppKit

extension Color {
    static let tertiaryLabel = Color(nsColor: .tertiaryLabelColor)
}

struct PopoverContentView: View {
    @ObservedObject var sessionManager: SessionManager

    var body: some View {
        VStack(spacing: 0) {
            // Title
            HStack {
                Text("Claude Code Status")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()

            // Sessions list
            if sessionManager.sessions.isEmpty {
                VStack(spacing: 6) {
                    Text("No active sessions")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("Start a Claude Code session to see it here")
                        .font(.system(size: 11))
                        .foregroundColor(.tertiaryLabel)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sessionManager.sessions.enumerated()), id: \.element.sessionId) { index, session in
                        SessionRowView(
                            session: session,
                            isStale: sessionManager.isStale(sessionId: session.sessionId),
                            dotColor: SessionColorPalette.swiftUIColor(for: session.sessionId)
                        )
                        .onTapGesture {
                            openInFinder(path: session.folderPath)
                        }

                        if index < sessionManager.sessions.count - 1 {
                            Divider()
                        }
                    }
                }
            }

            Divider()

            // Rate limits
            RateLimitsView(rateLimits: sessionManager.latestRateLimits)

            Divider()

            Divider()

            QuotaView(loader: SessionManagerGlobal.shared.rateLimitHistoryLoader)

            Divider()

            // Footer
            HStack {
                Text("Total cost: $\(totalCost, specifier: "%.2f")")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .frame(width: 320)
    }

    private var totalCost: Double {
        sessionManager.sessions.reduce(0) { $0 + $1.costUsd }
    }

    private func openInFinder(path: String) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }
}
