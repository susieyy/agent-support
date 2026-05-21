import Foundation

struct SkillsNormalizer {
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

    func normalize() throws {
        try ensureAgentsSkillsDir()
        try normalizeClaudeSkills()
        try ensureGitkeep()
    }

    /// .agents/skills が無ければ作成。symlink/regular file になっていたらエラー。
    func ensureAgentsSkillsDir() throws {
        let path = workspace.agentsSkillsDir.path
        let attrs = try? fileManager.attributesOfItem(atPath: path)
        if attrs == nil {
            reporter.action("create .agents/skills/")
            if !reporter.dryRun {
                try symlinks.createDirectory(at: workspace.agentsSkillsDir)
            }
            return
        }
        let type = attrs?[.type] as? FileAttributeType
        switch type {
        case .typeDirectory: return
        case .typeSymbolicLink:
            throw AgentSupportError.unexpectedFileType(path: path, reason: ".agents/skills はディレクトリである必要があります（symlinkでした）。")
        default:
            throw AgentSupportError.unexpectedFileType(path: path, reason: ".agents/skills はディレクトリである必要があります。")
        }
    }

    func normalizeClaudeSkills() throws {
        let state = symlinks.state(at: workspace.claudeSkillsDir, expectedRelativeTarget: Workspace.claudeSkillsRelativeTarget)
        switch state {
        case .matchingSymlink:
            reporter.log(".claude/skills: ok")
            return

        case .missing:
            try ensureClaudeDir()
            reporter.action("symlink .claude/skills -> ../.agents/skills")
            if !reporter.dryRun {
                try symlinks.createRelativeSymlink(at: workspace.claudeSkillsDir, relativeTarget: Workspace.claudeSkillsRelativeTarget)
            }

        case .mismatchedSymlink(let actual):
            throw AgentSupportError.unexpectedSymlinkTarget(
                path: workspace.claudeSkillsDir.path,
                actual: actual,
                expected: Workspace.claudeSkillsRelativeTarget
            )

        case .regularFile:
            throw AgentSupportError.unexpectedFileType(path: workspace.claudeSkillsDir.path, reason: ".claude/skills が通常ファイルです。")

        case .directory:
            try migrateAndLink()
        }
    }

    private func ensureClaudeDir() throws {
        if !fileManager.fileExists(atPath: workspace.claudeDir.path) {
            if !reporter.dryRun {
                try symlinks.createDirectory(at: workspace.claudeDir)
            }
        }
    }

    /// .claude/skills 配下を .agents/skills 配下に moveItem。衝突は事前検査でエラー。
    private func migrateAndLink() throws {
        let src = workspace.claudeSkillsDir
        let dst = workspace.agentsSkillsDir

        let entries: [String]
        do {
            entries = try fileManager.contentsOfDirectory(atPath: src.path)
        } catch {
            throw AgentSupportError.io(path: src.path, underlying: error)
        }

        for name in entries {
            let dstPath = dst.appendingPathComponent(name).path
            if fileManager.fileExists(atPath: dstPath) {
                throw AgentSupportError.skillsNameConflict(name: name)
            }
        }

        for name in entries {
            let from = src.appendingPathComponent(name)
            let to = dst.appendingPathComponent(name)
            reporter.action("move .claude/skills/\(name) -> .agents/skills/\(name)")
            if !reporter.dryRun {
                do {
                    try fileManager.moveItem(at: from, to: to)
                } catch {
                    throw AgentSupportError.io(path: from.path, underlying: error)
                }
            }
        }

        reporter.action("replace .claude/skills with symlink -> ../.agents/skills")
        if !reporter.dryRun {
            try symlinks.removeItem(at: src)
            try symlinks.createRelativeSymlink(at: src, relativeTarget: Workspace.claudeSkillsRelativeTarget)
        }
    }

    /// .agents/skills が空のときのみ .gitkeep を作成する。
    func ensureGitkeep() throws {
        let dir = workspace.agentsSkillsDir
        // dry-run で dir 未作成のときはスキップ
        guard fileManager.fileExists(atPath: dir.path) else { return }

        let entries: [String]
        do {
            entries = try fileManager.contentsOfDirectory(atPath: dir.path)
        } catch {
            throw AgentSupportError.io(path: dir.path, underlying: error)
        }

        let nonHidden = entries.filter { $0 != ".gitkeep" }
        let hasGitkeep = entries.contains(".gitkeep")

        if nonHidden.isEmpty {
            if !hasGitkeep {
                reporter.action("create .agents/skills/.gitkeep")
                if !reporter.dryRun {
                    do {
                        try Data().write(to: workspace.gitkeep)
                    } catch {
                        throw AgentSupportError.io(path: workspace.gitkeep.path, underlying: error)
                    }
                }
            }
        } else if hasGitkeep {
            reporter.action("remove redundant .agents/skills/.gitkeep")
            if !reporter.dryRun {
                try symlinks.removeItem(at: workspace.gitkeep)
            }
        }
    }
}
