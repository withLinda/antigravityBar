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
