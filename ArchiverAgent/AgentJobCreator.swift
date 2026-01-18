import Foundation
import SharedCore

struct AgentJobCreator {
    private let store = JobStore()

    func createArchiveJob(for urls: [URL]) throws -> Job {
        let destinationFolder = resolveDestinationFolder(for: urls)
        let outputName = Naming.uniqueArchiveName(in: destinationFolder)
        let job = Job(
            id: UUID(),
            createdAt: Date(),
            items: urls,
            destinationFolderURL: destinationFolder,
            operation: .archive,
            outputName: outputName
        )
        _ = try store.write(job)
        return job
    }

    func createExtractJob(for archiveURL: URL) throws -> Job {
        let destinationFolder = archiveURL.deletingLastPathComponent()
        let outputName = Naming.uniqueExtractionFolderName(for: archiveURL, in: destinationFolder)
        let job = Job(
            id: UUID(),
            createdAt: Date(),
            items: [archiveURL],
            destinationFolderURL: destinationFolder,
            operation: .extract,
            outputName: outputName
        )
        _ = try store.write(job)
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
}
