//
//  FileEnumeration.swift
//  SilentArchive
//
//  Created by Sasha on 1/17/26.
//

import Foundation

public enum FileEnumeration {
    public struct ManifestEntry: Sendable {
        public let fileURL: URL
        public let relativePath: String
    }

    public static func buildManifest(for items: [URL], fileManager: FileManager = .default) throws -> [ManifestEntry] {
        var manifest: [ManifestEntry] = []
        for item in items {
            let standardized = item.standardizedFileURL
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: standardized.path, isDirectory: &isDirectory), isDirectory.boolValue {
                let rootName = standardized.lastPathComponent
                let enumerator = fileManager.enumerator(at: standardized, includingPropertiesForKeys: [.isRegularFileKey])
                while let child = enumerator?.nextObject() as? URL {
                    let resourceValues = try child.resourceValues(forKeys: [.isRegularFileKey])
                    guard resourceValues.isRegularFile == true else { continue }
                    let relativeSuffix = child.path.replacingOccurrences(of: standardized.path, with: "")
                    let relativePath = rootName + relativeSuffix
                    manifest.append(ManifestEntry(fileURL: child, relativePath: relativePath))
                }
            } else {
                manifest.append(ManifestEntry(fileURL: standardized, relativePath: standardized.lastPathComponent))
            }
        }
        return manifest
    }

    public static func countFiles(for items: [URL], fileManager: FileManager = .default) throws -> Int {
        try buildManifest(for: items, fileManager: fileManager).count
    }
}
