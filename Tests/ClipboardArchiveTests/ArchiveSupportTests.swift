import Foundation
import XCTest
@testable import ClipboardArchive

final class ArchiveSupportTests: XCTestCase {
    func testFilenameUsesTimestampAndSafeExtension() {
        let date = Date(timeIntervalSince1970: 1_728_000_000)
        let name = ArchiveNaming.filename(base: "hello/world", extension: "txt", date: date, collision: 0)

        XCTAssertTrue(name.hasPrefix("2024-10-04_"))
        XCTAssertTrue(name.hasSuffix("_hello-world.txt"))
        XCTAssertFalse(name.contains("/"))
    }

    func testCollisionSuffixIsIncluded() {
        let date = Date(timeIntervalSince1970: 1_728_000_000)
        let name = ArchiveNaming.filename(base: "clipboard", extension: "png", date: date, collision: 2)

        XCTAssertTrue(name.hasSuffix("_clipboard-2.png"))
    }

    func testURLBookmarkDataUsesStandardWeblocPropertyList() throws {
        let data = try ArchiveFormat.weblocData(for: URL(string: "https://example.com/path?q=1")!)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]

        XCTAssertEqual(plist?["URL"], "https://example.com/path?q=1")
    }

    func testDuplicateTrackerSkipsSavedContentButCanRetryFailedSave() {
        var tracker = DuplicateTracker()
        let digest = DuplicateTracker.digest(Data("same".utf8))

        XCTAssertTrue(tracker.shouldArchive(digest))
        XCTAssertFalse(tracker.shouldArchive(digest))
        tracker.remove(digest)
        XCTAssertTrue(tracker.shouldArchive(digest))
        XCTAssertTrue(tracker.shouldArchive(DuplicateTracker.digest(Data("different".utf8))))
    }

    func testWriterKeepsExistingFileAndAddsCollisionSuffix() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = ArchiveWriter(directory: directory)
        let date = Date(timeIntervalSince1970: 1_728_000_000)

        let first = try writer.write(Data("first".utf8), base: "text", extension: "txt", date: date)
        let second = try writer.write(Data("second".utf8), base: "text", extension: "txt", date: date)

        XCTAssertNotEqual(first, second)
        XCTAssertEqual(try String(contentsOf: first, encoding: .utf8), "first")
        XCTAssertEqual(try String(contentsOf: second, encoding: .utf8), "second")
        XCTAssertTrue(second.lastPathComponent.hasSuffix("_text-1.txt"))
        let attributes = try FileManager.default.attributesOfItem(atPath: first.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }
}
