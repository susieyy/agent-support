import XCTest
@testable import agent_support

final class ClaudeMdNormalizerTests: XCTestCase {
    var tmp: URL!
    var workspace: Workspace!
    var normalizer: ClaudeMdNormalizer!

    override func setUp() {
        super.setUp()
        tmp = TestSupport.makeTempDir()
        workspace = Workspace(root: tmp)
        normalizer = ClaudeMdNormalizer(workspace: workspace, symlinks: SymlinkManager(), reporter: TestSupport.silentReporter())
    }

    override func tearDown() {
        TestSupport.remove(tmp)
        super.tearDown()
    }

    func test_bothMissing_createsEmptyAgentsAndSymlink() throws {
        try normalizer.normalize()

        XCTAssertTrue(FileManager.default.fileExists(atPath: workspace.agentsMd.path))
        let agentsContent = try TestSupport.read(workspace.agentsMd)
        XCTAssertEqual(agentsContent, "")

        let dest = try FileManager.default.destinationOfSymbolicLink(atPath: workspace.claudeMd.path)
        XCTAssertEqual(dest, "AGENTS.md")
    }

    func test_onlyClaudeMdExists_movesContentToAgentsAndSymlinks() throws {
        try TestSupport.write("hello from claude", to: workspace.claudeMd)

        try normalizer.normalize()

        let agentsContent = try TestSupport.read(workspace.agentsMd)
        XCTAssertEqual(agentsContent, "hello from claude")

        let dest = try FileManager.default.destinationOfSymbolicLink(atPath: workspace.claudeMd.path)
        XCTAssertEqual(dest, "AGENTS.md")
    }

    func test_bothExistIdenticalContent_dropsClaude() throws {
        try TestSupport.write("same", to: workspace.agentsMd)
        try TestSupport.write("same", to: workspace.claudeMd)

        try normalizer.normalize()

        XCTAssertEqual(try TestSupport.read(workspace.agentsMd), "same")
        let dest = try FileManager.default.destinationOfSymbolicLink(atPath: workspace.claudeMd.path)
        XCTAssertEqual(dest, "AGENTS.md")
    }

    func test_bothExistDifferentContent_mergesWithSeparator() throws {
        try TestSupport.write("agents-side", to: workspace.agentsMd)
        try TestSupport.write("claude-side", to: workspace.claudeMd)

        try normalizer.normalize()

        let merged = try TestSupport.read(workspace.agentsMd)
        XCTAssertEqual(merged, "agents-side" + ClaudeMdNormalizer.mergeSeparator + "claude-side")

        let dest = try FileManager.default.destinationOfSymbolicLink(atPath: workspace.claudeMd.path)
        XCTAssertEqual(dest, "AGENTS.md")
    }

    func test_alreadyLinked_isIdempotent() throws {
        try TestSupport.write("v1", to: workspace.agentsMd)
        try FileManager.default.createSymbolicLink(atPath: workspace.claudeMd.path, withDestinationPath: "AGENTS.md")

        try normalizer.normalize()
        try normalizer.normalize()  // 2回目も同じ結果

        XCTAssertEqual(try TestSupport.read(workspace.agentsMd), "v1")
        let dest = try FileManager.default.destinationOfSymbolicLink(atPath: workspace.claudeMd.path)
        XCTAssertEqual(dest, "AGENTS.md")
    }

    func test_mismatchedSymlink_throws() throws {
        try FileManager.default.createSymbolicLink(atPath: workspace.claudeMd.path, withDestinationPath: "OTHER.md")

        XCTAssertThrowsError(try normalizer.normalize()) { error in
            guard case AgentSupportError.unexpectedSymlinkTarget(_, let actual, let expected) = error else {
                return XCTFail("expected unexpectedSymlinkTarget, got \(error)")
            }
            XCTAssertEqual(actual, "OTHER.md")
            XCTAssertEqual(expected, "AGENTS.md")
        }
    }
}
