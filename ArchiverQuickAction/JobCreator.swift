import Foundation
import SharedCore

struct JobCreator {
    private let store = JobStore()

    func createJob(for urls: [URL]) throws -> Job {
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
        try store.write(job)
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
