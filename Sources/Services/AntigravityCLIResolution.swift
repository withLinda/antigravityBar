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
        executableSearchPaths: [String] = Self.defaultExecutableSearchPaths,
        nodeSearchPaths: [String] = Self.defaultNodeSearchPaths,
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
        guard firstLine == "#!/usr/bin/env node" else {
            return LaunchPlan(executablePath: cliPath, arguments: arguments)
        }

        guard let nodePath = nodeSearchPaths.first(where: fileExists) else {
            throw ResolutionError.nodeRuntimeNotFound
        }

        return LaunchPlan(executablePath: nodePath, arguments: [cliPath] + arguments)
    }

    private static let defaultExecutableSearchPaths = [
        "/opt/homebrew/bin/antigravity-usage",
        "/usr/local/bin/antigravity-usage",
        "/usr/bin/antigravity-usage"
    ]

    private static let defaultNodeSearchPaths = [
        "/opt/homebrew/bin/node",
        "/usr/local/bin/node",
        "/Library/Frameworks/Node.js/Versions/Current/bin/node"
    ]

    private static func readFirstLine(at path: String) throws -> String {
        let text = try String(contentsOfFile: path, encoding: .utf8)
        return text.split(separator: "\n", omittingEmptySubsequences: false).first.map(String.init) ?? ""
    }
}
