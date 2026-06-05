import Foundation

struct AntigravityUsageCLIClient: Sendable {
    enum ClientError: LocalizedError, Equatable {
        case executableNotFound
        case jsonNotFound
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .executableNotFound:
                return "antigravity-usage CLI was not found."
            case .jsonNotFound:
                return "The CLI did not return JSON."
            case .commandFailed(let message):
                return message.isEmpty ? "The CLI command failed." : message
            }
        }
    }

    let executableSearchPaths: [String]
    let runner: @Sendable ([String], String) async throws -> String

    init(
        executableSearchPaths: [String] = Self.defaultExecutableSearchPaths,
        runner: @escaping @Sendable ([String], String) async throws -> String = Self.runProcess(arguments:executablePath:)
    ) {
        self.executableSearchPaths = executableSearchPaths
        self.runner = runner
    }

    func fetchAllAccounts(forceRefresh: Bool = true) async throws -> [AllAccountsQuotaResult] {
        let executablePath = try executablePath()
        let output = try await runner(Self.allAccountsArguments(forceRefresh: forceRefresh), executablePath)
        return try Self.decodeAccounts(from: output)
    }

    func addAccount() async throws {
        let executablePath = try executablePath()
        _ = try await runner(Self.addAccountArguments, executablePath)
    }

    func removeAccount(email: String) async throws {
        let executablePath = try executablePath()
        _ = try await runner(Self.removeAccountArguments(email: email), executablePath)
    }

    static func allAccountsArguments(forceRefresh: Bool) -> [String] {
        var arguments = ["quota", "--all", "--json", "--all-models"]
        if forceRefresh {
            arguments.append("--refresh")
        }
        return arguments
    }

    static let addAccountArguments = ["accounts", "add"]

    static func removeAccountArguments(email: String) -> [String] {
        ["accounts", "remove", "--force", email]
    }

    static func decodeAccounts(from output: String) throws -> [AllAccountsQuotaResult] {
        guard let jsonStart = output.firstIndex(of: "[") else {
            throw ClientError.jsonNotFound
        }

        let jsonText = String(output[jsonStart...])
        let data = Data(jsonText.utf8)
        return try JSONDecoder().decode([AllAccountsQuotaResult].self, from: data)
    }

    private static let defaultExecutableSearchPaths = [
        "/opt/homebrew/bin/antigravity-usage",
        "/usr/local/bin/antigravity-usage",
        "/usr/bin/antigravity-usage"
    ]

    private func executablePath() throws -> String {
        guard let executablePath = executableSearchPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw ClientError.executableNotFound
        }
        return executablePath
    }

    private static func runProcess(arguments: [String], executablePath: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            process.terminationHandler = { process in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: ClientError.commandFailed(errorOutput + output))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
