//
//  JobStore.swift
//  SilentArchive
//
//  Created by Sasha on 1/17/26.
//

import Foundation
import os

public struct JobStore {
    public static let appGroupIdentifier = "group.com.example.silentarchive"

    private let fileManager: FileManager
    private let logger = Logger(subsystem: "com.example.silentarchive", category: "JobStore")

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func write(_ job: Job) throws -> URL {
        let jobURL = try jobFileURL(for: job.id)
        let data = try JSONEncoder.jobEncoder.encode(job)
        do {
            try fileManager.createDirectory(at: jobURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: jobURL, options: [.atomic])
        } catch {
            logger.error("Failed to write job \(job.id.uuidString, privacy: .public) to \(jobURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw JobStoreError.failedToWrite(jobURL, error)
        }
        return jobURL
    }

    public func read(id: UUID) throws -> Job {
        let jobURL = try jobFileURL(for: id)
        do {
            let data = try Data(contentsOf: jobURL)
            return try JSONDecoder.jobDecoder.decode(Job.self, from: data)
        } catch {
            logger.error("Failed to read job \(id.uuidString, privacy: .public) from \(jobURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw JobStoreError.failedToRead(jobURL, error)
        }
    }

    public func jobFileURL(for id: UUID) throws -> URL {
        let containerURL = try appGroupContainerURL()
        return containerURL
            .appendingPathComponent("jobs", isDirectory: true)
            .appendingPathComponent("\(id.uuidString).json")
    }

    public func appGroupContainerURL() throws -> URL {
        guard let url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier) else {
            logger.error("Missing App Group container for \(Self.appGroupIdentifier, privacy: .public)")
            throw JobStoreError.missingAppGroupContainer(Self.appGroupIdentifier)
        }
        return url
    }
}

public enum JobStoreError: LocalizedError {
    case missingAppGroupContainer(String)
    case failedToWrite(URL, Error)
    case failedToRead(URL, Error)

    public var errorDescription: String? {
        switch self {
        case .missingAppGroupContainer(let identifier):
            return "Missing App Group container for \(identifier)."
        case .failedToWrite(let url, let error):
            return "Failed to write job file at \(url.path): \(error.localizedDescription)"
        case .failedToRead(let url, let error):
            return "Failed to read job file at \(url.path): \(error.localizedDescription)"
        }
    }
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
