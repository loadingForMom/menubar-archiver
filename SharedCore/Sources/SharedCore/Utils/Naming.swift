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

    public static func uniqueExtractionFolderName(
        for archiveURL: URL,
        in folder: URL,
        fileManager: FileManager = .default
    ) -> String {
        let baseName = archiveURL.deletingPathExtension().lastPathComponent
        let resolvedBase = baseName.isEmpty ? "Archive" : baseName
        var candidate = resolvedBase
        var counter = 2
        while fileManager.fileExists(atPath: folder.appendingPathComponent(candidate).path) {
            candidate = "\(resolvedBase) \(counter)"
            counter += 1
        }
        return candidate
    }
}
