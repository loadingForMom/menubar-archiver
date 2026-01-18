import AppKit
import UniformTypeIdentifiers
import SharedCore

final class QuickActionHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        let logger = QuickActionLogger()
        logger.logInfo("Quick Action beginRequest")
        Task {
            let urls = await resolveFileURLs(from: context.inputItems)
            logger.writeLastQuickAction(selectedCount: urls.count)
            guard !urls.isEmpty else {
                logger.logInfo("No file URLs resolved from Quick Action input items.")
                context.completeRequest(returningItems: [], completionHandler: nil)
                return
            }

            do {
                let jobCreator = JobCreator()
                let job = try jobCreator.createJob(for: urls)
                let jobPath = try JobStore().jobFileURL(for: job.id)
                logger.logInfo("Created archive job \(job.id.uuidString) at \(jobPath.path)")
                let url = URL(string: "archiver://run?job=\(job.id.uuidString)")
                if let url {
                    let opened = NSWorkspace.shared.open(url)
                    if opened {
                        logger.logInfo("Opened URL scheme for job \(job.id.uuidString)")
                    } else {
                        logger.logError("Failed to open URL scheme for job \(job.id.uuidString)")
                    }
                } else {
                    logger.logError("Failed to build URL scheme for job \(job.id.uuidString)")
                }
                context.completeRequest(returningItems: [], completionHandler: nil)
            } catch {
                logger.logError("Quick Action failed: \(error.localizedDescription)")
                context.completeRequest(returningItems: [], completionHandler: nil)
            }
        }
    }

    private func resolveFileURLs(from items: [Any]) async -> [URL] {
        var urls: [URL] = []
        for item in items {
            guard let extensionItem = item as? NSExtensionItem else { continue }
            guard let providers = extensionItem.attachments else { continue }
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    if let url = await loadURL(from: provider) {
                        urls.append(url)
                    }
                }
            }
        }
        return urls
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else if let url = item as? URL {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
