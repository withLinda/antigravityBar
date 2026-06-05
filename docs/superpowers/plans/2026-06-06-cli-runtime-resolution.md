# AntigravityBar CLI Runtime Resolution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make AntigravityBar launch `antigravity-usage` reliably from a GUI app by supporting common GUI-discoverable Node installs and showing a clear setup error for shell-only Node installs.

**Architecture:** Keep `AntigravityUsageCLIClient` as the public CLI entry point, but move launch-path decisions into a focused resolver. The resolver should decide whether to run the CLI directly or run `node` explicitly with the CLI script path, based on the wrapper file contents and a fixed list of GUI-safe Node locations. User-facing failures should become structured setup errors instead of leaking raw `env: node` text.

**Tech Stack:** Swift 6, Foundation `Process`, SwiftUI, Observation, XCTest, XcodeGen.

---

## File Map

- Modify: `Sources/Services/AntigravityUsageCLIClient.swift`
  - replace direct executable launch logic with resolved launch plans and clearer setup errors
- Create: `Sources/Services/AntigravityCLIResolution.swift`
  - resolve CLI wrapper path, inspect shebang, resolve Node path, and build the final launch plan
- Modify: `Sources/AppRuntime/AntigravityUsageStore.swift`
  - keep surfacing localized errors, but verify setup failures flow through cleanly
- Modify: `Sources/Views/MenuBarRootView.swift`
  - show a short friendly setup hint when the failure is a CLI or Node setup issue
- Modify: `README.md`
  - explain that the app needs both `antigravity-usage` and a GUI-discoverable Node install
- Modify: `Tests/AntigravityUsageCLIClientTests.swift`
  - cover launch-plan behavior and setup error mapping
- Create: `Tests/AntigravityCLIResolutionTests.swift`
  - cover resolver fallback order, shebang inspection, and setup failures
- Modify: `Tests/AntigravityUsageStoreTests.swift`
  - cover setup-error propagation into store state

## Launch Fallback Order

The implementation should follow this order exactly:

1. Find `antigravity-usage` from the existing explicit CLI search paths.
2. Read the first line of that file.
3. If the file does **not** use `#!/usr/bin/env node`, run it directly as today.
4. If the file **does** use `#!/usr/bin/env node`, resolve `node` from a fixed GUI-safe list:
   - `/opt/homebrew/bin/node`
   - `/usr/local/bin/node`
   - `/Library/Frameworks/Node.js/Versions/Current/bin/node`
5. If one of those Node binaries exists and is executable, run:
   - `node <resolved-antigravity-usage-path> <arguments>`
6. If no GUI-safe Node binary is found, fail with a clear setup error that explains:
   - AntigravityBar found `antigravity-usage`
   - but it could not find a system-visible Node runtime
   - shell-only installs like `nvm`, `fnm`, or `asdf` may work in Terminal but not in a GUI app
7. Do **not** try to scrape shell startup files or emulate interactive shells.
8. Do **not** silently mutate `PATH` to many guessed directories.

## Tasks

### Task 1: Add failing resolver tests for the safe fallback order

