import SwiftUI

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AntigravityTheme.primaryText)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(
                configuration.isPressed ? AntigravityTheme.cardStrongFill : AntigravityTheme.cardFill,
                in: .rect(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AntigravityTheme.border, lineWidth: 1)
            )
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(AntigravityTheme.mutedText)
            .background(
                configuration.isPressed ? AntigravityTheme.cardStrongFill : AntigravityTheme.cardFill,
                in: .rect(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AntigravityTheme.border, lineWidth: 1)
            )
    }
}

struct CompactIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AntigravityTheme.mutedText)
            .frame(width: 28, height: 28)
            .background(
                configuration.isPressed ? AntigravityTheme.cardStrongFill : AntigravityTheme.cardFill,
                in: .rect(cornerRadius: 9)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(AntigravityTheme.border, lineWidth: 1)
            )
    }
}
