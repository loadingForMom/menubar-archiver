import Foundation
import SharedCore

final class ExtractWorker {
    private let job: Job
    private let token = CancellationToken()
    private let logger = AgentLogger.shared

    init(job: Job) {
        self.job = job
    }

    func cancel() {
        token.cancel()
    }

    func run(progressHandler: @escaping @Sendable (JobProgress) -> Void) async -> JobResult {
        guard let archiveURL = job.items.first else {
            await logger.logError("Extract worker missing archive URL for job \(job.id.uuidString)")
            return .failure(ArchiveError.unableToOpen)
        }
        let destination = job.destinationFolderURL.appendingPathComponent(job.outputName, isDirectory: true)
        let engine = ZipFoundationEngine()
        var lastLoggedBucket = -1

        await logger.logInfo("Extract worker starting for job \(job.id.uuidString) -> \(destination.path)")

        do {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try engine.extract(archiveURL: archiveURL, destination: destination, progress: { completed, total in
                let fraction = total > 0 ? Double(completed) / Double(total) : 1.0
                progressHandler(JobProgress(fractionComplete: fraction, completed: completed, total: total))
                let percent = Int(fraction * 100)
                let bucket = percent / 10
                if bucket != lastLoggedBucket {
                    lastLoggedBucket = bucket
                    Task { await self.logger.logInfo("Extract progress \(percent)% for job \(self.job.id.uuidString)") }
                }
            }, isCancelled: {
                self.token.isCancelled()
            })

            await logger.logInfo("Extract worker completed job \(job.id.uuidString)")
            return .success(destination)
        } catch let error as ArchiveError {
            cleanup(destination: destination)
            switch error {
            case .cancelled:
                await logger.logInfo("Extract worker canceled job \(job.id.uuidString)")
                return .canceled
            case .unableToCreate, .unableToOpen:
                await logger.logError("Extract worker failed job \(job.id.uuidString): \(error)")
                return .failure(error)
            }
        } catch {
            await logger.logError("Extract failed for job \(job.id.uuidString): \(error.localizedDescription)")
            cleanup(destination: destination)
            return .failure(error)
        }
    }

    private func cleanup(destination: URL) {
        try? FileManager.default.removeItem(at: destination)
    }
}
