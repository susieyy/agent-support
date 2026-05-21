import Foundation

struct Workspace {
    let root: URL

    init(root: URL) {
        self.root = root.standardizedFileURL
    }

    var agentsMd: URL { root.appendingPathComponent("AGENTS.md") }
    var claudeMd: URL { root.appendingPathComponent("CLAUDE.md") }
    var agentsSkillsDir: URL { root.appendingPathComponent(".agents/skills", isDirectory: true) }
    var agentsDir: URL { root.appendingPathComponent(".agents", isDirectory: true) }
    var claudeDir: URL { root.appendingPathComponent(".claude", isDirectory: true) }
    var claudeSkillsDir: URL { root.appendingPathComponent(".claude/skills", isDirectory: true) }
    var gitkeep: URL { agentsSkillsDir.appendingPathComponent(".gitkeep") }

    /// CLAUDE.md → AGENTS.md (同階層なので "AGENTS.md")
    static let claudeMdRelativeTarget = "AGENTS.md"

    /// .claude/skills → ../.agents/skills (一階層上って .agents/skills)
    static let claudeSkillsRelativeTarget = "../.agents/skills"
}
