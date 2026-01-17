import AppKit
import os.log
import SharedCore

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let jobQueue = JobQueue()
    private let router: URLRouter
    private let logger = Logger(subsystem: "com.example.silentarchive", category: "AppDelegate")
    private let jobStore = JobStore()

    override init() {
        router = URLRouter(jobQueue: jobQueue)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
#if DEBUG
        enqueueDebugJobIfNeeded()
#endif
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.scheme == "archiver" {
                router.handle(url: url)
            } else {
                enqueueExtractJobIfNeeded(for: url)
            }
        }
    }

    private func enqueueExtractJobIfNeeded(for url: URL) {
        guard url.isFileURL, url.pathExtension.lowercased() == "zip" else { return }
        let zipURL = url.standardizedFileURL
        let parent = zipURL.deletingLastPathComponent()
        let baseName = zipURL.deletingPathExtension().lastPathComponent
        let folderName = Naming.uniqueFolderName(baseName: baseName, in: parent)
        let job = Job(
            id: UUID(),
            createdAt: Date(),
            items: [zipURL],
            destinationFolderURL: parent,
            operation: .extract,
            outputName: folderName
        )

        Task {
            do {
                try jobStore.write(job)
                logger.info("Enqueued extract job for \(zipURL.path, privacy: .public)")
                await jobQueue.enqueue(jobID: job.id)
            } catch {
                logger.error("Failed to enqueue extract job: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

#if DEBUG
    private func enqueueDebugJobIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "--test"), idx + 1 < args.count else { return }
        let path = args[idx + 1]
        let url = URL(fileURLWithPath: path)
        let isExtract = args.contains("--extract")
        let operation: Job.Operation = isExtract ? .extract : .archive
        let destinationFolder = url.deletingLastPathComponent()
        let outputName: String
        if isExtract {
            let baseName = url.deletingPathExtension().lastPathComponent
            outputName = Naming.uniqueFolderName(baseName: baseName, in: destinationFolder)
        } else {
            outputName = Naming.uniqueArchiveName(in: destinationFolder)
        }

        let job = Job(
            id: UUID(),
            createdAt: Date(),
            items: [url],
            destinationFolderURL: destinationFolder,
            operation: operation,
            outputName: outputName
        )

        Task {
            do {
                try jobStore.write(job)
                logger.info("DEBUG: enqueued test job for \(url.path, privacy: .public)")
                await jobQueue.enqueue(jobID: job.id)
            } catch {
                logger.error("DEBUG: failed to enqueue test job: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
#endif
}
