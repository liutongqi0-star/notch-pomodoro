import Foundation

struct MemoStore {
    let fileURL: URL

    init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("memo.txt", isDirectory: false)
    }

    func load() -> String {
        guard let data = try? Data(contentsOf: fileURL) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    func save(_ text: String) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try text.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
