import Foundation

struct StatusInspector {
    let workspace: Workspace
    let symlinks: SymlinkManager
    let fileManager: FileManager

    init(workspace: Workspace, symlinks: SymlinkManager = SymlinkManager(), fileManager: FileManager = .default) {
        self.workspace = workspace
        self.symlinks = symlinks
        self.fileManager = fileManager
    }

    /// 4項目それぞれの状態を ItemReport にして返す。
    /// hasIssue は ✓ 以外が1つでも含まれるか。
    func inspect() -> (items: [ItemReport], hasIssue: Bool) {
        var items: [ItemReport] = []
        var issue = false

        // AGENTS.md
        let agentsAttrs = try? fileManager.attributesOfItem(atPath: workspace.agentsMd.path)
        if agentsAttrs == nil {
            items.append(.init(mark: .fixable, label: "AGENTS.md", detail: "missing (run `agent-support sync`)"))
            issue = true
        } else if (agentsAttrs?[.type] as? FileAttributeType) == .typeRegular {
            let size = (agentsAttrs?[.size] as? Int) ?? 0
            items.append(.init(mark: .ok, label: "AGENTS.md", detail: "file, \(humanSize(size))"))
        } else {
            items.append(.init(mark: .manual, label: "AGENTS.md", detail: "unexpected file type"))
            issue = true
        }

        // CLAUDE.md
        let claudeState = symlinks.state(at: workspace.claudeMd, expectedRelativeTarget: Workspace.claudeMdRelativeTarget)
        switch claudeState {
        case .matchingSymlink:
            items.append(.init(mark: .ok, label: "CLAUDE.md", detail: "-> \(Workspace.claudeMdRelativeTarget)"))
        case .missing:
            items.append(.init(mark: .fixable, label: "CLAUDE.md", detail: "missing (run `agent-support sync`)"))
            issue = true
        case .regularFile:
            items.append(.init(mark: .fixable, label: "CLAUDE.md", detail: "regular file (run `agent-support sync` to merge & link)"))
            issue = true
        case .directory:
            items.append(.init(mark: .manual, label: "CLAUDE.md", detail: "is a directory"))
            issue = true
        case .mismatchedSymlink(let actual):
            items.append(.init(mark: .manual, label: "CLAUDE.md", detail: "symlink -> \(actual) (expected \(Workspace.claudeMdRelativeTarget))"))
            issue = true
        }

        // .agents/skills
        let agentsSkillsAttrs = try? fileManager.attributesOfItem(atPath: workspace.agentsSkillsDir.path)
        if agentsSkillsAttrs == nil {
            items.append(.init(mark: .fixable, label: ".agents/skills", detail: "missing (run `agent-support sync`)"))
            issue = true
        } else if (agentsSkillsAttrs?[.type] as? FileAttributeType) == .typeDirectory {
            let count = (try? fileManager.contentsOfDirectory(atPath: workspace.agentsSkillsDir.path).count) ?? 0
            items.append(.init(mark: .ok, label: ".agents/skills", detail: "dir, \(count) entries"))
        } else {
            items.append(.init(mark: .manual, label: ".agents/skills", detail: "unexpected file type"))
            issue = true
        }

        // .claude/skills
        let skillsState = symlinks.state(at: workspace.claudeSkillsDir, expectedRelativeTarget: Workspace.claudeSkillsRelativeTarget)
        switch skillsState {
        case .matchingSymlink:
            items.append(.init(mark: .ok, label: ".claude/skills", detail: "-> \(Workspace.claudeSkillsRelativeTarget)"))
        case .missing:
            items.append(.init(mark: .fixable, label: ".claude/skills", detail: "missing (run `agent-support sync`)"))
            issue = true
        case .directory:
            items.append(.init(mark: .fixable, label: ".claude/skills", detail: "regular directory (run `agent-support sync` to migrate & link)"))
            issue = true
        case .regularFile:
            items.append(.init(mark: .manual, label: ".claude/skills", detail: "is a regular file"))
            issue = true
        case .mismatchedSymlink(let actual):
            items.append(.init(mark: .manual, label: ".claude/skills", detail: "symlink -> \(actual) (expected \(Workspace.claudeSkillsRelativeTarget))"))
            issue = true
        }

        return (items, issue)
    }

    private func humanSize(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024.0
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        let mb = kb / 1024.0
        return String(format: "%.1f MB", mb)
    }
}
