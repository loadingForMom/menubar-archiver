//
//  Naming.swift
//  SilentArchive
//
//  Created by Sasha on 1/17/26.
//

import Foundation

public enum Naming {
    public static func uniqueArchiveName(in folder: URL, fileManager: FileManager = .default) -> String {
        let baseName = "Archive"
        let ext = "zip"
        var candidate = "\(baseName).\(ext)"
        var counter = 2
        while fileManager.fileExists(atPath: folder.appendingPathComponent(candidate).path) {
            candidate = "\(baseName) \(counter).\(ext)"
            counter += 1
        }
        return candidate
    }

    public static func uniqueFolderName(baseName: String, in folder: URL, fileManager: FileManager = .default) -> String {
        var candidate = baseName
        var counter = 2
        while fileManager.fileExists(atPath: folder.appendingPathComponent(candidate).path) {
            candidate = "\(baseName) \(counter)"
            counter += 1
        }
        return candidate
    }
}
