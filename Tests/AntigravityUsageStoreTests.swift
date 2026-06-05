import XCTest
@testable import AntigravityBar

@MainActor
final class AntigravityUsageStoreTests: XCTestCase {
    func testAddAccountRunsAddCommandThenRefreshesAccounts() async throws {
        let recorder = StoreCommandRecorder()
        let client = AntigravityUsageCLIClient(
            executableSearchPaths: ["/usr/bin/true"],
            runner: { arguments, executablePath in
                await recorder.record(arguments: arguments, executablePath: executablePath)

                if arguments == AntigravityUsageCLIClient.addAccountArguments {
                    return "Account added successfully"
                }

                return """
                [
                  {
                    "email": "person@example.com",
                    "isActive": true,
                    "status": "success",
                    "snapshot": {
                      "timestamp": "2026-06-05T15:21:06.249Z",
                      "method": "google",
                      "email": "person@example.com",
                      "models": []
                    }
                  }
                ]
                """
            }
        )
        let store = AntigravityUsageStore(client: client)

        store.addAccount()

        try await waitUntil {
            store.loadState == .loaded && store.accounts.count == 1
        }

        let commands = await recorder.commands.map(\.arguments)
        XCTAssertEqual(commands, [
            ["accounts", "add"],
            ["quota", "--all", "--json", "--all-models", "--refresh"]
        ])
        XCTAssertEqual(store.accountAddState, .idle)
        XCTAssertEqual(store.accounts.first?.email, "person@example.com")
    }

    func testAddAccountQueuesForcedRefreshWhenRefreshAlreadyRunning() async throws {
        let recorder = StoreCommandRecorder()
        let gate = AsyncGate()
        let refreshArguments = AntigravityUsageCLIClient.allAccountsArguments(forceRefresh: true)
        let client = AntigravityUsageCLIClient(
            executableSearchPaths: ["/usr/bin/true"],
            runner: { arguments, executablePath in
                await recorder.record(arguments: arguments, executablePath: executablePath)

                if arguments == AntigravityUsageCLIClient.addAccountArguments {
                    return "Account added successfully"
                }

                if arguments == refreshArguments {
                    let refreshCount = await recorder.count(for: refreshArguments)
                    if refreshCount == 1 {
                        await gate.wait()
                        return accountPayload(email: "old@example.com", timestamp: "2026-06-05T15:21:06.249Z")
                    }

                    return accountPayload(email: "new@example.com", timestamp: "2026-06-05T15:22:06.249Z")
                }

                return ""
            }
        )
        let store = AntigravityUsageStore(client: client)

        store.refresh(force: true)
        store.addAccount()

        await gate.open()

        try await waitUntil {
            store.loadState == .loaded && store.accounts.first?.email == "new@example.com"
        }

        let refreshCount = await recorder.count(for: refreshArguments)
        XCTAssertEqual(refreshCount, 2)
    }

    func testRemoveAccountRunsRemoveCommandThenRefreshesAccounts() async throws {
        let recorder = StoreCommandRecorder()
        let refreshArguments = AntigravityUsageCLIClient.allAccountsArguments(forceRefresh: true)
        let client = AntigravityUsageCLIClient(
            executableSearchPaths: ["/usr/bin/true"],
            runner: { arguments, executablePath in
                await recorder.record(arguments: arguments, executablePath: executablePath)

                if arguments == AntigravityUsageCLIClient.removeAccountArguments(email: "person@example.com") {
                    return "Account removed successfully"
                }

                if arguments == refreshArguments {
                    return accountPayload(email: "other@example.com", timestamp: "2026-06-05T15:23:06.249Z")
                }

                return ""
            }
        )
        let store = AntigravityUsageStore(client: client)

        store.removeAccount(email: "person@example.com")

        try await waitUntil {
            store.loadState == .loaded && store.accounts.first?.email == "other@example.com"
        }

        let commands = await recorder.allArguments()
        XCTAssertEqual(commands, [
            ["accounts", "remove", "--force", "person@example.com"],
            refreshArguments
        ])
    }

    private func waitUntil(
        timeout: Duration = .seconds(2),
        condition: @MainActor @escaping () -> Bool
    ) async throws {
        let start = ContinuousClock.now
        while condition() == false {
            if start.duration(to: ContinuousClock.now) > timeout {
                XCTFail("Timed out while waiting for store state.")
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

}

private actor StoreCommandRecorder {
    private(set) var commands: [(arguments: [String], executablePath: String)] = []

    func record(arguments: [String], executablePath: String) {
        commands.append((arguments, executablePath))
    }

    func count(for arguments: [String]) -> Int {
        commands.filter { $0.arguments == arguments }.count
    }

    func allArguments() -> [[String]] {
        commands.map(\.arguments)
    }
}

private actor AsyncGate {
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var isOpen = false

    func wait() async {
        guard isOpen == false else {
            return
        }

        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func open() {
        isOpen = true
        let pending = continuations
        continuations.removeAll()
        pending.forEach { $0.resume() }
    }
}

private func accountPayload(email: String, timestamp: String) -> String {
    """
    [
      {
        "email": "\(email)",
        "isActive": true,
        "status": "success",
        "snapshot": {
          "timestamp": "\(timestamp)",
          "method": "google",
          "email": "\(email)",
          "models": []
        }
      }
    ]
    """
}
