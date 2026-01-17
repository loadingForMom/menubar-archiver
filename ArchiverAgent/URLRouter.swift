import Foundation

final class URLRouter {
    private let jobQueue: JobQueue

    init(jobQueue: JobQueue) {
        self.jobQueue = jobQueue
    }

    func handle(url: URL) {
        guard url.scheme == "archiver" else { return }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        guard components.host == "run" else { return }
        let jobID = components.queryItems?.first(where: { $0.name == "job" })?.value
        guard let idString = jobID, let id = UUID(uuidString: idString) else { return }

        Task {
            await jobQueue.enqueue(jobID: id)
        }
    }
}
