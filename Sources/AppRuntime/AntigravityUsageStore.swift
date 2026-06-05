import Foundation
import Observation

@MainActor
@Observable
final class AntigravityUsageStore {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    enum AccountAddState: Equatable {
        case idle
        case adding
        case failed(String)
    }

    enum AccountRemoveState: Equatable {
        case idle
        case removing(String)
        case failed(String)
    }

    @ObservationIgnored
    private let client: AntigravityUsageCLIClient

    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?

    @ObservationIgnored
    private var addAccountTask: Task<Void, Never>?

    @ObservationIgnored
    private var removeAccountTask: Task<Void, Never>?

    @ObservationIgnored
    private var timer: Timer?

    @ObservationIgnored
    private let disclosureStore: AccountDisclosureStore

    @ObservationIgnored
    private var needsForcedRefreshAfterCurrentLoad = false

    var loadState: LoadState = .idle
    var accountAddState: AccountAddState = .idle
    var accountRemoveState: AccountRemoveState = .idle
    var accounts: [AccountQuotaPresentation] = []
    var lastRefreshAt: Date?

    init(
        client: AntigravityUsageCLIClient = AntigravityUsageCLIClient(),
        disclosureStore: AccountDisclosureStore = AccountDisclosureStore()
    ) {
        self.client = client
        self.disclosureStore = disclosureStore
    }

    func start() {
        refresh(force: true)
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh(force: true)
            }
        }
    }

    func refresh(force: Bool) {
        requestRefresh(force: force)
    }

    func addAccount() {
        guard accountAddState != .adding, removingAccountEmail == nil else {
            return
        }

        addAccountTask?.cancel()
        accountAddState = .adding

        addAccountTask = Task { [client] in
            do {
                try await client.addAccount()
                guard Task.isCancelled == false else {
                    return
                }

                accountAddState = .idle
                requestRefresh(force: true)
            } catch {
                guard Task.isCancelled == false else {
                    return
                }

                accountAddState = .failed(error.localizedDescription)
            }
        }
    }

    func removeAccount(email: String) {
        guard accountAddState != .adding, removingAccountEmail == nil else {
            return
        }

        removeAccountTask?.cancel()
        accountRemoveState = .removing(email)

        removeAccountTask = Task { [client] in
            do {
                try await client.removeAccount(email: email)
                guard Task.isCancelled == false else {
                    return
                }

                accountRemoveState = .idle
                requestRefresh(force: true)
            } catch {
                guard Task.isCancelled == false else {
                    return
                }

                accountRemoveState = .failed(error.localizedDescription)
            }
        }
    }

    func isExpanded(email: String) -> Bool {
        disclosureStore.isExpanded(email: email)
    }

    func setExpanded(_ isExpanded: Bool, for email: String) {
        disclosureStore.setExpanded(isExpanded, for: email)
    }

    private func requestRefresh(force: Bool) {
        guard loadState != .loading else {
            needsForcedRefreshAfterCurrentLoad = needsForcedRefreshAfterCurrentLoad || force
            return
        }

        refreshTask?.cancel()
        loadState = .loading

        refreshTask = Task { [client] in
            do {
                let results = try await client.fetchAllAccounts(forceRefresh: force)
                let presentations = FocusedQuotaMapper.accountPresentations(from: results)
                guard Task.isCancelled == false else {
                    return
                }

                accounts = presentations
                lastRefreshAt = Date()
                loadState = .loaded
                runQueuedRefreshIfNeeded()
            } catch {
                guard Task.isCancelled == false else {
                    return
                }

                loadState = .failed(error.localizedDescription)
                runQueuedRefreshIfNeeded()
            }
        }
    }

    private func runQueuedRefreshIfNeeded() {
        guard needsForcedRefreshAfterCurrentLoad else {
            return
        }

        needsForcedRefreshAfterCurrentLoad = false
        requestRefresh(force: true)
    }

    var statusBarPercentText: String {
        let percentages = accounts.flatMap(\.rows).compactMap(\.remainingPercentage)
        guard let lowest = percentages.min() else {
            return "--"
        }
        return DisplayFormatter.percent(lowest)
    }

    var statusBarAccessibilityText: String {
        switch loadState {
        case .idle:
            return "AntigravityBar idle"
        case .loading:
            return "AntigravityBar refreshing"
        case .loaded:
            return "AntigravityBar lowest quota \(statusBarPercentText)"
        case .failed(let message):
            return "AntigravityBar failed: \(message)"
        }
    }

    var accountAddErrorMessage: String? {
        if case .failed(let message) = accountAddState {
            return message
        }
        return nil
    }

    var accountRemoveErrorMessage: String? {
        if case .failed(let message) = accountRemoveState {
            return message
        }
        return nil
    }

    var removingAccountEmail: String? {
        if case .removing(let email) = accountRemoveState {
            return email
        }
        return nil
    }

    var isMutatingAccounts: Bool {
        accountAddState == .adding || removingAccountEmail != nil
    }
}
