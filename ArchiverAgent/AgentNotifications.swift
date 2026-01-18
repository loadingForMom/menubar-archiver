import Foundation
import SharedCore

extension Notification.Name {
    static let agentJobStatusDidChange = Notification.Name("AgentJobStatusDidChange")
}

struct AgentJobStatusUpdate {
    let status: JobStatus
    let outputURL: URL?
    let jobID: UUID?
}
