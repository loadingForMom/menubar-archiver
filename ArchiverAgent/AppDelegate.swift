import AppKit
import SharedCore

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let jobQueue = JobQueue()
    private let router: URLRouter
#if DEBUG
    private var debugPanelController: DebugPanelWindowController?
#endif

    override init() {
        router = URLRouter(jobQueue: jobQueue)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Task {
            await AgentLogger.shared.logInfo("Agent didFinishLaunching")
            let appGroupResult = await AgentLogger.shared.appGroupPath()
            switch appGroupResult {
            case .success(let url):
                await AgentLogger.shared.logInfo("App Group container: \(url.path)")
            case .failure(let error):
                await AgentLogger.shared.logError("App Group error: \(error.localizedDescription)")
            }
        }
#if DEBUG
        let controller = DebugPanelWindowController(jobQueue: jobQueue)
        debugPanelController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
#endif
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        Task { await AgentLogger.shared.logInfo("application:open urls: \(urls.map(\.absoluteString).joined(separator: \", \"))") }
        for url in urls {
            if url.scheme == "archiver" {
                router.handle(url: url)
            } else {
                handleIncomingURLs([url])
            }
        }
    }

    func application(_ application: NSApplication, openFile filename: String) -> Bool {
        Task { await AgentLogger.shared.logInfo("application:openFile \(filename)") }
        handleIncomingURLs([URL(fileURLWithPath: filename)])
        return true
    }

    func application(_ application: NSApplication, openFiles filenames: [String]) {
        Task { await AgentLogger.shared.logInfo("application:openFiles \(filenames.joined(separator: \", \"))") }
        let urls = filenames.map { URL(fileURLWithPath: $0) }
        handleIncomingURLs(urls)
    }

    private func handleIncomingURLs(_ urls: [URL]) {
        let zipURLs = urls.filter { $0.pathExtension.lowercased() == "zip" }
        guard !zipURLs.isEmpty else {
            Task { await AgentLogger.shared.logInfo("No ZIP files found in open request.") }
            return
        }
        for zipURL in zipURLs {
            Task { await enqueueExtractJob(for: zipURL) }
        }
    }

    private func enqueueExtractJob(for url: URL) async {
        let creator = AgentJobCreator()
        do {
            let job = try creator.createExtractJob(for: url)
            let jobPath = try JobStore().jobFileURL(for: job.id)
            await AgentLogger.shared.logInfo("Created extract job \(job.id.uuidString) for \(url.path)")
            await AgentLogger.shared.logInfo("Wrote extract job to \(jobPath.path)")
            await jobQueue.enqueue(jobID: job.id)
        } catch {
            await AgentLogger.shared.logError("Failed to create extract job for \(url.path): \(error.localizedDescription)")
        }
    }
}
