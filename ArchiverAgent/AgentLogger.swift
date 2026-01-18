import Foundation
import os.log
import SharedCore

actor AgentLogger {
    static let shared = AgentLogger()

    private let logger = Logger(subsystem: "com.example.silentarchive", category: "Agent")
    private let store = JobStore()
    private let fileManager: FileManager
    private let dateFormatter: ISO8601DateFormatter
    private var lines: [String] = []
    private let maxLines = 200

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.dateFormatter = formatter
    }

    func logInfo(_ message: String) {
        log(level: "INFO", message: message) { logger.info("\(message, privacy: .public)") }
    }

    func logError(_ message: String) {
        log(level: "ERROR", message: message) { logger.error("\(message, privacy: .public)") }
    }

    func recentEntries() -> [String] {
        lines
    }

    func readLogFileTail(maxLines: Int) -> [String] {
        guard let url = try? logFileURL(), let contents = try? String(contentsOf: url) else {
            return []
        }
        let fileLines = contents.split(separator: "\n").map(String.init)
        return Array(fileLines.suffix(maxLines))
    }

    func clearLogs() {
        lines.removeAll()
        if let url = try? logFileURL() {
            try? fileManager.removeItem(at: url)
        }
    }

    func appGroupPath() -> Result<URL, Error> {
        Result { try store.appGroupContainerURL() }
    }

    private func log(level: String, message: String, osLog: () -> Void) {
        osLog()
        let line = "\(timestamp()) [\(level)] \(message)"
        appendToBuffer(line)
        appendToFile(line)
    }

    private func appendToBuffer(_ line: String) {
        lines.append(line)
        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }
    }

    private func appendToFile(_ line: String) {
        guard let url = try? logFileURL() else { return }
        let data = "\(line)\n".data(using: .utf8)
        do {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !fileManager.fileExists(atPath: url.path) {
                fileManager.createFile(atPath: url.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd()
            if let data {
                try handle.write(contentsOf: data)
            }
            try handle.close()
        } catch {
            logger.error("Failed to append log: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func logFileURL() throws -> URL {
        try store.appGroupContainerURL()
            .appendingPathComponent("logs", isDirectory: true)
            .appendingPathComponent("agent.log")
    }

    private func timestamp() -> String {
        dateFormatter.string(from: Date())
    }
}
