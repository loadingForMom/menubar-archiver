import Foundation

public struct Job: Codable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let items: [URL]
    public let destinationFolderURL: URL
    public let operation: Operation
    public let outputName: String

    public init(
        id: UUID,
        createdAt: Date,
        items: [URL],
        destinationFolderURL: URL,
        operation: Operation,
        outputName: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.items = items
        self.destinationFolderURL = destinationFolderURL
        self.operation = operation
        self.outputName = outputName
    }
}

public extension Job {
    enum Operation: String, Codable, Sendable {
        case archive
        case extract
    }
}
