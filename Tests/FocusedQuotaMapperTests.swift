import XCTest
@testable import AntigravityBar

final class FocusedQuotaMapperTests: XCTestCase {
    func testMapsOnlyTargetModelsAndCombinesGeminiProToWorstRemainingBucket() {
        let snapshot = AntigravityQuotaSnapshot(
            timestamp: "2026-06-05T15:21:06Z",
            method: "google",
            email: "person@example.com",
            models: [
                RawModelQuota(
                    label: "Claude Opus 4.6 (Thinking)",
                    modelId: "claude-opus-4-6-thinking",
                    remainingPercentage: 0.8,
                    isExhausted: false,
                    resetTime: "2026-06-10T03:27:21Z",
                    timeUntilResetMs: 10_000,
                    isAutocompleteOnly: false
                ),
                RawModelQuota(
                    label: "Claude Sonnet 4.6 (Thinking)",
                    modelId: "claude-sonnet-4-6",
                    remainingPercentage: nil,
                    isExhausted: false,
                    resetTime: "2026-06-10T03:27:21Z",
                    timeUntilResetMs: 20_000,
                    isAutocompleteOnly: false
                ),
                RawModelQuota(
                    label: "Gemini 3.1 Pro (High)",
                    modelId: "gemini-3.1-pro-high",
                    remainingPercentage: 0.9,
                    isExhausted: false,
                    resetTime: "2026-06-05T20:21:06Z",
                    timeUntilResetMs: 30_000,
                    isAutocompleteOnly: false
                ),
                RawModelQuota(
                    label: "Gemini 3.1 Pro (Low)",
                    modelId: "gemini-3.1-pro-low",
                    remainingPercentage: 0.4,
                    isExhausted: false,
                    resetTime: "2026-06-05T20:21:06Z",
                    timeUntilResetMs: 40_000,
                    isAutocompleteOnly: false
                ),
                RawModelQuota(
                    label: "Gemini 3 Flash",
                    modelId: "gemini-3-flash",
                    remainingPercentage: 1,
                    isExhausted: false,
                    resetTime: "2026-06-05T20:21:06Z",
                    timeUntilResetMs: 50_000,
                    isAutocompleteOnly: false
                )
            ]
        )

        let rows = FocusedQuotaMapper.focusedRows(from: snapshot)

        XCTAssertEqual(rows.map(\.kind), [.claudeOpus, .claudeSonnet, .geminiPro])
        XCTAssertEqual(rows[0].remainingPercentage, 0.8)
        XCTAssertNil(rows[1].remainingPercentage)
        XCTAssertEqual(rows[2].remainingPercentage, 0.4)
        XCTAssertEqual(rows[2].timeUntilResetMs, 40_000)
    }

    func testUsesGeminiProAgentAliasAsPartOfGeminiProGroup() {
        let snapshot = AntigravityQuotaSnapshot(
            timestamp: "2026-06-05T15:21:06Z",
            method: "google",
            email: nil,
            models: [
                RawModelQuota(
                    label: "Gemini 3.1 Pro (High)",
                    modelId: "gemini-pro-agent",
                    remainingPercentage: 0.7,
                    isExhausted: false,
                    resetTime: nil,
                    timeUntilResetMs: nil,
                    isAutocompleteOnly: false
                )
            ]
        )

        let rows = FocusedQuotaMapper.focusedRows(from: snapshot)

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].kind, .geminiPro)
        XCTAssertEqual(rows[0].remainingPercentage, 0.7)
    }
}