**Files:**
- Create: `Tests/AntigravityCLIResolutionTests.swift`
- Create: `Sources/Services/AntigravityCLIResolution.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import AntigravityBar

final class AntigravityCLIResolutionTests: XCTestCase {
    func testUsesDirectLaunchForNonNodeWrapper() throws {
        let resolver = AntigravityCLIResolution(
            executableSearchPaths: ["/mock/antigravity-usage"],
            fileExists: { path in path == "/mock/antigravity-usage" },
            readFirstLine: { _ in "#!/bin/bash" }
        )

        let plan = try resolver.makeLaunchPlan(arguments: ["quota", "--all"])

        XCTAssertEqual(plan.executablePath, "/mock/antigravity-usage")
        XCTAssertEqual(plan.arguments, ["quota", "--all"])
    }

    func testUsesExplicitNodeForEnvNodeWrapper() throws {
        let resolver = AntigravityCLIResolution(
            executableSearchPaths: ["/mock/antigravity-usage"],
            nodeSearchPaths: ["/missing/node", "/usr/local/bin/node"],
            fileExists: { path in
                path == "/mock/antigravity-usage" || path == "/usr/local/bin/node"
            },
            readFirstLine: { _ in "#!/usr/bin/env node" }
        )

        let plan = try resolver.makeLaunchPlan(arguments: ["accounts", "add"])

        XCTAssertEqual(plan.executablePath, "/usr/local/bin/node")
        XCTAssertEqual(plan.arguments, ["/mock/antigravity-usage", "accounts", "add"])
    }

    func testThrowsNodeRuntimeNotFoundForShellOnlySetup() {
        let resolver = AntigravityCLIResolution(
            executableSearchPaths: ["/mock/antigravity-usage"],
            nodeSearchPaths: ["/opt/homebrew/bin/node", "/usr/local/bin/node"],
            fileExists: { path in path == "/mock/antigravity-usage" },
            readFirstLine: { _ in "#!/usr/bin/env node" }
        )

        XCTAssertThrowsError(try resolver.makeLaunchPlan(arguments: ["quota"])) { error in
            XCTAssertEqual(error as? AntigravityCLIResolution.ResolutionError, .nodeRuntimeNotFound)
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project AntigravityBar.xcodeproj -scheme AntigravityBar -destination 'platform=macOS,arch=arm64' -only-testing:AntigravityBarTests/AntigravityCLIResolutionTests`

Expected: FAIL because `AntigravityCLIResolution`, `LaunchPlan`, and `ResolutionError` do not exist yet.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

struct AntigravityCLIResolution: Sendable {
    struct LaunchPlan: Equatable {
        let executablePath: String
        let arguments: [String]
    }

    enum ResolutionError: LocalizedError, Equatable {
        case cliNotFound
        case nodeRuntimeNotFound
    }

    let executableSearchPaths: [String]
    let nodeSearchPaths: [String]
    let fileExists: @Sendable (String) -> Bool
    let readFirstLine: @Sendable (String) throws -> String

