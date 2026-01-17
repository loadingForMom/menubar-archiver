import Foundation
import os
import SharedCore

struct JobCreator {
    private let store = JobStore()
    private let logger = Logger(subsystem: "com.example.silentarchive", category: "JobCreator")

    func createJob(for urls: [URL]) throws -> Job {
        let destinationFolder = resolveDestinationFolder(for: urls)
        let outputName = Naming.uniqueArchiveName(in: destinationFolder)
        let itemBookmarks = try urls.map { url -> JobItem in
            let bookmark = try makeBookmark(for: url, readOnly: true)
            return JobItem(bookmark: bookmark, displayName: url.lastPathComponent)
        }
        let destinationBookmark = try makeBookmark(for: destinationFolder, readOnly: false)
        let job = Job(
            id: UUID(),
            createdAt: Date(),
            items: itemBookmarks,
            destinationFolderBookmark: destinationBookmark,
            operation: .archive,
            outputName: outputName
        )
        try store.write(job)
        logger.info("Created archive job \(job.id.uuidString, privacy: .public) for \(urls.count, privacy: .public) items")
        return job
    }

    private func resolveDestinationFolder(for items: [URL]) -> URL {
        let parents = items.map { $0.deletingLastPathComponent().standardizedFileURL }
        guard let first = parents.first else {
            return FileManager.default.homeDirectoryForCurrentUser
        }
        let allSame = parents.allSatisfy { $0 == first }
        return allSame ? first : first
    }

    private func makeBookmark(for url: URL, readOnly: Bool) throws -> Data {
        var options: URL.BookmarkCreationOptions = [.withSecurityScope]
        if readOnly {
            options.insert(.securityScopeAllowOnlyReadAccess)
        }
        do {
            return try url.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
            logger.error("Failed to create bookmark for \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}
