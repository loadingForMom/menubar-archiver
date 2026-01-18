#if DEBUG
import AppKit
import SharedCore
import UniformTypeIdentifiers

@MainActor
final class DebugPanelWindowController: NSWindowController {
    private let jobQueue: JobQueue
    private let jobCreator = AgentJobCreator()
    private let logTextView = NSTextView()
    private let appGroupPathField = NSTextField(labelWithString: "Resolving…")
    private let appGroupStatusField = NSTextField(labelWithString: "")
    private let jobStatusField = NSTextField(labelWithString: "Idle")
    private let outputPathField = NSTextField(labelWithString: "")
    private var logTimer: Timer?

    init(jobQueue: JobQueue) {
        self.jobQueue = jobQueue
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SilentArchive Debug Panel"
        window.center()
        super.init(window: window)
        setupContent()
        refreshAppGroupStatus()
        observeJobStatus()
        startLogUpdates()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        logTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    private func setupContent() {
        guard let contentView = window?.contentView else { return }

        let containerLabel = label(with: "App Group Container:")
        let statusLabel = label(with: "Status:")
        let jobLabel = label(with: "Current Job:")
        let outputLabel = label(with: "Output Path:")

        appGroupPathField.lineBreakMode = .byTruncatingMiddle
        outputPathField.lineBreakMode = .byTruncatingMiddle

        let buttonsStack = NSStackView(views: [
            makeButton(title: "Pick Files to Archive…", action: #selector(pickFilesToArchive)),
            makeButton(title: "Pick ZIP to Extract…", action: #selector(pickZipToExtract)),
            makeButton(title: "Reveal Jobs Folder", action: #selector(revealJobsFolder)),
            makeButton(title: "Clear Logs", action: #selector(clearLogs))
        ])
        buttonsStack.orientation = .horizontal
        buttonsStack.alignment = .centerY
        buttonsStack.spacing = 12

        logTextView.isEditable = false
        logTextView.isSelectable = true
        logTextView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = logTextView

        let stackView = NSStackView(views: [
            containerLabel,
            appGroupPathField,
            statusLabel,
            appGroupStatusField,
            jobLabel,
            jobStatusField,
            outputLabel,
            outputPathField,
            buttonsStack,
            scrollView
        ])
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 240)
        ])
    }

    private func label(with text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        return label
    }

    private func makeButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }

    private func refreshAppGroupStatus() {
        Task {
            let result = await AgentLogger.shared.appGroupPath()
            switch result {
            case .success(let url):
                appGroupPathField.stringValue = url.path
                appGroupStatusField.stringValue = "App Group OK"
            case .failure(let error):
                appGroupPathField.stringValue = "Unavailable"
                appGroupStatusField.stringValue = error.localizedDescription
            }
        }
    }

    private func observeJobStatus() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleJobStatusNotification(_:)),
            name: .agentJobStatusDidChange,
            object: nil
        )
    }

    private func startLogUpdates() {
        logTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshLogs()
        }
        refreshLogs()
    }

    private func refreshLogs() {
        Task {
            let memoryLines = await AgentLogger.shared.recentEntries()
            let fileLines = await AgentLogger.shared.readLogFileTail(maxLines: 200)
            let combined = (
                ["— In-Memory Log —"] + memoryLines + ["", "— agent.log —"] + fileLines
            ).joined(separator: "\n")
            await MainActor.run {
                self.logTextView.string = combined
                self.logTextView.scrollToEndOfDocument(nil)
            }
        }
    }

    @objc private func pickFilesToArchive() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.begin { [weak self] response in
            guard response == .OK else { return }
            let urls = panel.urls
            Task { await self?.enqueueArchive(for: urls) }
        }
    }

    @objc private func pickZipToExtract() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.zip]
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.urls.first else { return }
            Task { await self?.enqueueExtract(for: url) }
        }
    }

    @objc private func revealJobsFolder() {
        Task {
            let result = await AgentLogger.shared.appGroupPath()
            guard case .success(let url) = result else { return }
            let jobsURL = url.appendingPathComponent("jobs", isDirectory: true)
            try? FileManager.default.createDirectory(at: jobsURL, withIntermediateDirectories: true)
            NSWorkspace.shared.activateFileViewerSelecting([jobsURL])
        }
    }

    @objc private func clearLogs() {
        Task {
            await AgentLogger.shared.clearLogs()
            await MainActor.run {
                logTextView.string = ""
            }
        }
    }

    private func enqueueArchive(for urls: [URL]) async {
        guard !urls.isEmpty else { return }
        do {
            let job = try jobCreator.createArchiveJob(for: urls)
            await AgentLogger.shared.logInfo("Debug panel created archive job \(job.id.uuidString)")
            let jobPath = try JobStore().jobFileURL(for: job.id)
            await AgentLogger.shared.logInfo("Debug panel wrote archive job to \(jobPath.path)")
            await jobQueue.enqueue(jobID: job.id)
        } catch {
            await AgentLogger.shared.logError("Debug panel failed to create archive job: \(error.localizedDescription)")
        }
    }

    private func enqueueExtract(for url: URL) async {
        do {
            let job = try jobCreator.createExtractJob(for: url)
            await AgentLogger.shared.logInfo("Debug panel created extract job \(job.id.uuidString)")
            let jobPath = try JobStore().jobFileURL(for: job.id)
            await AgentLogger.shared.logInfo("Debug panel wrote extract job to \(jobPath.path)")
            await jobQueue.enqueue(jobID: job.id)
        } catch {
            await AgentLogger.shared.logError("Debug panel failed to create extract job: \(error.localizedDescription)")
        }
    }

    @objc private func handleJobStatusNotification(_ notification: Notification) {
        guard let status = notification.userInfo?["status"] as? String else { return }
        let output = notification.userInfo?["output"] as? String
        jobStatusField.stringValue = status
        outputPathField.stringValue = output ?? ""
    }
}
#endif
