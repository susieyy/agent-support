import XCTest
@testable import agent_support

final class SymlinkManagerTests: XCTestCase {
    var tmp: URL!

    override func setUp() {
        super.setUp()
        tmp = TestSupport.makeTempDir()
    }

    override func tearDown() {
        TestSupport.remove(tmp)
        super.tearDown()
    }

    func test_missing() {
        let sm = SymlinkManager()
        let state = sm.state(at: tmp.appendingPathComponent("nope"), expectedRelativeTarget: "AGENTS.md")
        XCTAssertEqual(state, .missing)
    }

    func test_regularFile() throws {
        let sm = SymlinkManager()
        let file = tmp.appendingPathComponent("a.md")
        try TestSupport.write("hi", to: file)
        XCTAssertEqual(sm.state(at: file, expectedRelativeTarget: "AGENTS.md"), .regularFile)
    }

    func test_directory() throws {
        let sm = SymlinkManager()
        let dir = tmp.appendingPathComponent("d", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        XCTAssertEqual(sm.state(at: dir, expectedRelativeTarget: "AGENTS.md"), .directory)
    }

    func test_matchingSymlink() throws {
        let sm = SymlinkManager()
        let link = tmp.appendingPathComponent("CLAUDE.md")
        try sm.createRelativeSymlink(at: link, relativeTarget: "AGENTS.md")
        XCTAssertEqual(sm.state(at: link, expectedRelativeTarget: "AGENTS.md"), .matchingSymlink)
    }

    func test_mismatchedSymlink_absolute() throws {
        let sm = SymlinkManager()
        let link = tmp.appendingPathComponent("CLAUDE.md")
        // 絶対パスで symlink を貼る → mismatch
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "/tmp/AGENTS.md")
        XCTAssertEqual(sm.state(at: link, expectedRelativeTarget: "AGENTS.md"), .mismatchedSymlink(actual: "/tmp/AGENTS.md"))
    }

    func test_mismatchedSymlink_otherRelative() throws {
        let sm = SymlinkManager()
        let link = tmp.appendingPathComponent("CLAUDE.md")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "OTHER.md")
        XCTAssertEqual(sm.state(at: link, expectedRelativeTarget: "AGENTS.md"), .mismatchedSymlink(actual: "OTHER.md"))
    }

    func test_createRelativeSymlink_storesDestinationVerbatim() throws {
        let sm = SymlinkManager()
        let link = tmp.appendingPathComponent("CLAUDE.md")
        try sm.createRelativeSymlink(at: link, relativeTarget: "AGENTS.md")
        let dest = try FileManager.default.destinationOfSymbolicLink(atPath: link.path)
        XCTAssertEqual(dest, "AGENTS.md")
    }
}
