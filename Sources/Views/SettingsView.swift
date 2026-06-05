import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AntigravityBar")
                .font(.headline)
            Text("Uses antigravity-usage CLI, adds Google accounts through Google login, and refreshes saved accounts every 5 minutes.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 360, alignment: .leading)
    }
}
