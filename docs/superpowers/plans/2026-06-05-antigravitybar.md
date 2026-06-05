# AntigravityBar Account Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add account removal, full-email copy, remembered expand or collapse state, and reliable post-add refresh to the AntigravityBar menu bar panel.

**Architecture:** Keep the app as a native SwiftUI plus AppKit menu bar panel. Extend the CLI client and observable store with remove-account support, queued forced refreshes, and per-email disclosure persistence. Keep the view layer thin by moving persistence and command logic into focused helpers the account cards can call through the store.

**Tech Stack:** Swift 6, SwiftUI, Observation, AppKit `NSStatusItem`, XCTest, XcodeGen.

---

## File Map

- Modify: `Sources/Services/AntigravityUsageCLIClient.swift`
  - add remove-account command support
- Modify: `Sources/AppRuntime/AntigravityUsageStore.swift`
  - add queued refresh handling, remove-account flow, and collapse-state access
- Create: `Sources/AppRuntime/AccountDisclosureStore.swift`
  - persist expanded or collapsed state per email in `UserDefaults`
- Modify: `Sources/Models/QuotaModels.swift`
  - add compact summary helpers if needed by the UI
- Modify: `Sources/Support/DisplayFormatter.swift`
  - add compact percent-summary formatting
- Modify: `Sources/Views/AccountQuotaSection.swift`
  - add copy, collapse, and remove controls plus native confirmation alert
- Modify: `Sources/Views/MenuBarRootView.swift`
  - pass store into account sections
- Modify: `Sources/Views/ButtonStyles.swift`
  - add or refine compact icon-button treatment if needed
- Modify: `Tests/AntigravityUsageCLIClientTests.swift`
  - cover remove-account command arguments and execution
- Modify: `Tests/AntigravityUsageStoreTests.swift`
  - cover queued refresh after add, remove flow, and collapse persistence helper
- Create: `Tests/AccountDisclosureStoreTests.swift`
  - cover remember or restore behavior for collapsed cards

## Tasks

### Task 1: Add failing tests for CLI remove-account support

**Files:**
- Modify: `Tests/AntigravityUsageCLIClientTests.swift`
- Modify: `Sources/Services/AntigravityUsageCLIClient.swift`

- [ ] **Step 1: Write the failing tests**

```swift
func testBuildsRemoveAccountArguments() {
    let arguments = AntigravityUsageCLIClient.removeAccountArguments(email: "person@example.com")

    XCTAssertEqual(arguments, ["accounts", "remove", "--force", "person@example.com"])
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project AntigravityBar.xcodeproj -scheme AntigravityBar -destination 'platform=macOS,arch=arm64' -only-testing:AntigravityBarTests/AntigravityUsageCLIClientTests`

Expected: FAIL because `removeAccountArguments(email:)` and `removeAccount(email:)` do not exist yet.

- [ ] **Step 3: Write minimal implementation**

```swift
func removeAccount(email: String) async throws {
    let executablePath = try executablePath()
    _ = try await runner(Self.removeAccountArguments(email: email), executablePath)
}

static func removeAccountArguments(email: String) -> [String] {
    ["accounts", "remove", "--force", email]
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project AntigravityBar.xcodeproj -scheme AntigravityBar -destination 'platform=macOS,arch=arm64' -only-testing:AntigravityBarTests/AntigravityUsageCLIClientTests`

Expected: PASS

### Task 2: Add failing tests for queued forced refresh and remove flow

**Files:**
- Modify: `Tests/AntigravityUsageStoreTests.swift`
- Modify: `Sources/AppRuntime/AntigravityUsageStore.swift`

- [ ] **Step 1: Write the failing tests**

```swift
func testAddAccountQueuesForcedRefreshWhenRefreshAlreadyRunning() async throws {
    let recorder = StoreCommandRecorder()
    let gate = AsyncGate()
    let client = AntigravityUsageCLIClient(
        executableSearchPaths: ["/usr/bin/true"],
        runner: { arguments, executablePath in
            await recorder.record(arguments: arguments, executablePath: executablePath)

            if arguments == ["quota", "--all", "--json", "--all-models", "--refresh"] {
                let callCount = await recorder.count(for: arguments)
                if callCount == 1 {
                    await gate.wait()
                    return """
                    [{"email":"old@example.com","isActive":true,"status":"success","snapshot":{"timestamp":"2026-06-05T15:21:06.249Z","method":"google","email":"old@example.com","models":[]}}]
                    """
                }

                return """
                [{"email":"new@example.com","isActive":true,"status":"success","snapshot":{"timestamp":"2026-06-05T15:22:06.249Z","method":"google","email":"new@example.com","models":[]}}]
                """
            }

            if arguments == AntigravityUsageCLIClient.addAccountArguments {
                return "Account added successfully"
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

    let refreshCommand = ["quota", "--all", "--json", "--all-models", "--refresh"]
    XCTAssertEqual(await recorder.count(for: refreshCommand), 2)
}

func testRemoveAccountRunsRemoveCommandThenRefreshesAccounts() async throws {
    let recorder = StoreCommandRecorder()
    let client = AntigravityUsageCLIClient(
        executableSearchPaths: ["/usr/bin/true"],
        runner: { arguments, executablePath in
            await recorder.record(arguments: arguments, executablePath: executablePath)

            if arguments == AntigravityUsageCLIClient.removeAccountArguments(email: "person@example.com") {
                return "Account removed"
            }

            return """
            [
              {
                "email": "other@example.com",
                "isActive": true,
                "status": "success",
                "snapshot": {
                  "timestamp": "2026-06-05T15:21:06.249Z",
                  "method": "google",
                  "email": "other@example.com",
                  "models": []
                }
              }
            ]
            """
        }
    )
    let store = AntigravityUsageStore(client: client)

    store.removeAccount(email: "person@example.com")

    try await waitUntil {
        store.loadState == .loaded && store.accounts.first?.email == "other@example.com"
    }

    XCTAssertEqual(await recorder.commands.map(\\.arguments), [
        ["accounts", "remove", "--force", "person@example.com"],
        ["quota", "--all", "--json", "--all-models", "--refresh"]
    ])
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project AntigravityBar.xcodeproj -scheme AntigravityBar -destination 'platform=macOS,arch=arm64' -only-testing:AntigravityBarTests/AntigravityUsageStoreTests`

