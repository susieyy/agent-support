import ArgumentParser
import Foundation

struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "4項目それぞれの状態を人間向けに表示する。"
    )

    @Option(name: [.long], help: "対象リポジトリのルート（既定: CWD）")
    var path: String?

    func run() throws {
        let root = URL(fileURLWithPath: path ?? FileManager.default.currentDirectoryPath)
        let workspace = Workspace(root: root)
        let inspector = StatusInspector(workspace: workspace)
        let reporter = Reporter(verbose: false, dryRun: false)

        let result = inspector.inspect()
        reporter.writeStatus(items: result.items, header: "agent-support status (\(workspace.root.path))")
    }
}
