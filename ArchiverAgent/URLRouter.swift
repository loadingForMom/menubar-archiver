import Foundation

final class URLRouter {
    private let jobQueue: JobQueue

    init(jobQueue: JobQueue) {
        self.jobQueue = jobQueue
    }

    func handle(url: URL) {
        Task { await AgentLogger.shared.logInfo("URLRouter handling \(url.absoluteString)") }
        guard url.scheme == "archiver" else { return }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        guard components.host == "run" else { return }
        let jobID = components.queryItems?.first(where: { $0.name == "job" })?.value
        guard let idString = jobID, let id = UUID(uuidString: idString) else { return }

        Task {
            await AgentLogger.shared.logInfo("Enqueue job from URL: \(id.uuidString)")
            await jobQueue.enqueue(jobID: id)
        }
    }
}
