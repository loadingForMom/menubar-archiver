//
//  QuickActionHandler.swift
//  SilentArchive
//
//  Created by Sasha on 1/17/26.
//


import AppKit
import UniformTypeIdentifiers
import SharedCore

final class QuickActionHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        Task {
            let urls = await resolveFileURLs(from: context.inputItems)
            guard !urls.isEmpty else {
                context.completeRequest(returningItems: [], completionHandler: nil)
                return
            }

            do {
                let jobCreator = JobCreator()
                let job = try jobCreator.createJob(for: urls)
                let url = URL(string: "archiver://run?job=\(job.id.uuidString)")
                if let url {
                    NSWorkspace.shared.open(url)
                }
                context.completeRequest(returningItems: [], completionHandler: nil)
            } catch {
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