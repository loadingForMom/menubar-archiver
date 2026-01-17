//
//  JobQueue.swift
//  SilentArchive
//
//  Created by Sasha on 1/17/26.
//


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

    // Main-actor UI controller — создаём лениво на главном акторе
    @MainActor private static let statusBar = StatusBarController()

    func enqueue(jobID: UUID) {
        pending.append(jobID)
        totalQueued += 1

        if !isRunning {
            isRunning = true
            Task { await runNext() }
        } else {
            // снимем значения внутри actor-контекста
            let currentIndex = completed + 1
            let total = totalQueued
            Task { @MainActor in
                Self.statusBar.updateQueuePosition(currentIndex: currentIndex, total: total)
            }
        }
    }

    private func runNext() async {
        guard !pending.isEmpty else {
            isRunning = false
            completed = 0
            totalQueued = 0

            await MainActor.run {
                Self.statusBar.teardownIfIdle()
                NSApp.terminate(nil)
            }
            return
        }

        let jobID = pending.removeFirst()

        do {
            let job = try store.read(id: jobID)
            let worker = ArchiveWorker(job: job)

            // Снимем queue-значения в actor-контексте
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
                Self.statusBar.finish(result: .failure(error))
            }
        }

        completed += 1
        await runNext()
    }
}
