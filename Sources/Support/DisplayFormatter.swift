import Foundation

enum DisplayFormatter {
    static func percent(_ value: Double?) -> String {
        guard let value else {
            return "--"
        }
        return "\(Int((value * 100).rounded()))%"
    }

    static func compactPercentSummary(_ rows: [FocusedModelQuota]) -> String {
        rows.map { row in
            "\(row.kind.shortTitle) \(percent(row.remainingPercentage))"
        }
        .joined(separator: " · ")
    }

    static func resetText(milliseconds: Int?) -> String {
        guard let milliseconds, milliseconds > 0 else {
            return "reset unknown"
        }

        let totalMinutes = milliseconds / 60_000
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            return "resets in \(days)d \(hours)h"
        }
        if hours > 0 {
            return "resets in \(hours)h \(minutes)m"
        }
        return "resets in \(minutes)m"
    }

    static func maskedEmail(_ email: String) -> String {
        let parts = email.split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            return email
        }

        let local = parts[0]
        let domain = parts[1]
        let prefix = String(local.prefix(2))
        return "\(prefix)**@\(domain)"
    }

    static func updatedText(_ date: Date?) -> String {
        guard let date else {
            return "not refreshed yet"
        }

        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 60 {
            return "updated now"
        }

        let minutes = seconds / 60
        if minutes < 60 {
            return "updated \(minutes)m ago"
        }

        let hours = minutes / 60
        return "updated \(hours)h ago"
    }
}
