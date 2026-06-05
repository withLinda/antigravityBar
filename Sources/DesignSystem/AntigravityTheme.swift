import SwiftUI

enum AntigravityTheme {
    enum Palette {
        static let bg0 = Color(hex: "#1E2326")
        static let bg1 = Color(hex: "#272E33")
        static let bg2 = Color(hex: "#2E383C")
        static let bg4 = Color(hex: "#414B50")
        static let fg = Color(hex: "#D3C6AA")
        static let muted = Color(hex: "#9DA9A0")
        static let quiet = Color(hex: "#7A8478")
        static let orange = Color(hex: "#E69875")
        static let red = Color(hex: "#E67E80")
        static let yellow = Color(hex: "#DBBC7F")
        static let green = Color(hex: "#83C092")
        static let aqua = Color(hex: "#7FBBB3")
    }

    static let primaryText = Palette.fg
    static let mutedText = Palette.muted
    static let quietText = Palette.quiet
    static let shellFill = Palette.bg0
    static let cardFill = Palette.bg1.opacity(0.92)
    static let cardStrongFill = Palette.bg2.opacity(0.94)
    static let border = Color(hex: "#4F5B58").opacity(0.44)
    static let accent = Palette.orange

    static func quotaColor(_ value: Double?) -> Color {
        guard let value else {
            return Palette.quiet
        }

        if value >= 0.75 {
            return Palette.green
        }
        if value >= 0.45 {
            return Palette.yellow
        }
        if value >= 0.2 {
            return Palette.orange
        }
        return Palette.red
    }
}

extension Color {
    init(hex: String, alpha: Double = 1) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var intValue: UInt64 = 0
        Scanner(string: value).scanHexInt64(&intValue)

        let red = Double((intValue >> 16) & 0xFF) / 255
        let green = Double((intValue >> 8) & 0xFF) / 255
        let blue = Double(intValue & 0xFF) / 255

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
