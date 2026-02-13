import Foundation

public actor DraftStore {
    private let fileURL: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let directory = appSupport.appendingPathComponent("XPosting", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            self.fileURL = directory.appendingPathComponent("draft.json")
        }
    }

    public func load() -> Draft {
        guard
            let data = try? Data(contentsOf: fileURL),
            let draft = try? decoder.decode(Draft.self, from: data)
        else {
            return Draft()
        }
        return draft
    }

    public func save(_ draft: Draft) throws {
        let data = try encoder.encode(draft)
        try data.write(to: fileURL, options: .atomic)
    }

    public func updateText(_ text: String) throws -> Draft {
        var draft = load()
        draft.text = text
        draft.updatedAt = Date()
        try save(draft)
        return draft
    }

    public func clear() throws {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
