import ArgumentParser
import Foundation

struct CheckCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "check",
        abstract: "不変条件を検査する。違反があれば exit code 1。"
    )

    @Option(name: [.long], help: "対象リポジトリのルート（既定: CWD）")
    var path: String?

    func run() throws {
        let root = URL(fileURLWithPath: path ?? FileManager.default.currentDirectoryPath)
        let workspace = Workspace(root: root)
        let inspector = StatusInspector(workspace: workspace)

        let result = inspector.inspect()

        if result.hasIssue {
            let reporter = Reporter(verbose: false, dryRun: false)
            for item in result.items where item.mark.symbol != "✓" {
                reporter.error("\(item.label): \(item.detail)")
            }
            throw ExitCode.failure
        }
    }
}
