//
//  ZipFoundationEngine.swift
//  SilentArchive
//
//  Created by Sasha on 1/17/26.
//

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
        progress: (Int, Int) -> Void,
        isCancelled: () -> Bool
    ) throws {
        let manifest = try FileEnumeration.buildManifest(for: items, fileManager: fileManager)
        let totalFiles = manifest.count
        var processed = 0

        let archive: Archive
        do {
            archive = try Archive(url: destination, accessMode: .create)
        } catch {
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
        progress: (Int, Int) -> Void,
        isCancelled: () -> Bool
    ) throws {
        let archive: Archive
        do {
            archive = try Archive(url: archiveURL, accessMode: .read)
        } catch {
            throw ArchiveError.unableToOpen
        }

        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

        let entries = Array(archive)
        let total = entries.count
        var processed = 0

        for entry in entries {
            if isCancelled() {
                throw ArchiveError.cancelled
            }
            let outputURL = destination.appendingPathComponent(entry.path)
            if entry.type == .directory {
                try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)
            } else {
                try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try archive.extract(entry, to: outputURL)
            }
            processed += 1
            progress(processed, total)
        }
    }
}

public enum ArchiveError: Error {
    case unableToCreate
    case unableToOpen
    case cancelled
}
