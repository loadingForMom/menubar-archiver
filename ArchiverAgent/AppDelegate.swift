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
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            router.handle(url: url)
        }
    }
}
