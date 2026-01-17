import Foundation

public enum JobResult: Sendable {
    case success(URL)
    case canceled
    case failure(Error)
}
