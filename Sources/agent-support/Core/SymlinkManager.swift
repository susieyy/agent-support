import Foundation

enum SymlinkState: Equatable {
    case missing
    case matchingSymlink                  // 期待する相対 symlink
    case mismatchedSymlink(actual: String) // symlink だが target が違う（絶対 / 別パス）
    case regularFile                      // symlink でない通常ファイル
    case directory                        // symlink でない通常ディレクトリ
}

struct SymlinkManager {
    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// path の状態を expectedRelativeTarget との照合とともに返す。
    func state(at path: URL, expectedRelativeTarget: String) -> SymlinkState {
        let p = path.path

        // lstat 相当: シンボリックリンクは展開しない
        let attrs = try? fileManager.attributesOfItem(atPath: p)
        guard let attrs else { return .missing }

        let type = attrs[.type] as? FileAttributeType
        switch type {
        case .typeSymbolicLink:
            let dest = (try? fileManager.destinationOfSymbolicLink(atPath: p)) ?? ""
            return dest == expectedRelativeTarget ? .matchingSymlink : .mismatchedSymlink(actual: dest)
        case .typeRegular:
            return .regularFile
        case .typeDirectory:
            return .directory
        default:
            return .regularFile
        }
    }

    /// 相対 symlink を作成する（既存パスがある場合は事前に削除しておくこと）。
    func createRelativeSymlink(at path: URL, relativeTarget: String) throws {
        do {
            try fileManager.createSymbolicLink(atPath: path.path, withDestinationPath: relativeTarget)
        } catch {
            throw AgentSupportError.io(path: path.path, underlying: error)
        }
    }

    func removeItem(at path: URL) throws {
        do {
            try fileManager.removeItem(at: path)
        } catch {
            throw AgentSupportError.io(path: path.path, underlying: error)
        }
    }

    func createDirectory(at path: URL) throws {
        do {
            try fileManager.createDirectory(at: path, withIntermediateDirectories: true)
        } catch {
            throw AgentSupportError.io(path: path.path, underlying: error)
        }
    }
}
