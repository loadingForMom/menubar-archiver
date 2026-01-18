import AppKit
import Foundation
import SharedCore

actor JobQueue {
    private var pending: [UUID] = []
    private var isRunning = false
    private var totalQueued = 0
    private var completed = 0
    private let store = JobStore()
    private let statusBar = StatusBarController()
    private let logger = AgentLogger.shared

    func enqueue(jobID: UUID) {
        pending.append(jobID)
        totalQueued += 1
        Task { await logger.logInfo("Queued job \(jobID.uuidString). Pending: \(pending.count)") }
        postJobStatus(status: .queued, outputURL: nil, jobID: jobID)
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
            }
#if !DEBUG
            await MainActor.run {
                NSApp.terminate(nil)
            }
#endif
            return
        }

        let jobID = pending.removeFirst()
        do {
            let job = try store.read(id: jobID)
            let jobPath = try store.jobFileURL(for: jobID)
            await logger.logInfo("Read job \(jobID.uuidString) from \(jobPath.path)")
            postJobStatus(status: .running, outputURL: nil, jobID: jobID)

            let workerResult = await runWorker(for: job)

            await MainActor.run {
                statusBar.finish(result: workerResult)
            }
            postJobStatus(status: status(for: workerResult), outputURL: outputURL(for: workerResult), jobID: jobID)
        } catch {
            await logger.logError("Failed to read job \(jobID.uuidString): \(error.localizedDescription)")
            await MainActor.run {
                statusBar.finish(result: .failure(error))
            }
            postJobStatus(status: .failed, outputURL: nil, jobID: jobID)
        }

        completed += 1
        await runNext()
    }

    private func runWorker(for job: Job) async -> JobResult {
        await MainActor.run {
            statusBar.updateQueuePosition(currentIndex: completed + 1, total: totalQueued)
        }

        switch job.operation {
        case .archive:
            let worker = ArchiveWorker(job: job)
            await MainActor.run {
                statusBar.begin(job: job, cancelHandler: { worker.cancel() })
                statusBar.updateQueuePosition(currentIndex: completed + 1, total: totalQueued)
            }
            return await worker.run { progress in
                Task { @MainActor in
                    statusBar.updateProgress(progress)
                }
            }
        case .extract:
            let worker = ExtractWorker(job: job)
            await MainActor.run {
                statusBar.begin(job: job, cancelHandler: { worker.cancel() })
                statusBar.updateQueuePosition(currentIndex: completed + 1, total: totalQueued)
            }
            return await worker.run { progress in
                Task { @MainActor in
                    statusBar.updateProgress(progress)
                }
            }
        }
    }

    private func status(for result: JobResult) -> JobStatus {
        switch result {
        case .success:
            return .completed
        case .canceled:
            return .canceled
        case .failure:
            return .failed
        }
    }

    private func outputURL(for result: JobResult) -> URL? {
        switch result {
        case .success(let url):
            return url
        case .canceled, .failure:
            return nil
        }
    }

    private func postJobStatus(status: JobStatus, outputURL: URL?, jobID: UUID?) {
        var userInfo: [String: Any] = ["status": status.rawValue]
        if let outputURL {
            userInfo["output"] = outputURL.path
        }
        if let jobID {
            userInfo["jobID"] = jobID.uuidString
        }
        NotificationCenter.default.post(name: .agentJobStatusDidChange, object: nil, userInfo: userInfo)
    }
}
