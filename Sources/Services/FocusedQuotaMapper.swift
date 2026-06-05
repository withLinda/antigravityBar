import Foundation

enum FocusedQuotaMapper {
    static func focusedRows(from snapshot: AntigravityQuotaSnapshot) -> [FocusedModelQuota] {
        FocusedModelKind.allCases.compactMap { kind in
            focusedRow(kind: kind, models: snapshot.models)
        }
    }

    static func accountPresentations(from results: [AllAccountsQuotaResult]) -> [AccountQuotaPresentation] {
        results.map { result in
            AccountQuotaPresentation(
                email: result.email,
                isActive: result.isActive,
                status: result.status,
                rows: result.snapshot.map(focusedRows(from:)) ?? [],
                error: result.error,
                updatedAt: result.snapshot.flatMap { parseDate($0.timestamp) }
            )
        }
    }

    private static func focusedRow(kind: FocusedModelKind, models: [RawModelQuota]) -> FocusedModelQuota? {
        let matchingModels = models.filter { matches(model: $0, kind: kind) }
        guard matchingModels.isEmpty == false else {
            return nil
        }

        let representative = worstModel(in: matchingModels)
        return FocusedModelQuota(
            kind: kind,
            remainingPercentage: representative.remainingPercentage,
            isExhausted: matchingModels.contains(where: \.isExhausted),
            resetTime: representative.resetTime,
            timeUntilResetMs: representative.timeUntilResetMs,
            sourceLabels: matchingModels.map(\.label)
        )
    }

    private static func worstModel(in models: [RawModelQuota]) -> RawModelQuota {
        models.min { left, right in
            let leftScore = left.remainingPercentage ?? (left.isExhausted ? 0 : 1)
            let rightScore = right.remainingPercentage ?? (right.isExhausted ? 0 : 1)
            return leftScore < rightScore
        } ?? models[0]
    }

    private static func matches(model: RawModelQuota, kind: FocusedModelKind) -> Bool {
        let id = model.modelId.lowercased()
        let label = model.label.lowercased()

        switch kind {
        case .claudeOpus:
            return id.contains("claude-opus") || label.contains("claude opus")
        case .claudeSonnet:
            return id.contains("claude-sonnet") || label.contains("claude sonnet")
        case .geminiPro:
            return id == "gemini-pro-agent"
                || id.contains("gemini-3.1-pro")
                || label.contains("gemini 3.1 pro")
        }
    }

    private static func parseDate(_ value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