    init(
        executableSearchPaths: [String] = [
            "/opt/homebrew/bin/antigravity-usage",
            "/usr/local/bin/antigravity-usage",
            "/usr/bin/antigravity-usage"
        ],
        nodeSearchPaths: [String] = [
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/Library/Frameworks/Node.js/Versions/Current/bin/node"
        ],
        fileExists: @escaping @Sendable (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) },
        readFirstLine: @escaping @Sendable (String) throws -> String = Self.readFirstLine(at:)
    ) {
        self.executableSearchPaths = executableSearchPaths
        self.nodeSearchPaths = nodeSearchPaths
        self.fileExists = fileExists
        self.readFirstLine = readFirstLine
    }

    func makeLaunchPlan(arguments: [String]) throws -> LaunchPlan {
        guard let cliPath = executableSearchPaths.first(where: fileExists) else {
            throw ResolutionError.cliNotFound
        }

        let firstLine = (try? readFirstLine(cliPath)) ?? ""
        if firstLine == "#!/usr/bin/env node" {
            guard let nodePath = nodeSearchPaths.first(where: fileExists) else {
                throw ResolutionError.nodeRuntimeNotFound
            }

            return LaunchPlan(
                executablePath: nodePath,
                arguments: [cliPath] + arguments
            )
        }

        return LaunchPlan(
            executablePath: cliPath,
            arguments: arguments
        )
    }

    private static func readFirstLine(at path: String) throws -> String {
        let text = try String(contentsOfFile: path, encoding: .utf8)
        return text.split(separator: "\n", omittingEmptySubsequences: false).first.map(String.init) ?? ""
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project AntigravityBar.xcodeproj -scheme AntigravityBar -destination 'platform=macOS,arch=arm64' -only-testing:AntigravityBarTests/AntigravityCLIResolutionTests`

Expected: PASS

### Task 2: Add failing client tests for launch-plan execution and friendly setup errors

**Files:**
- Modify: `Tests/AntigravityUsageCLIClientTests.swift`
- Modify: `Sources/Services/AntigravityUsageCLIClient.swift`

- [ ] **Step 1: Write the failing tests**

```swift
func testFetchAllAccountsRunsResolvedNodeLaunchPlan() async throws {
    let recorder = CommandRecorder()
    let resolver = AntigravityCLIResolution(
        executableSearchPaths: ["/mock/antigravity-usage"],
        nodeSearchPaths: ["/usr/local/bin/node"],
        fileExists: { _ in true },
        readFirstLine: { _ in "#!/usr/bin/env node" }
    )
    let client = AntigravityUsageCLIClient(
        resolver: resolver,
        runner: { arguments, executablePath in
            await recorder.record(arguments: arguments, executablePath: executablePath)
            return "[]"
        }
    )

    _ = try await client.fetchAllAccounts(forceRefresh: false)

    let command = await recorder.command
    XCTAssertEqual(command?.executablePath, "/usr/local/bin/node")
    XCTAssertEqual(command?.arguments, ["/mock/antigravity-usage", "quota", "--all", "--json", "--all-models"])
}

func testMapsMissingNodeRuntimeToFriendlyError() async {
    let resolver = AntigravityCLIResolution(
        executableSearchPaths: ["/mock/antigravity-usage"],
        nodeSearchPaths: ["/usr/local/bin/node"],
        fileExists: { path in path == "/mock/antigravity-usage" },
        readFirstLine: { _ in "#!/usr/bin/env node" }
    )
    let client = AntigravityUsageCLIClient(resolver: resolver)

    do {
        _ = try await client.fetchAllAccounts(forceRefresh: true)
        XCTFail("Expected an error")
    } catch {
        XCTAssertEqual(
            error.localizedDescription,
            "AntigravityBar found antigravity-usage, but it could not find a system-visible Node.js install. Shell-only installs like nvm, fnm, or asdf may work in Terminal but not in this app."
        )
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project AntigravityBar.xcodeproj -scheme AntigravityBar -destination 'platform=macOS,arch=arm64' -only-testing:AntigravityBarTests/AntigravityUsageCLIClientTests`

Expected: FAIL because the client still searches only for a direct executable path and does not accept a resolver dependency.

- [ ] **Step 3: Write minimal implementation**

```swift
struct AntigravityUsageCLIClient: Sendable {
    enum ClientError: LocalizedError, Equatable {
        case executableNotFound
        case nodeRuntimeNotFound
        case jsonNotFound
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .executableNotFound:
                return "antigravity-usage CLI was not found."
            case .nodeRuntimeNotFound:
                return "AntigravityBar found antigravity-usage, but it could not find a system-visible Node.js install. Shell-only installs like nvm, fnm, or asdf may work in Terminal but not in this app."
            case .jsonNotFound:
                return "The CLI did not return JSON."
            case .commandFailed(let message):
                return message.isEmpty ? "The CLI command failed." : message
            }
        }
    }

    let resolver: AntigravityCLIResolution
    let runner: @Sendable ([String], String) async throws -> String

    init(
        resolver: AntigravityCLIResolution = AntigravityCLIResolution(),
        runner: @escaping @Sendable ([String], String) async throws -> String = Self.runProcess(arguments:executablePath:)
    ) {
        self.resolver = resolver
        self.runner = runner
    }

    private func output(for arguments: [String]) async throws -> String {
        do {
            let plan = try resolver.makeLaunchPlan(arguments: arguments)
            return try await runner(plan.arguments, plan.executablePath)
        } catch let error as AntigravityCLIResolution.ResolutionError {
            switch error {
            case .cliNotFound:
                throw ClientError.executableNotFound
            case .nodeRuntimeNotFound:
                throw ClientError.nodeRuntimeNotFound
            }
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project AntigravityBar.xcodeproj -scheme AntigravityBar -destination 'platform=macOS,arch=arm64' -only-testing:AntigravityBarTests/AntigravityUsageCLIClientTests`

Expected: PASS

### Task 3: Add store-level and UI-level proof for setup failures

**Files:**
- Modify: `Tests/AntigravityUsageStoreTests.swift`
- Modify: `Sources/AppRuntime/AntigravityUsageStore.swift`
- Modify: `Sources/Views/MenuBarRootView.swift`

- [ ] **Step 1: Write the failing test**

```swift
func testRefreshShowsFriendlyNodeSetupError() async throws {
    let resolver = AntigravityCLIResolution(
        executableSearchPaths: ["/mock/antigravity-usage"],
        nodeSearchPaths: ["/usr/local/bin/node"],
        fileExists: { path in path == "/mock/antigravity-usage" },
        readFirstLine: { _ in "#!/usr/bin/env node" }
    )
    let store = AntigravityUsageStore(
        client: AntigravityUsageCLIClient(resolver: resolver)
    )

    store.refresh(force: true)

    try await waitUntil {
        if case .failed(let message) = store.loadState {
            return message.contains("system-visible Node.js install")
        }
        return false
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project AntigravityBar.xcodeproj -scheme AntigravityBar -destination 'platform=macOS,arch=arm64' -only-testing:AntigravityBarTests/AntigravityUsageStoreTests`

Expected: FAIL because the current store path leaks the raw `env: node: No such file or directory` process failure instead of the new setup error.

- [ ] **Step 3: Write minimal implementation**

```swift
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project AntigravityBar.xcodeproj -scheme AntigravityBar -destination 'platform=macOS,arch=arm64' -only-testing:AntigravityBarTests/AntigravityUsageStoreTests`

Expected: PASS

### Task 4: Document supported install types and unsupported shell-only setups

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update install instructions**

```md
Install requirements before opening AntigravityBar:

1. Install Node.js in a system-visible location.
   Supported examples:
   - Homebrew Node
   - official Node.js installer
2. Install `antigravity-usage`.

Example:

    npm install -g antigravity-usage

Important:

- AntigravityBar is a GUI app, so it does not automatically inherit your shell startup environment.
- Shell-only Node managers such as `nvm`, `fnm`, and `asdf` may work in Terminal but may not be visible to AntigravityBar.
```

- [ ] **Step 2: Sanity-check the README wording**

Run: `sed -n '1,140p' README.md`

Expected: the install section clearly explains both requirements and warns about shell-only Node setups in simple English.

### Task 5: Run the full verification set

**Files:**
- Modify: `Tests/AntigravityCLIResolutionTests.swift`
- Modify: `Tests/AntigravityUsageCLIClientTests.swift`
- Modify: `Tests/AntigravityUsageStoreTests.swift`
- Modify: `Sources/Services/AntigravityCLIResolution.swift`
- Modify: `Sources/Services/AntigravityUsageCLIClient.swift`
- Modify: `Sources/Views/MenuBarRootView.swift`
- Modify: `README.md`

- [ ] **Step 1: Run targeted tests**

Run: `xcodebuild test -project AntigravityBar.xcodeproj -scheme AntigravityBar -destination 'platform=macOS,arch=arm64' -only-testing:AntigravityBarTests/AntigravityCLIResolutionTests -only-testing:AntigravityBarTests/AntigravityUsageCLIClientTests -only-testing:AntigravityBarTests/AntigravityUsageStoreTests`

Expected: PASS

- [ ] **Step 2: Run full repo verification**

Run: `make agent-verify`

Expected: PASS

- [ ] **Step 3: Manual app check**

Run: `make build-and-run`

Expected:
- when Node is in `/opt/homebrew/bin/node` or `/usr/local/bin/node`, refresh works without `env: node` errors
- when `antigravity-usage` is missing, the existing CLI-not-found message still appears
- when only a shell-managed Node install exists, the app shows the new setup message instead of raw process text
