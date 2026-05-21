import ArgumentParser

@main
struct AgentSupport: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agent-support",
        abstract: "リポジトリの AGENT 設定と Claude Code 設定を symlink で共通化する CLI",
        version: "0.1.0",
        subcommands: [SyncCommand.self, CheckCommand.self, StatusCommand.self],
        defaultSubcommand: StatusCommand.self
    )
}
