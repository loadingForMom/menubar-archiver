//
//  AppDelegate.swift
//  SilentArchive
//
//  Created by Sasha on 1/17/26.
//


import AppKit
import SharedCore

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let jobQueue = JobQueue()
    private let router: URLRouter

    override init() {
        router = URLRouter(jobQueue: jobQueue)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
#if DEBUG
let args = ProcessInfo.processInfo.arguments
if let idx = args.firstIndex(of: "--test"), idx + 1 < args.count {
    let path = args[idx + 1]
    let url = URL(fileURLWithPath: path)
    Task {
        do {
            let job = Job(
                id: UUID(),
                createdAt: Date(),
                items: [url],
                destinationFolderURL: url.deletingLastPathComponent(),
                operation: .archive,
                outputName: Naming.uniqueArchiveName(in: url.deletingLastPathComponent())
            )
            _ = try JobStore().write(job)
            await jobQueue.enqueue(jobID: job.id)
        } catch {
            NSLog("Test job failed: \(error)")
        }
    }
}
#endif
    }
    

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            router.handle(url: url)
        }
    }
}
