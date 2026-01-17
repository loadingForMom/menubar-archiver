//
//  ArchivingEngine.swift
//  SilentArchive
//
//  Created by Sasha on 1/17/26.
//

import Foundation

public protocol ArchivingEngine: Sendable {
    func archive(
        items: [URL],
        destination: URL,
        progress: @Sendable (Int, Int) -> Void,
        isCancelled: @Sendable () -> Bool
    ) throws
}

