import Foundation

public enum JobStatus: String, Codable, Sendable {
    case queued
    case running
    case completed
    case canceled
    case failed
}
