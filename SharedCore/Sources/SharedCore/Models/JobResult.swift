//
//  JobResult.swift
//  SilentArchive
//
//  Created by Sasha on 1/17/26.
//

import Foundation

public enum JobResult: Sendable {
    case success(URL)
    case canceled
    case failure(String)
}
