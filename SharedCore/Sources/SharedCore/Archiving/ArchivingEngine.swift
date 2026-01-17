import Foundation

public protocol ArchivingEngine: Sendable {
    func archive(
        items: [URL],
        destination: URL,
        progress: @Sendable (Int, Int) -> Void,
        isCancelled: @Sendable () -> Bool
    ) throws
}
