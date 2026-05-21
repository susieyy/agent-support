import XCTest
@testable import agent_support

final class SkillsNormalizerTests: XCTestCase {
    var tmp: URL!
    var workspace: Workspace!
    var normalizer: SkillsNormalizer!

    override func setUp() {
        super.setUp()
        tmp = TestSupport.makeTempDir()
        workspace = Workspace(root: tmp)
        normalizer = SkillsNormalizer(workspace: workspace, symlinks: SymlinkManager(), reporter: TestSupport.silentReporter())
    }

    override func tearDown() {
        TestSupport.remove(tmp)
        super.tearDown()
    }

    func test_bothMissing_createsDirAndGitkeepAndSymlink() throws {
        try normalizer.normalize()

        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: workspace.agentsSkillsDir.path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)

        XCTAssertTrue(FileManager.default.fileExists(atPath: workspace.gitkeep.path))

        let dest = try FileManager.default.destinationOfSymbolicLink(atPath: workspace.claudeSkillsDir.path)
        XCTAssertEqual(dest, "../.agents/skills")
    }

    func test_claudeSkillsHasContent_migratesAndSymlinks() throws {
        let src = workspace.claudeSkillsDir
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        try TestSupport.write("skill A", to: src.appendingPathComponent("a.md"))
        let subdir = src.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
        try TestSupport.write("nested", to: subdir.appendingPathComponent("b.md"))

        try normalizer.normalize()

        // 移動先に存在
        XCTAssertEqual(try TestSupport.read(workspace.agentsSkillsDir.appendingPathComponent("a.md")), "skill A")
        XCTAssertEqual(try TestSupport.read(workspace.agentsSkillsDir.appendingPathComponent("sub/b.md")), "nested")

        // .gitkeep は中身があるので作られない
        XCTAssertFalse(FileManager.default.fileExists(atPath: workspace.gitkeep.path))

        // .claude/skills は symlink
        let dest = try FileManager.default.destinationOfSymbolicLink(atPath: workspace.claudeSkillsDir.path)
        XCTAssertEqual(dest, "../.agents/skills")
    }

    func test_nameConflict_throws_withoutMutation() throws {
        try FileManager.default.createDirectory(at: workspace.claudeSkillsDir, withIntermediateDirectories: true)
        try TestSupport.write("from-claude", to: workspace.claudeSkillsDir.appendingPathComponent("dup.md"))
        try FileManager.default.createDirectory(at: workspace.agentsSkillsDir, withIntermediateDirectories: true)
        try TestSupport.write("from-agents", to: workspace.agentsSkillsDir.appendingPathComponent("dup.md"))

        XCTAssertThrowsError(try normalizer.normalize()) { error in
            guard case AgentSupportError.skillsNameConflict(let name) = error else {
                return XCTFail("expected skillsNameConflict, got \(error)")
            }
            XCTAssertEqual(name, "dup.md")
        }

        // どちらも残っている（巻き戻り不要を確認）
        XCTAssertEqual(try TestSupport.read(workspace.claudeSkillsDir.appendingPathComponent("dup.md")), "from-claude")
        XCTAssertEqual(try TestSupport.read(workspace.agentsSkillsDir.appendingPathComponent("dup.md")), "from-agents")
    }

    func test_alreadyLinked_isIdempotent() throws {
        try normalizer.normalize()
        try normalizer.normalize()

        let dest = try FileManager.default.destinationOfSymbolicLink(atPath: workspace.claudeSkillsDir.path)
        XCTAssertEqual(dest, "../.agents/skills")
        XCTAssertTrue(FileManager.default.fileExists(atPath: workspace.gitkeep.path))
    }

    func test_gitkeepRemovedWhenContentArrives() throws {
        try normalizer.normalize()
        XCTAssertTrue(FileManager.default.fileExists(atPath: workspace.gitkeep.path))

        // skills に何か追加
        try TestSupport.write("skill", to: workspace.agentsSkillsDir.appendingPathComponent("x.md"))

        try normalizer.normalize()
        XCTAssertFalse(FileManager.default.fileExists(atPath: workspace.gitkeep.path))
    }

    func test_mismatchedSymlink_throws() throws {
        try FileManager.default.createDirectory(at: workspace.claudeDir, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(atPath: workspace.claudeSkillsDir.path, withDestinationPath: "/somewhere/else")

        XCTAssertThrowsError(try normalizer.normalize()) { error in
            guard case AgentSupportError.unexpectedSymlinkTarget = error else {
                return XCTFail("expected unexpectedSymlinkTarget, got \(error)")
            }
        }
    }
}
