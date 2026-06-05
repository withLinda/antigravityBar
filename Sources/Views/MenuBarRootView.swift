import SwiftUI

enum MenuBarPanelMetrics {
    static let width: CGFloat = 430
    static let height: CGFloat = 620
    static let contentWidth: CGFloat = 382
}

struct MenuBarRootView: View {
    @Bindable var store: AntigravityUsageStore

    var body: some View {
        ZStack {
            AntigravityTheme.shellFill

            VStack(alignment: .leading, spacing: 16) {
                MenuBarHeaderView(store: store)

                if case .failed(let message) = store.loadState {
                    StatusBanner(message: message)
                }
                if let message = store.accountAddErrorMessage {
                    StatusBanner(message: message)
                }
                if let message = store.accountRemoveErrorMessage {
                    StatusBanner(message: message)
                }

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        if store.accounts.isEmpty && store.loadState == .loading {
                            LoadingStateView()
                        } else if store.accounts.isEmpty {
                            EmptyStateView()
                        } else {
                            ForEach(store.accounts) { account in
                                AccountQuotaSection(store: store, account: account)
                            }
                        }
                    }
                    .frame(width: MenuBarPanelMetrics.contentWidth, alignment: .leading)
                }
                .frame(width: MenuBarPanelMetrics.contentWidth, alignment: .topLeading)

                MenuBarFooterView(store: store)
            }
            .padding(18)
            .frame(width: MenuBarPanelMetrics.width, height: MenuBarPanelMetrics.height, alignment: .topLeading)
        }
        .frame(width: MenuBarPanelMetrics.width, height: MenuBarPanelMetrics.height)
        .preferredColorScheme(.dark)
    }
}

private struct MenuBarHeaderView: View {
    let store: AntigravityUsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AntigravityTheme.accent)

                Text("Antigravity")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AntigravityTheme.primaryText)

                Spacer(minLength: 0)

                StatusPill(store: store)
            }

            Text("\(store.accounts.count) accounts · \(DisplayFormatter.updatedText(store.lastRefreshAt))")
                .font(.caption)
                .foregroundStyle(AntigravityTheme.quietText)
                .lineLimit(1)
        }
    }
}

private struct StatusPill: View {
    let store: AntigravityUsageStore

    var body: some View {
        HStack(spacing: 6) {
            if store.loadState == .loading {
                ProgressView()
                    .controlSize(.mini)
                    .tint(AntigravityTheme.accent)
            }

            Text(store.loadState == .loading ? "Refreshing" : store.statusBarPercentText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AntigravityTheme.primaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AntigravityTheme.cardStrongFill, in: .rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AntigravityTheme.border, lineWidth: 1)
        )
    }
}

private struct StatusBanner: View {
    let message: String

    private var footnote: String? {
        guard message.contains("system-visible Node.js install") else {
            return nil
        }

        return "Install Node.js in a system-visible location, then open AntigravityBar again."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AntigravityTheme.Palette.yellow)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(AntigravityTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(AntigravityTheme.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(AntigravityTheme.Palette.yellow.opacity(0.12), in: .rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AntigravityTheme.Palette.yellow.opacity(0.28), lineWidth: 1)
        )
    }
}

private struct LoadingStateView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Checking accounts")
                .font(.headline)
                .foregroundStyle(AntigravityTheme.primaryText)
            Text("This can take a few seconds because each Google account is checked one by one.")
                .font(.caption)
                .foregroundStyle(AntigravityTheme.mutedText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AntigravityTheme.cardFill, in: .rect(cornerRadius: 16))
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No accounts found")
                .font(.headline)
                .foregroundStyle(AntigravityTheme.primaryText)
            Text("Add a Google account. Quotas will appear here after login.")
                .font(.caption)
                .foregroundStyle(AntigravityTheme.mutedText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AntigravityTheme.cardFill, in: .rect(cornerRadius: 16))
    }
}

private struct MenuBarFooterView: View {
    let store: AntigravityUsageStore

    var body: some View {
        HStack(spacing: 8) {
            Button {
                store.addAccount()
            } label: {
                AddAccountButtonLabel(isAdding: store.accountAddState == .adding)
            }
            .buttonStyle(QuietButtonStyle())
            .disabled(store.loadState == .loading || store.isMutatingAccounts)
            .help("Add another Google account")

            Button {
                store.refresh(force: true)
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(QuietButtonStyle())
            .disabled(store.loadState == .loading || store.isMutatingAccounts)

            Spacer(minLength: 0)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(IconButtonStyle())
            .help("Quit AntigravityBar")
        }
    }
}

private struct AddAccountButtonLabel: View {
    let isAdding: Bool

    var body: some View {
        HStack(spacing: 6) {
            if isAdding {
                ProgressView()
                    .controlSize(.mini)
                    .tint(AntigravityTheme.accent)
            } else {
                Image(systemName: "person.badge.plus")
            }

            Text(isAdding ? "Adding Account" : "Add Account")
        }
        .accessibilityLabel(isAdding ? "Adding Google account" : "Add Google account")
    }
}
