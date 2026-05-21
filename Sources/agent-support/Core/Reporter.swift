import Foundation

enum ItemMark {
    case ok          // ✓
    case fixable     // ⚠
    case manual      // ✗

    var symbol: String {
        switch self {
        case .ok: return "✓"
        case .fixable: return "⚠"
        case .manual: return "✗"
        }
    }
}

struct ItemReport {
    let mark: ItemMark
    let label: String
    let detail: String
}

final class Reporter {
    let verbose: Bool
    let dryRun: Bool
    private var stderr = FileHandle.standardError

    init(verbose: Bool, dryRun: Bool) {
        self.verbose = verbose
        self.dryRun = dryRun
    }

    func log(_ message: String) {
        guard verbose else { return }
        print(message)
    }

    func action(_ message: String) {
        let prefix = dryRun ? "[dry-run] " : ""
        print("\(prefix)\(message)")
    }

    func error(_ message: String) {
        if let data = "error: \(message)\n".data(using: .utf8) {
            stderr.write(data)
        }
    }

    func writeStatus(items: [ItemReport], header: String) {
        print(header)
        let width = items.map { $0.label.count }.max() ?? 0
        for item in items {
            let pad = String(repeating: " ", count: max(0, width - item.label.count))
            print("  \(item.mark.symbol) \(item.label)\(pad)   \(item.detail)")
        }
    }
}
