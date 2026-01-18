import Foundation
import os.log
import SharedCore

struct QuickActionLogger {
    private let logger = Logger(subsystem: "com.example.silentarchive", category: "QuickAction")
    private let store = JobStore()
    private let fileManager = FileManager.default
    private let formatter: ISO8601DateFormatter

    init() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.formatter = formatter
    }

    func logInfo(_ message: String) {
        logger.info("\(message, privacy: .public)")
        appendToLogFile("INFO", message)
    }

    func logError(_ message: String) {
        logger.error("\(message, privacy: .public)")
        appendToLogFile("ERROR", message)
    }

    func writeLastQuickAction(selectedCount: Int) {
        guard let url = try? logsDirectoryURL().appendingPathComponent("last_quickaction.txt") else { return }
        let line = "\(timestamp()) selectedItems=\(selectedCount)\n"
        do {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try line.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            logger.error("Failed to write last_quickaction.txt: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func appendToLogFile(_ level: String, _ message: String) {
        guard let url = try? logsDirectoryURL().appendingPathComponent("quickaction.log") else { return }
        let line = "\(timestamp()) [\(level)] \(message)\n"
        do {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !fileManager.fileExists(atPath: url.path) {
                fileManager.createFile(atPath: url.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd()
            if let data = line.data(using: .utf8) {
                try handle.write(contentsOf: data)
            }
            try handle.close()
        } catch {
            logger.error("Failed to append quickaction.log: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func logsDirectoryURL() throws -> URL {
        try store.appGroupContainerURL().appendingPathComponent("logs", isDirectory: true)
    }

    private func timestamp() -> String {
        formatter.string(from: Date())
    }
}
