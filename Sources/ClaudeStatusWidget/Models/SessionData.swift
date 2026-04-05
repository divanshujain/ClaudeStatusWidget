import Foundation

struct ContextInfo: Codable {
    let usedTokens: Int
    let totalTokens: Int
    let usedPercentage: Int

    enum CodingKeys: String, CodingKey {
        case usedTokens = "used_tokens"
        case totalTokens = "total_tokens"
        case usedPercentage = "used_percentage"
    }

    var formattedUsed: String {
        formatTokenCount(usedTokens)
    }

    var formattedTotal: String {
        formatTokenCount(totalTokens)
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            let millions = Double(count) / 1_000_000.0
            if millions == millions.rounded() {
                return "\(Int(millions))M"
            }
            return String(format: "%.1fM", millions)
        }
        let thousands = Double(count) / 1000.0
        if thousands == thousands.rounded() {
            return "\(Int(thousands))k"
        }
        return String(format: "%.1fk", thousands)
    }
}

struct RateLimitWindow: Codable {
    let usedPercentage: Double
    let resetsAt: TimeInterval

    enum CodingKeys: String, CodingKey {
        case usedPercentage = "used_percentage"
        case resetsAt = "resets_at"
    }
}

struct RateLimits: Codable {
    let fiveHour: RateLimitWindow
    let sevenDay: RateLimitWindow

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }
}

struct SessionData: Codable {
    let sessionId: String
    let pid: Int
    let folderName: String
    let folderPath: String
    let model: String
    let context: ContextInfo
    let rateLimits: RateLimits?
    let costUsd: Double
    let linesAdded: Int
    let linesRemoved: Int
    let timestamp: TimeInterval

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case pid
        case folderName = "folder_name"
        case folderPath = "folder_path"
        case model
        case context
        case rateLimits = "rate_limits"
        case costUsd = "cost_usd"
        case linesAdded = "lines_added"
        case linesRemoved = "lines_removed"
        case timestamp
    }
}
