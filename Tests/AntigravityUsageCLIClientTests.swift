import XCTest
@testable import AntigravityBar

final class AntigravityUsageCLIClientTests: XCTestCase {
    func testDecodesAllAccountsJsonAfterProgressTextPrefix() throws {
        let output = """
        Refreshing quota data for all accounts...

        [
          {
            "email": "person@example.com",
            "isActive": true,
            "status": "success",
            "snapshot": {
              "timestamp": "2026-06-05T15:21:06.249Z",
              "method": "google",
              "email": "person@example.com",
              "models": [
                {
                  "label": "Claude Opus 4.6 (Thinking)",
                  "modelId": "claude-opus-4-6-thinking",
                  "remainingPercentage": 0.2,
                  "isExhausted": false,
                  "resetTime": "2026-06-10T03:27:21Z",
                  "timeUntilResetMs": 389174773,
                  "isAutocompleteOnly": false
                }
              ]
            }
          }
        ]
        """

        let accounts = try AntigravityUsageCLIClient.decodeAccounts(from: output)

        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts[0].email, "person@example.com")
        XCTAssertEqual(accounts[0].status, .success)
        XCTAssertEqual(accounts[0].snapshot?.models.first?.modelId, "claude-opus-4-6-thinking")
    }

    func testBuildsRefreshAllArguments() {
        let arguments = AntigravityUsageCLIClient.allAccountsArguments(forceRefresh: true)

        XCTAssertEqual(arguments, ["quota", "--all", "--json", "--all-models", "--refresh"])
    }

    func testBuildsAddAccountArguments() {
        let arguments = AntigravityUsageCLIClient.addAccountArguments

        XCTAssertEqual(arguments, ["accounts", "add"])
    }

    func testBuildsRemoveAccountArguments() {
        let arguments = AntigravityUsageCLIClient.removeAccountArguments(email: "person@example.com")

        XCTAssertEqual(arguments, ["accounts", "remove", "--force", "person@example.com"])
    }

    func testAddAccountRunsAccountsAddCommand() async throws {
        let recorder = CommandRecorder()
        let client = AntigravityUsageCLIClient(
            executableSearchPaths: ["/usr/bin/true"],
            runner: { arguments, executablePath in
                await recorder.record(arguments: arguments, executablePath: executablePath)
                return "Account added successfully"
            }
        )

        try await client.addAccount()

        let command = await recorder.command
        XCTAssertEqual(command?.arguments, ["accounts", "add"])
        XCTAssertEqual(command?.executablePath, "/usr/bin/true")
    }

    func testRemoveAccountRunsAccountsRemoveCommand() async throws {
        let recorder = CommandRecorder()
        let client = AntigravityUsageCLIClient(
            executableSearchPaths: ["/usr/bin/true"],
            runner: { arguments, executablePath in
                await recorder.record(arguments: arguments, executablePath: executablePath)
                return "Account removed successfully"
            }
        )

        try await client.removeAccount(email: "person@example.com")

        let command = await recorder.command
        XCTAssertEqual(command?.arguments, ["accounts", "remove", "--force", "person@example.com"])
        XCTAssertEqual(command?.executablePath, "/usr/bin/true")
    }
}

private actor CommandRecorder {
    private(set) var command: (arguments: [String], executablePath: String)?

    func record(arguments: [String], executablePath: String) {
        command = (arguments, executablePath)
    }
}
