//
//  Job.swift
//  SilentArchive
//
//  Created by Sasha on 1/17/26.
//

import Foundation

public struct JobItem: Codable, Sendable {
    public let bookmark: Data
    public let displayName: String?

    public init(bookmark: Data, displayName: String? = nil) {
        self.bookmark = bookmark
        self.displayName = displayName
    }
}

public struct Job: Codable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let items: [JobItem]
    public let destinationFolderBookmark: Data
    public let operation: Operation
    public let outputName: String

    public init(
        id: UUID,
        createdAt: Date,
        items: [JobItem],
        destinationFolderBookmark: Data,
        operation: Operation,
        outputName: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.items = items
        self.destinationFolderBookmark = destinationFolderBookmark
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
