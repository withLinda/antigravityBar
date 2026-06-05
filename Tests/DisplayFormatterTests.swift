import XCTest
@testable import AntigravityBar

final class DisplayFormatterTests: XCTestCase {
    func testCompactPercentSummaryUsesOnlyVisiblePercentages() {
        let rows = [
            FocusedModelQuota(
                kind: .claudeOpus,
                remainingPercentage: 0.4,
                isExhausted: false,
                resetTime: nil,
                timeUntilResetMs: nil,
                sourceLabels: []
            ),
            FocusedModelQuota(
                kind: .claudeSonnet,
                remainingPercentage: nil,
                isExhausted: false,
                resetTime: nil,
                timeUntilResetMs: nil,
                sourceLabels: []
            ),
            FocusedModelQuota(
                kind: .geminiPro,
                remainingPercentage: 0.8,
                isExhausted: false,
                resetTime: nil,
                timeUntilResetMs: nil,
                sourceLabels: []
            )
        ]

        XCTAssertEqual(
            DisplayFormatter.compactPercentSummary(rows),
            "Opus 40% · Sonnet -- · Gemini 80%"
        )
    }
}
