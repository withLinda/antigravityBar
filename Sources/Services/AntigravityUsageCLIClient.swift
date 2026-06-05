import Foundation

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

    func fetchAllAccounts(forceRefresh: Bool = true) async throws -> [AllAccountsQuotaResult] {
        let output = try await output(for: Self.allAccountsArguments(forceRefresh: forceRefresh))
        return try Self.decodeAccounts(from: output)
    }

    func addAccount() async throws {
        _ = try await output(for: Self.addAccountArguments)
    }

    func removeAccount(email: String) async throws {
        _ = try await output(for: Self.removeAccountArguments(email: email))
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
