import Foundation
import ZIPFoundation

public struct ZipFoundationEngine: ArchivingEngine {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func archive(
        items: [URL],
        destination: URL,
        progress: @Sendable (Int, Int) -> Void,
        isCancelled: @Sendable () -> Bool
    ) throws {
        let manifest = try FileEnumeration.buildManifest(for: items, fileManager: fileManager)
        let totalFiles = manifest.count
        var processed = 0

        guard let archive = Archive(url: destination, accessMode: .create) else {
            throw ArchiveError.unableToCreate
        }

        for entry in manifest {
            if isCancelled() {
                throw ArchiveError.cancelled
            }
            try archive.addEntry(with: entry.relativePath, fileURL: entry.fileURL, compressionMethod: .deflate)
            processed += 1
            progress(processed, totalFiles)
        }
    }

    public func extract(
        archiveURL: URL,
        destination: URL,
        progress: @Sendable (Int, Int) -> Void,
        isCancelled: @Sendable () -> Bool
    ) throws {
        guard let archive = Archive(url: archiveURL, accessMode: .read) else {
            throw ArchiveError.unableToOpen
        }

        let totalEntries = archive.count
        var processed = 0
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

        for entry in archive {
            if isCancelled() {
                throw ArchiveError.cancelled
            }
            let outputURL = destination.appendingPathComponent(entry.path)
            switch entry.type {
            case .directory:
                try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)
            default:
                try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try archive.extract(entry, to: outputURL)
            }
            processed += 1
            progress(processed, totalEntries)
        }
    }
}

public enum ArchiveError: Error {
    case unableToCreate
    case unableToOpen
    case cancelled
}
