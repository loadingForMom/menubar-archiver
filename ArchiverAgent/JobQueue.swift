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
    @MainActor private let statusBar = StatusBarController()
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
            await finishAndMaybeTerminate()
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
                statusBar.finish(result: .failure(error.localizedDescription))
            }
        }

        completed += 1
        await runNext()
    }

    private func finishAndMaybeTerminate() async {
        try? await Task.sleep(nanoseconds: 1_600_000_000)
        guard pending.isEmpty else {
            await runNext()
            return
        }
        isRunning = false
        completed = 0
        totalQueued = 0
        await MainActor.run {
            statusBar.teardownIfIdle()
            NSApp.terminate(nil)
        }
    }
}
