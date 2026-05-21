import Foundation
import XCTest
@testable import agent_support

enum TestSupport {
    static func makeTempDir(_ function: String = #function) -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-support-tests", isDirectory: true)
            .appendingPathComponent("\(function)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    static func write(_ string: String, to url: URL) throws {
        try string.data(using: .utf8)!.write(to: url)
    }

    static func read(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func silentReporter() -> Reporter {
        Reporter(verbose: false, dryRun: false)
    }
}
