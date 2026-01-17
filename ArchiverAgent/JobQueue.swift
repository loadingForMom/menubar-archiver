import AppKit
import Foundation
import os.log
import SharedCore

actor JobQueue {
    private var pending: [UUID] = []
    private var isRunning = false
    private var totalQueued = 0
    private var completed = 0
    private let store = JobStore()
    private let statusBar = StatusBarController()
    private let logger = Logger(subsystem: "com.example.silentarchive", category: "JobQueue")

    func enqueue(jobID: UUID) {
        pending.append(jobID)
        totalQueued += 1
        if !isRunning {
            isRunning = true
            Task { await runNext() }
        } else {
            Task { @MainActor in
                statusBar.updateQueuePosition(currentIndex: completed + 1, total: totalQueued)
            }
        }
    }

    private func runNext() async {
        guard !pending.isEmpty else {
            isRunning = false
            completed = 0
            totalQueued = 0
            await MainActor.run {
                statusBar.teardownIfIdle()
                NSApp.terminate(nil)
            }
            return
        }

        let jobID = pending.removeFirst()
        do {
            let job = try store.read(id: jobID)
            let worker = ArchiveWorker(job: job)
            await MainActor.run {
                statusBar.begin(job: job, cancelHandler: { worker.cancel() })
                statusBar.updateQueuePosition(currentIndex: completed + 1, total: totalQueued)
            }

            let result = await worker.run { progress in
                Task { @MainActor in
                    statusBar.updateProgress(progress)
                }
            }

            await MainActor.run {
                statusBar.finish(result: result)
            }
        } catch {
            logger.error("Failed to read job: \(error.localizedDescription, privacy: .public)")
            await MainActor.run {
                statusBar.finish(result: .failure(error))
            }
        }

        completed += 1
        await runNext()
    }
}
