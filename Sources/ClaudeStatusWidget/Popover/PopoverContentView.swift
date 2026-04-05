import SwiftUI
import AppKit

extension Color {
    static let tertiaryLabel = Color(nsColor: .tertiaryLabelColor)
}

struct PopoverContentView: View {
    @ObservedObject var sessionManager: SessionManager

    var body: some View {
        VStack(spacing: 0) {
            // Sessions list
            if sessionManager.sessions.isEmpty {
                VStack(spacing: 8) {
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
                ScrollView {
                    VStack(spacing: 0) {
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
                .frame(maxHeight: 300)
            }

            Divider()
                .padding(.horizontal, 12)

            // Rate limits
            RateLimitsView(rateLimits: sessionManager.latestRateLimits)

            Divider()
                .padding(.horizontal, 12)

            // Footer: total cost
            HStack {
                Text("Total cost: $\(totalCost, specifier: "%.2f")")
                    .font(.system(size: 10))
                    .foregroundColor(.tertiaryLabel)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(width: 280)
    }

    private var totalCost: Double {
        sessionManager.sessions.reduce(0) { $0 + $1.costUsd }
    }

    private func openInFinder(path: String) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }
}
