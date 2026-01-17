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
    private let logger = Logger(subsystem: "com.example.silentarchive", category: "JobQueue")

    @MainActor private static let statusBar = StatusBarController()

    func enqueue(jobID: UUID) {
        pending.append(jobID)
        totalQueued += 1

        if !isRunning {
            isRunning = true
            Task { await runNext() }
        } else {
            // снимай значения внутри actor
            let currentIndex = completed + 1
            let total = totalQueued
            Task { @MainActor in
                Self.statusBar.updateQueuePosition(currentIndex: currentIndex, total: total)
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

            let currentIndex = completed + 1
            let total = totalQueued

            await MainActor.run {
                Self.statusBar.begin(job: job, cancelHandler: { worker.cancel() })
                Self.statusBar.updateQueuePosition(currentIndex: currentIndex, total: total)
            }

            let result = await worker.run { progress in
                Task { @MainActor in
                    Self.statusBar.updateProgress(progress)
                }
            }

            await MainActor.run {
                Self.statusBar.finish(result: result)
            }
        } catch {
            logger.error("Failed to read job: \(error.localizedDescription, privacy: .public)")
            await MainActor.run {
                Self.statusBar.finish(result: .failure(error.localizedDescription))
            }
        }

        completed += 1
        await runNext()
    }

    private func finishAndMaybeTerminate() async {
        isRunning = false
        completed = 0
        totalQueued = 0
        try? await Task.sleep(nanoseconds: 1_700_000_000)
        await MainActor.run {
            Self.statusBar.teardownIfIdle()
            NSApp.terminate(nil)
        }
    }
}
