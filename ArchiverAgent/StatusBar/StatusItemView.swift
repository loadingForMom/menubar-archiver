import AppKit
import SharedCore

final class StatusItemView: NSView {
    private let progressIndicator = NSProgressIndicator()
    private let titleLabel = NSTextField(labelWithString: "Archiving…")
    private let cancelButton = NSButton(title: "✕", target: nil, action: nil)
    private let stackView = NSStackView()

    var onCancel: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 1
        progressIndicator.doubleValue = 0
        progressIndicator.controlSize = .small
        progressIndicator.style = .bar

        titleLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        titleLabel.lineBreakMode = .byTruncatingTail

        cancelButton.bezelStyle = .texturedRounded
        cancelButton.controlSize = .mini
        cancelButton.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        cancelButton.target = self
        cancelButton.action = #selector(cancelTapped)

        stackView.orientation = .horizontal
        stackView.spacing = 6
        stackView.alignment = .centerY
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(progressIndicator)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(cancelButton)

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            progressIndicator.widthAnchor.constraint(equalToConstant: 60)
        ])
    }

    func updateProgress(_ fraction: Double, text: String) {
        progressIndicator.doubleValue = fraction
        titleLabel.stringValue = text
    }

    func showStatusSymbol(_ symbol: String, text: String) {
        progressIndicator.isHidden = true
        cancelButton.isHidden = true
        titleLabel.stringValue = "\(symbol) \(text)"
    }

    func resetForProgress(operation: Job.Operation) {
        progressIndicator.isHidden = false
        cancelButton.isHidden = false
        titleLabel.stringValue = operation == .extract ? "Extracting…" : "Archiving…"
    }

    @objc private func cancelTapped() {
        onCancel?()
    }
}
