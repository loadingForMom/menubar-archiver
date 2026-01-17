import Foundation

public struct JobStore {
    public static let appGroupIdentifier = "group.com.example.silentarchive"

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func write(_ job: Job) throws -> URL {
        let jobURL = try jobFileURL(for: job.id)
        let data = try JSONEncoder.jobEncoder.encode(job)
        try fileManager.createDirectory(at: jobURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: jobURL, options: [.atomic])
        return jobURL
    }

    public func read(id: UUID) throws -> Job {
        let jobURL = try jobFileURL(for: id)
        let data = try Data(contentsOf: jobURL)
        return try JSONDecoder.jobDecoder.decode(Job.self, from: data)
    }

    public func jobFileURL(for id: UUID) throws -> URL {
        let containerURL = try appGroupContainerURL()
        return containerURL
            .appendingPathComponent("jobs", isDirectory: true)
            .appendingPathComponent("\(id.uuidString).json")
    }

    public func appGroupContainerURL() throws -> URL {
        guard let url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier) else {
            throw JobStoreError.missingAppGroupContainer
        }
        return url
    }
}

public enum JobStoreError: Error {
    case missingAppGroupContainer
}

private extension JSONEncoder {
    static var jobEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var jobDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
