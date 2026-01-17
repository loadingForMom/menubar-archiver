//
//  JobStatus.swift
//  SilentArchive
//
//  Created by Sasha on 1/17/26.
//

import Foundation

public enum JobStatus: String, Codable, Sendable {
    case queued
    case running
    case completed
    case canceled
    case failed
}
