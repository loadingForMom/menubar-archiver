import AppKit
import SharedCore

@MainActor
final class StatusBarController {
    private var statusItem: NSStatusItem?
    private var statusItemView: StatusItemView?
    private var finishTimer: Timer?
    private var queueInfo: (current: Int, total: Int)?

    func begin(job: Job, cancelHandler: @escaping () -> Void) {
        ensureStatusItem()
        finishTimer?.invalidate()
        statusItemView?.resetForProgress(operation: job.operation)
        statusItemView?.onCancel = cancelHandler
    }

    func updateProgress(_ progress: ArchiveWorker.Progress) {
        let percent = Int(progress.fractionComplete * 100)
        let queueSuffix: String
        if let queueInfo, queueInfo.total > 1 {
            queueSuffix = " (\(queueInfo.current) of \(queueInfo.total))"
        } else {
            queueSuffix = ""
        }
        statusItemView?.updateProgress(progress.fractionComplete, text: "\(percent)%\(queueSuffix)")
    }

    func updateQueuePosition(currentIndex: Int, total: Int) {
        queueInfo = (currentIndex, total)
    }

    func finish(result: JobResult) {
        switch result {
        case .success:
            statusItemView?.showStatusSymbol("✓", text: "Done")
        case .canceled:
            statusItemView?.showStatusSymbol("×", text: "Canceled")
        case .failure:
            statusItemView?.showStatusSymbol("!", text: "Failed")
        }

        finishTimer?.invalidate()
        finishTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.removeStatusItem()
            }
        }
    }

    func teardownIfIdle() {
        removeStatusItem()
    }

    private func ensureStatusItem() {
        if statusItem != nil { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let view = StatusItemView(frame: NSRect(x: 0, y: 0, width: 180, height: 22))
        item.button?.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        if let button = item.button {
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                view.topAnchor.constraint(equalTo: button.topAnchor),
                view.bottomAnchor.constraint(equalTo: button.bottomAnchor)
            ])
        }
        statusItem = item
        statusItemView = view
    }

    private func removeStatusItem() {
        finishTimer?.invalidate()
        finishTimer = nil
        queueInfo = nil
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
        statusItemView = nil
    }
}
