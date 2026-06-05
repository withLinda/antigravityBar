import Foundation

struct AllAccountsQuotaResult: Decodable, Equatable, Sendable, Identifiable {
    enum Status: String, Decodable, Sendable {
        case success
        case error
        case cached
    }

    var id: String { email }

    let email: String
    let isActive: Bool
    let status: Status
    let snapshot: AntigravityQuotaSnapshot?
    let error: String?
    let cacheAge: Int?

    init(
        email: String,
        isActive: Bool,
        status: Status,
        snapshot: AntigravityQuotaSnapshot? = nil,
        error: String? = nil,
        cacheAge: Int? = nil
    ) {
        self.email = email
        self.isActive = isActive
        self.status = status
        self.snapshot = snapshot
        self.error = error
        self.cacheAge = cacheAge
    }
}

struct AntigravityQuotaSnapshot: Decodable, Equatable, Sendable {
    let timestamp: String
    let method: String
    let email: String?
    let models: [RawModelQuota]
}

struct RawModelQuota: Decodable, Equatable, Sendable {
    let label: String
    let modelId: String
    let remainingPercentage: Double?
    let isExhausted: Bool
    let resetTime: String?
    let timeUntilResetMs: Int?
    let isAutocompleteOnly: Bool?
}

enum FocusedModelKind: String, CaseIterable, Sendable {
    case claudeOpus
    case claudeSonnet
    case geminiPro

    var title: String {
        switch self {
        case .claudeOpus:
            return "Claude Opus"
        case .claudeSonnet:
            return "Claude Sonnet"
        case .geminiPro:
            return "Gemini 3.1 Pro"
        }
    }

    var symbolName: String {
        switch self {
        case .claudeOpus:
            return "sparkles"
        case .claudeSonnet:
            return "waveform.path.ecg"
        case .geminiPro:
            return "diamond.fill"
        }
    }

    var shortTitle: String {
        switch self {
        case .claudeOpus:
            return "Opus"
        case .claudeSonnet:
            return "Sonnet"
        case .geminiPro:
            return "Gemini"
        }
    }
}

struct FocusedModelQuota: Equatable, Identifiable, Sendable {
    var id: FocusedModelKind { kind }

    let kind: FocusedModelKind
    let remainingPercentage: Double?
    let isExhausted: Bool
    let resetTime: String?
    let timeUntilResetMs: Int?
    let sourceLabels: [String]
}

struct AccountQuotaPresentation: Equatable, Identifiable, Sendable {
    var id: String { email }

    let email: String
    let isActive: Bool
    let status: AllAccountsQuotaResult.Status
    let rows: [FocusedModelQuota]
    let error: String?
    let updatedAt: Date?
}