Expected: FAIL because queued refresh behavior and remove-account store flow do not exist yet.

- [ ] **Step 3: Write minimal implementation**

```swift
@ObservationIgnored private var needsForcedRefreshAfterCurrentLoad = false

private func requestRefresh(force: Bool) {
    if loadState == .loading {
        needsForcedRefreshAfterCurrentLoad = needsForcedRefreshAfterCurrentLoad || force
        return
    }
    startRefresh(force: force)
}

func addAccount() {
    // on success:
    accountAddState = .idle
    requestRefresh(force: true)
}

func removeAccount(email: String) {
    // run client remove, then:
    requestRefresh(force: true)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project AntigravityBar.xcodeproj -scheme AntigravityBar -destination 'platform=macOS,arch=arm64' -only-testing:AntigravityBarTests/AntigravityUsageStoreTests`

Expected: PASS

### Task 3: Add failing tests for collapse-state persistence

**Files:**
- Create: `Tests/AccountDisclosureStoreTests.swift`
- Create: `Sources/AppRuntime/AccountDisclosureStore.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import AntigravityBar

final class AccountDisclosureStoreTests: XCTestCase {
    func testDefaultsToExpandedWhenNoValueWasSaved() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = AccountDisclosureStore(defaults: defaults)

        XCTAssertTrue(store.isExpanded(email: "person@example.com"))
    }

    func testPersistsCollapsedStatePerEmail() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = AccountDisclosureStore(defaults: defaults)

        store.setExpanded(false, for: "person@example.com")
        let reloaded = AccountDisclosureStore(defaults: defaults)

        XCTAssertFalse(reloaded.isExpanded(email: "person@example.com"))
        XCTAssertTrue(reloaded.isExpanded(email: "other@example.com"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project AntigravityBar.xcodeproj -scheme AntigravityBar -destination 'platform=macOS,arch=arm64' -only-testing:AntigravityBarTests/AccountDisclosureStoreTests`

Expected: FAIL because `AccountDisclosureStore` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```swift
struct AccountDisclosureStore {
    private let defaults: UserDefaults
    private let keyPrefix = "accountDisclosure."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isExpanded(email: String) -> Bool {
        guard defaults.object(forKey: keyPrefix + email) != nil else {
            return true
        }
        return defaults.bool(forKey: keyPrefix + email)
    }

    func setExpanded(_ isExpanded: Bool, for email: String) {
        defaults.set(isExpanded, forKey: keyPrefix + email)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project AntigravityBar.xcodeproj -scheme AntigravityBar -destination 'platform=macOS,arch=arm64' -only-testing:AntigravityBarTests/AccountDisclosureStoreTests`

Expected: PASS

### Task 4: Add compact summary formatting and account-card controls

**Files:**
- Modify: `Sources/Support/DisplayFormatter.swift`
- Modify: `Sources/Views/AccountQuotaSection.swift`
- Modify: `Sources/Views/MenuBarRootView.swift`
- Modify: `Sources/Views/ButtonStyles.swift`
- Modify: `Sources/AppRuntime/AntigravityUsageStore.swift`

- [ ] **Step 1: Write the failing test for compact summary formatting**

```swift
func testCompactPercentSummaryUsesOnlyVisiblePercentages() {
    let rows = [
        FocusedModelQuota(kind: .claudeOpus, remainingPercentage: 0.4, isExhausted: false, resetTime: nil, timeUntilResetMs: nil, sourceLabels: []),
        FocusedModelQuota(kind: .claudeSonnet, remainingPercentage: nil, isExhausted: false, resetTime: nil, timeUntilResetMs: nil, sourceLabels: []),
        FocusedModelQuota(kind: .geminiPro, remainingPercentage: 0.8, isExhausted: false, resetTime: nil, timeUntilResetMs: nil, sourceLabels: [])
    ]

    XCTAssertEqual(
        DisplayFormatter.compactPercentSummary(rows),
        "Opus 40% · Sonnet -- · Gemini 80%"
    )
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project AntigravityBar.xcodeproj -scheme AntigravityBar -destination 'platform=macOS,arch=arm64' -only-testing:AntigravityBarTests/FocusedQuotaMapperTests`

Expected: FAIL because `compactPercentSummary(_:)` does not exist yet.

- [ ] **Step 3: Write minimal implementation and view wiring**

```swift
static func compactPercentSummary(_ rows: [FocusedModelQuota]) -> String {
    rows.map { row in
        "\(row.kind.shortTitle) \(percent(row.remainingPercentage))"
    }.joined(separator: " · ")
}
```

Then update the account card so it:

- copies `account.email` to the pasteboard
- toggles expansion through the disclosure store
- shows `DisplayFormatter.compactPercentSummary(account.rows)` when collapsed
- uses `.alert("Remove account?", isPresented: ...)` for native destructive confirmation

- [ ] **Step 4: Run focused tests and a full app test pass**

Run: `xcodebuild test -project AntigravityBar.xcodeproj -scheme AntigravityBar -destination 'platform=macOS,arch=arm64'`

Expected: PASS
