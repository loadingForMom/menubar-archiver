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
        let args = ProcessInfo.processInfo.arguments
        print("DEBUG args:", args)
        enqueueDebugJobIfNeeded(args: args)
        #endif
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.scheme == "archiver" {
                router.handle(url: url)
            } else {
                // "Open With" / double-click for zip -> extract
                enqueueExtractJobIfNeeded(for: url)
            }
        }
    }

    // MARK: - Extract-on-open (zip)

    private func enqueueExtractJobIfNeeded(for url: URL) {
        guard url.isFileURL else { return }
        let ext = url.pathExtension.lowercased()
        guard ext == "zip" else { return }

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
                _ = try jobStore.write(job)
                logger.info("Enqueued extract job for \(zipURL.path, privacy: .public)")

                // Optional but very useful to see in Debug console:
                print("Wrote extract job:", job.id)

                // Real read-back verification (confirms App Group container works):
                let readBack = try jobStore.read(id: job.id)
                print("Read-back extract job OK:", readBack.id, readBack.items)

                await jobQueue.enqueue(jobID: job.id)
            } catch {
                logger.error("Failed to enqueue extract job: \(error.localizedDescription, privacy: .public)")
                print("ERROR enqueueExtractJobIfNeeded:", error.localizedDescription)
            }
        }
    }

    // MARK: - Debug: --test <path> [--extract]

    #if DEBUG
    private func enqueueDebugJobIfNeeded(args: [String]) {
        guard let idx = args.firstIndex(of: "--test"), idx + 1 < args.count else { return }

        let path = args[idx + 1]
        let url = URL(fileURLWithPath: path).standardizedFileURL
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
                _ = try jobStore.write(job)
                print("Wrote debug job:", job.id, "op:", job.operation.rawValue, "item:", url.path)

                // Real read-back verification:
                let readBack = try jobStore.read(id: job.id)
                print("Read-back debug job OK:", readBack.id, readBack.items)

                logger.info("DEBUG: enqueued test job for \(url.path, privacy: .public)")
                await jobQueue.enqueue(jobID: job.id)
            } catch {
                logger.error("DEBUG: failed to enqueue test job: \(error.localizedDescription, privacy: .public)")
                print("ERROR enqueueDebugJobIfNeeded:", error.localizedDescription)
            }
        }
    }
    #endif
}
