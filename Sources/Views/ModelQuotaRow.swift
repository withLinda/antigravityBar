import SwiftUI

struct ModelQuotaRow: View {
    let row: FocusedModelQuota

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: row.kind.symbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AntigravityTheme.quotaColor(row.remainingPercentage))
                    .frame(width: 16)

                Text(row.kind.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AntigravityTheme.primaryText)

                Spacer(minLength: 0)

                Text(DisplayFormatter.percent(row.remainingPercentage))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AntigravityTheme.quotaColor(row.remainingPercentage))
            }

            HStack(spacing: 8) {
                ProgressBar(value: row.remainingPercentage, tint: AntigravityTheme.quotaColor(row.remainingPercentage))
                    .frame(height: 6)

                Text(DisplayFormatter.resetText(milliseconds: row.timeUntilResetMs))
                    .font(.caption2)
                    .foregroundStyle(AntigravityTheme.quietText)
                    .frame(width: 86, alignment: .trailing)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.kind.title), \(DisplayFormatter.percent(row.remainingPercentage)), \(DisplayFormatter.resetText(milliseconds: row.timeUntilResetMs))")
    }
}

private struct ProgressBar: View {
    let value: Double?
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(value ?? 0, 0), 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AntigravityTheme.Palette.bg4.opacity(0.72))
                Capsule()
                    .fill(tint)
                    .frame(width: max(4, proxy.size.width * clamped))
            }
        }
    }
}
