//
//  ArchivingEngine.swift
//  SilentArchive
//
//  Created by Sasha on 1/17/26.
//

import Foundation

public protocol ArchivingEngine {
    func archive(
        items: [URL],
        destination: URL,
        progress: (Int, Int) -> Void,
        isCancelled: () -> Bool
    ) throws

    func extract(
        archiveURL: URL,
        destination: URL,
        progress: (Int, Int) -> Void,
        isCancelled: () -> Bool
    ) throws
}
