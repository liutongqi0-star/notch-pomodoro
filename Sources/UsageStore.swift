import Foundation

struct UsageData: Codable {
    var version: Int = 1
    var installedAt: Date = Date()
    /// 每天的累计秒数，键是本地日期（yyyy-MM-dd）
    var days: [String: Double] = [:]
}

struct UsageStore {
    let directory: URL

    var fileURL: URL { directory.appendingPathComponent("usage.json") }

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else if let override = ProcessInfo.processInfo.environment["USAGECLOCK_DATA_DIR"], !override.isEmpty {
            self.directory = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library/Application Support", isDirectory: true)
            self.directory = base.appendingPathComponent("UsageClock", isDirectory: true)
        }
    }

    func load() -> UsageData? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let raw = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(UsageData.self, from: raw)
        } catch {
            NSLog("UsageClock: 读取记录失败：\(error.localizedDescription)")
            // 数据损坏时保留现场，避免直接覆盖用户数据
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = directory.appendingPathComponent("usage.corrupt-\(stamp).json")
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            return nil
        }
    }

    func save(_ data: UsageData) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let payload = try encoder.encode(data)
        try payload.write(to: fileURL, options: [.atomic])
    }
}
