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
}

public enum ArchiveError: Error {
    case unableToCreate
    case cancelled
}
