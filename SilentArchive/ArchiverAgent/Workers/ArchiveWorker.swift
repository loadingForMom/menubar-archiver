//
//  ArchiveWorker.swift
//  SilentArchive
//
//  Created by Sasha on 1/17/26.
//


import Foundation
import os.log
import SharedCore

final class ArchiveWorker {
    struct Progress {
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

    func run(progressHandler: @escaping @Sendable (Progress) -> Void) async -> JobResult {
        let destination = job.destinationFolderURL.appendingPathComponent(job.outputName)
        let engine = ZipFoundationEngine()

        do {
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

            return .success(destination)
        } catch let error as ArchiveError {
            cleanup(destination: destination)
            switch error {
            case .cancelled:
                return .canceled
            case .unableToCreate:
                return .failure(error)
            }
        } catch {
            logger.error("Archiving failed: \(error.localizedDescription, privacy: .public)")
            cleanup(destination: destination)
            return .failure(error)
        }
    }

    private func cleanup(destination: URL) {
        try? FileManager.default.removeItem(at: destination)
    }
}