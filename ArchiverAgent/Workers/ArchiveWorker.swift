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
        let destination = job.destinationFolderURL.appendingPathComponent(job.outputName)
        let engine = ZipFoundationEngine()

        do {
            switch job.operation {
            case .archive:
                let total = try FileEnumeration.countFiles(for: job.items)
                progressHandler(Progress(fractionComplete: 0, completed: 0, total: total))
                try engine.archive(
                    items: job.items,
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
                guard let archiveURL = job.items.first else {
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
            cleanup(destination: destination)
            switch error {
            case .cancelled:
                return .canceled
            case .unableToCreate, .unableToOpen:
                return .failure(String(describing: error))
            }
        } catch {
            logger.error("Job failed: \(error.localizedDescription, privacy: .public)")
            cleanup(destination: destination)
            return .failure(error.localizedDescription)
        }
    }

    private func cleanup(destination: URL) {
        try? FileManager.default.removeItem(at: destination)
    }
}
