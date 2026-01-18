import Foundation
import os.log
import SharedCore

final class ArchiveWorker {
    struct Progress: Sendable {
        let fractionComplete: Double
        let completed: Int
        let total: Int
    }

    private let job: Job
    private let token = CancellationToken()
    private let logger = Logger(subsystem: "com.example.silentarchive", category: "ArchiveWorker")

    init(job: Job) {
        self.job = job
    }

    func cancel() {
        token.cancel()
    }

    func run(progressHandler: @escaping (Progress) -> Void) async -> JobResult {
        let engine = ZipFoundationEngine()
        var outputURL: URL?

        do {
            let resolved = try resolveJobResources()
            defer {
                resolved.accessedResources.forEach { $0.stopAccessingSecurityScopedResource() }
            }
            let destination = resolved.destinationFolder.appendingPathComponent(job.outputName)
            outputURL = destination

            switch job.operation {
            case .archive:
                let total = try FileEnumeration.countFiles(for: resolved.items)
                progressHandler(Progress(fractionComplete: 0, completed: 0, total: total))
                try engine.archive(
                    items: resolved.items,
                    destination: destination,
                    progress: { completed, total in
                        let fraction = total > 0 ? Double(completed) / Double(total) : 1.0
                        progressHandler(Progress(fractionComplete: fraction, completed: completed, total: total))
                    },
                    isCancelled: {
                        token.isCancelled()
                    }
                )
            case .extract:
                guard let archiveURL = resolved.items.first else {
                    throw ArchiveError.unableToOpen
                }
                progressHandler(Progress(fractionComplete: 0, completed: 0, total: 0))
                try engine.extract(
                    archiveURL: archiveURL,
                    destination: destination,
                    progress: { completed, total in
                        let fraction = total > 0 ? Double(completed) / Double(total) : 1.0
                        progressHandler(Progress(fractionComplete: fraction, completed: completed, total: total))
                    },
                    isCancelled: {
                        token.isCancelled()
                    }
                )
            }

            return .success(destination)
        } catch let error as ArchiveError {
            logger.error("Archive operation failed: \(error.localizedDescription, privacy: .public)")
            cleanup(destination: outputURL)
            switch error {
            case .cancelled:
                return .canceled
            case .unableToCreate, .unableToOpen:
                return .failure(String(describing: error))
            }
        } catch {
            logger.error("Job failed: \(error.localizedDescription, privacy: .public)")
            cleanup(destination: outputURL)
            return .failure(error.localizedDescription)
        }
    }

    private func resolveJobResources() throws -> (items: [URL], destinationFolder: URL, accessedResources: [URL]) {
        var accessed: [URL] = []
        var items: [URL] = []
        do {
            for item in job.items {
                let resolved = try resolveBookmark(item.bookmark, label: item.displayName)
                try startAccessing(resolved)
                accessed.append(resolved)
                items.append(resolved)
            }

            let destinationFolder = try resolveBookmark(job.destinationFolderBookmark, label: "destination")
            try startAccessing(destinationFolder)
            accessed.append(destinationFolder)

            return (items, destinationFolder, accessed)
        } catch {
            accessed.forEach { $0.stopAccessingSecurityScopedResource() }
            throw error
        }
    }

    private func resolveBookmark(_ data: Data, label: String?) throws -> URL {
        var stale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        if stale {
            logger.warning("Resolved stale bookmark for \(label ?? "item", privacy: .public); access may be limited.")
        }
        return url
    }

    private func startAccessing(_ url: URL) throws {
        if !url.startAccessingSecurityScopedResource() {
            logger.error("Failed to access security-scoped resource: \(url.path, privacy: .public)")
            throw ArchiveWorkerError.failedToAccessResource(url)
        }
    }

    private func cleanup(destination: URL?) {
        guard let destination else { return }
        try? FileManager.default.removeItem(at: destination)
    }
}

enum ArchiveWorkerError: LocalizedError {
    case failedToAccessResource(URL)

    var errorDescription: String? {
        switch self {
        case .failedToAccessResource(let url):
            return "Failed to access security-scoped resource: \(url.path)"
        }
    }
}
