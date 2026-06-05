import AppKit
import SwiftUI

struct AccountQuotaSection: View {
    let store: AntigravityUsageStore
    let account: AccountQuotaPresentation

    @State private var isExpanded: Bool
    @State private var isShowingRemoveAlert = false

    init(store: AntigravityUsageStore, account: AccountQuotaPresentation) {
        self.store = store
        self.account = account
        _isExpanded = State(initialValue: store.isExpanded(email: account.email))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AccountHeader(
                store: store,
                account: account,
                isExpanded: $isExpanded,
                isShowingRemoveAlert: $isShowingRemoveAlert
            )

            if isExpanded {
                expandedContent
            } else {
                collapsedContent
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AntigravityTheme.cardFill, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AntigravityTheme.border, lineWidth: 1)
        )
        .alert("Remove account?", isPresented: $isShowingRemoveAlert) {
            Button("Remove", role: .destructive) {
                store.removeAccount(email: account.email)
            }
            Button("Cancel", role: .cancel) {
            }
        } message: {
            Text("This will remove \(account.email) from Antigravity usage on this Mac.")
        }
        .onChange(of: isExpanded) {
            store.setExpanded(isExpanded, for: account.email)
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        if account.status == .error {
            Text(account.error ?? "Could not check this account.")
                .font(.caption)
                .foregroundStyle(AntigravityTheme.Palette.red)
                .fixedSize(horizontal: false, vertical: true)
        } else if account.rows.isEmpty {
            Text("Target model limits were not found.")
                .font(.caption)
                .foregroundStyle(AntigravityTheme.mutedText)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(account.rows) { row in
                    ModelQuotaRow(row: row)
                }
            }
        }
    }

    @ViewBuilder
    private var collapsedContent: some View {
        if account.status == .error {
            Text(account.error ?? "Could not check this account.")
                .font(.caption)
                .foregroundStyle(AntigravityTheme.Palette.red)
                .lineLimit(2)
        } else if account.rows.isEmpty {
            Text("No focused limits found")
                .font(.caption)
                .foregroundStyle(AntigravityTheme.mutedText)
        } else {
            Text(DisplayFormatter.compactPercentSummary(account.rows))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(AntigravityTheme.quietText)
                .lineLimit(1)
        }
    }
}

private struct AccountHeader: View {
    let store: AntigravityUsageStore
    let account: AccountQuotaPresentation
    @Binding var isExpanded: Bool
    @Binding var isShowingRemoveAlert: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(DisplayFormatter.maskedEmail(account.email))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AntigravityTheme.primaryText)
                        .lineLimit(1)

                    if account.isActive {
                        Text("active")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AntigravityTheme.Palette.aqua)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(AntigravityTheme.Palette.aqua.opacity(0.12), in: .rect(cornerRadius: 8))
                    }
                }

                Text(DisplayFormatter.updatedText(account.updatedAt))
                    .font(.caption2)
                    .foregroundStyle(AntigravityTheme.quietText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Button {
                    copyEmail()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .accessibilityLabel("Copy full email")
                }
                .buttonStyle(CompactIconButtonStyle())
                .help("Copy full email")

                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .accessibilityLabel(isExpanded ? "Collapse limits" : "Expand limits")
                }
                .buttonStyle(CompactIconButtonStyle())
                .help(isExpanded ? "Collapse limits" : "Expand limits")

                Button {
                    isShowingRemoveAlert = true
                } label: {
                    Image(systemName: "trash")
                        .accessibilityLabel("Remove account")
                }
                .buttonStyle(CompactIconButtonStyle())
                .help("Remove account")
                .disabled(store.isMutatingAccounts)
            }
        }
    }

    private func copyEmail() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(account.email, forType: .string)
    }
}
