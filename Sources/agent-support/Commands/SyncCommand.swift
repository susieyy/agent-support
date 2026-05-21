import ArgumentParser
import Foundation

struct SyncCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sync",
        abstract: "AGENTS.md / CLAUDE.md と .agents/skills / .claude/skills を共通化（symlink化）する。冪等。"
    )

    @Option(name: [.long], help: "対象リポジトリのルート（既定: CWD）")
    var path: String?

    @Flag(name: [.long], help: "実ファイルを触らず、行うはずの操作だけ出力する")
    var dryRun: Bool = false

    @Flag(name: [.short, .long], help: "詳細ログを出力する")
    var verbose: Bool = false

    func run() throws {
        let root = URL(fileURLWithPath: path ?? FileManager.default.currentDirectoryPath)
        let workspace = Workspace(root: root)
        let reporter = Reporter(verbose: verbose, dryRun: dryRun)
        let symlinks = SymlinkManager()

        reporter.log("agent-support sync (\(workspace.root.path))")

        do {
            try ClaudeMdNormalizer(workspace: workspace, symlinks: symlinks, reporter: reporter).normalize()
            try SkillsNormalizer(workspace: workspace, symlinks: symlinks, reporter: reporter).normalize()
        } catch let error as AgentSupportError {
            reporter.error(error.description)
            throw ExitCode.failure
        }
    }
}
