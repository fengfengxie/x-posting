import Foundation
import XCTest
@testable import XPostingCore

final class DraftStoreTests: XCTestCase {
    func testSaveAndLoadDraft() async throws {
        let fileURL = temporaryFileURL(named: "draft-save-load")
        let store = DraftStore(fileURL: fileURL)
        let draft = Draft(text: "build in public")

        try await store.save(draft)
        let loaded = await store.load()

        XCTAssertEqual(loaded.text, draft.text)
    }

    func testUpdateText() async throws {
        let fileURL = temporaryFileURL(named: "draft-update")
        let store = DraftStore(fileURL: fileURL)

        _ = try await store.updateText("hello")

        let loaded = await store.load()
        XCTAssertEqual(loaded.text, "hello")
    }

    private func temporaryFileURL(named name: String) -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("xposting-tests", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("\(name)-\(UUID().uuidString).json")
    }
}
