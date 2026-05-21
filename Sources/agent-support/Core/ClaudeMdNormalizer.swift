import Foundation

struct ClaudeMdNormalizer {
    let workspace: Workspace
    let symlinks: SymlinkManager
    let reporter: Reporter
    let fileManager: FileManager

    init(workspace: Workspace, symlinks: SymlinkManager, reporter: Reporter, fileManager: FileManager = .default) {
        self.workspace = workspace
        self.symlinks = symlinks
        self.reporter = reporter
        self.fileManager = fileManager
    }

    static let mergeSeparator = "\n\n<!-- merged from CLAUDE.md by agent-support -->\n\n"

    /// AGENTS.md / CLAUDE.md の状態を不変条件に揃える。冪等。
    func normalize() throws {
        try ensureAgentsMd()
        try normalizeClaudeMd()
    }

    /// AGENTS.md が無ければ空ファイルとして作成する。
    func ensureAgentsMd() throws {
        let agentsPath = workspace.agentsMd.path
        let attrs = try? fileManager.attributesOfItem(atPath: agentsPath)
        if attrs == nil {
            reporter.action("create AGENTS.md (empty)")
            if !reporter.dryRun {
                do {
                    try Data().write(to: workspace.agentsMd)
                } catch {
                    throw AgentSupportError.io(path: agentsPath, underlying: error)
                }
            }
            return
        }
        let type = attrs?[.type] as? FileAttributeType
        switch type {
        case .typeRegular:
            return
        case .typeSymbolicLink:
            throw AgentSupportError.unexpectedFileType(path: agentsPath, reason: "AGENTS.md がsymlinkです。実体ファイルである必要があります。")
        case .typeDirectory:
            throw AgentSupportError.unexpectedFileType(path: agentsPath, reason: "AGENTS.md がディレクトリです。")
        default:
            throw AgentSupportError.unexpectedFileType(path: agentsPath, reason: "AGENTS.md が未知の種別です。")
        }
    }

    func normalizeClaudeMd() throws {
        let state = symlinks.state(at: workspace.claudeMd, expectedRelativeTarget: Workspace.claudeMdRelativeTarget)
        switch state {
        case .matchingSymlink:
            reporter.log("CLAUDE.md: ok")
            return

        case .missing:
            reporter.action("symlink CLAUDE.md -> AGENTS.md")
            if !reporter.dryRun {
                try symlinks.createRelativeSymlink(at: workspace.claudeMd, relativeTarget: Workspace.claudeMdRelativeTarget)
            }

        case .mismatchedSymlink(let actual):
            throw AgentSupportError.unexpectedSymlinkTarget(
                path: workspace.claudeMd.path,
                actual: actual,
                expected: Workspace.claudeMdRelativeTarget
            )

        case .directory:
            throw AgentSupportError.unexpectedFileType(path: workspace.claudeMd.path, reason: "CLAUDE.md がディレクトリです。")

        case .regularFile:
            try mergeAndLink()
        }
    }

    private func mergeAndLink() throws {
        let claudePath = workspace.claudeMd
        let agentsPath = workspace.agentsMd

        let claudeData: Data
        do {
            claudeData = try Data(contentsOf: claudePath)
        } catch {
            throw AgentSupportError.io(path: claudePath.path, underlying: error)
        }
        let agentsData: Data
        do {
            agentsData = (try? Data(contentsOf: agentsPath)) ?? Data()
        }

        let claudeText = String(data: claudeData, encoding: .utf8) ?? ""
        let agentsText = String(data: agentsData, encoding: .utf8) ?? ""

        if agentsText.isEmpty {
            reporter.action("move CLAUDE.md contents into AGENTS.md")
            if !reporter.dryRun {
                do {
                    try claudeData.write(to: agentsPath)
                } catch {
                    throw AgentSupportError.io(path: agentsPath.path, underlying: error)
                }
            }
        } else if agentsText == claudeText {
            reporter.log("CLAUDE.md and AGENTS.md contents identical; dropping CLAUDE.md")
        } else {
            reporter.action("merge CLAUDE.md into AGENTS.md (append with separator)")
            if !reporter.dryRun {
                let merged = agentsText + Self.mergeSeparator + claudeText
                guard let mergedData = merged.data(using: .utf8) else {
                    throw AgentSupportError.io(path: agentsPath.path, underlying: NSError(domain: "agent-support", code: -1, userInfo: [NSLocalizedDescriptionKey: "UTF-8 encoding failed"]))
                }
                do {
                    try mergedData.write(to: agentsPath)
                } catch {
                    throw AgentSupportError.io(path: agentsPath.path, underlying: error)
                }
            }
        }

        reporter.action("replace CLAUDE.md with symlink -> AGENTS.md")
        if !reporter.dryRun {
            try symlinks.removeItem(at: claudePath)
            try symlinks.createRelativeSymlink(at: claudePath, relativeTarget: Workspace.claudeMdRelativeTarget)
        }
    }
}
