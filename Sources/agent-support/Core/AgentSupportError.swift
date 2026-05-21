import Foundation

enum AgentSupportError: Error, CustomStringConvertible {
    case unexpectedSymlinkTarget(path: String, actual: String, expected: String)
    case unexpectedFileType(path: String, reason: String)
    case skillsNameConflict(name: String)
    case io(path: String, underlying: Error)

    var description: String {
        switch self {
        case let .unexpectedSymlinkTarget(path, actual, expected):
            return "\(path): symlink points to \(actual.isEmpty ? "<empty>" : actual), expected \(expected)"
        case let .unexpectedFileType(path, reason):
            return "\(path): \(reason)"
        case let .skillsNameConflict(name):
            return ".claude/skills/\(name) と .agents/skills/\(name) が両方存在します。手動でマージしてください。"
        case let .io(path, underlying):
            return "\(path): I/O error — \(underlying.localizedDescription)"
        }
    }
}
