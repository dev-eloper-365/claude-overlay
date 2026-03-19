import AppKit
import Foundation
import Network

// MARK: - Data Models

enum PromptType: String {
    case binary = "binary"       // Approve/Deny
    case choice = "choice"       // Single select from options
    case multiSelect = "multi"   // Multiple select from options
    case textInput = "input"     // Free-form text input
}

struct PromptOption {
    let label: String
    let value: String
    let description: String?
}

struct PromptData {
    let requestId: String
    let promptType: PromptType
    let toolName: String
    let question: String
    let description: String
    let riskLevel: String
    let command: String?
    let filePath: String?
    let queueDepth: Int
    let options: [PromptOption]
    let allowOther: Bool        // Show "Other..." option with text input
    let placeholder: String?    // Placeholder for text input
}

// MARK: - JSON-RPC Socket Client

final class JsonRpcSocketClient {
    private let socketPath: String
    private var connection: NWConnection?
    private var buffer = Data()
    private(set) var isConnected = false

    var onPrompt: ((PromptData) -> Void)?

    init(socketPath: String) {
        self.socketPath = socketPath
    }

    func connect() {
        let endpoint = NWEndpoint.unix(path: socketPath)
        let parameters = NWParameters(tls: nil)
        parameters.allowLocalEndpointReuse = true
        parameters.includePeerToPeer = false

        let conn = NWConnection(to: endpoint, using: parameters)
        connection = conn

        conn.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isConnected = true
                self?.sendSubscribe()
                self?.receiveLoop()
            case .failed(let error):
                fputs("[overlay-macos] connection failed: \(error)\n", stderr)
                self?.isConnected = false
            case .cancelled:
                self?.isConnected = false
            default:
                break
            }
        }

        conn.start(queue: .global(qos: .userInitiated))
    }

    func sendDecision(requestId: String, decision: String, selectedValues: [String]? = nil, textInput: String? = nil) {
        let id = "decision_\(Int(Date().timeIntervalSince1970 * 1000))"
        var params: [String: Any] = [
            "requestId": requestId,
            "decision": decision
        ]
        if let values = selectedValues {
            params["selectedValues"] = values
        }
        if let text = textInput {
            params["textInput"] = text
        }
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "method": "overlay.decision",
            "params": params
        ]
        send(payload)
    }

    private func sendSubscribe() {
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": "sub_1",
            "method": "overlay.subscribe",
            "params": [:]
        ]
        send(payload)
    }

    private func send(_ payload: [String: Any]) {
        guard let conn = connection else { return }
        guard let json = try? JSONSerialization.data(withJSONObject: payload, options: []) else { return }

        var frame = Data(count: 4)
        let length = UInt32(json.count).bigEndian
        withUnsafeBytes(of: length) { ptr in
            frame.replaceSubrange(0..<4, with: ptr)
        }
        frame.append(json)

        conn.send(content: frame, completion: .contentProcessed { error in
            if let error {
                fputs("[overlay-macos] send error: \(error)\n", stderr)
            }
        })
    }

    private func receiveLoop() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self else { return }
            if let content, !content.isEmpty {
                self.buffer.append(content)
                self.processBuffer()
            }

            if let error {
                fputs("[overlay-macos] receive error: \(error)\n", stderr)
                return
            }

            if isComplete {
                self.isConnected = false
                return
            }

            self.receiveLoop()
        }
    }

    private func processBuffer() {
        while buffer.count >= 4 {
            let lengthBytes = buffer.prefix(4)
            let length = lengthBytes.withUnsafeBytes { ptr -> UInt32 in
                return ptr.load(as: UInt32.self).bigEndian
            }
            let frameLen = Int(length)

            if buffer.count < 4 + frameLen {
                return
            }

            let payload = buffer.subdata(in: 4..<(4 + frameLen))
            buffer.removeSubrange(0..<(4 + frameLen))
            handlePayload(payload)
        }
    }

    private func handlePayload(_ payload: Data) {
        guard
            let obj = try? JSONSerialization.jsonObject(with: payload, options: []),
            let dict = obj as? [String: Any],
            let method = dict["method"] as? String,
            method == "overlay.prompt",
            let params = dict["params"] as? [String: Any],
            let requestId = params["requestId"] as? String
        else {
            return
        }

        let promptTypeStr = params["promptType"] as? String ?? "binary"
        let promptType = PromptType(rawValue: promptTypeStr) ?? .binary

        let toolName = params["toolName"] as? String ?? "UnknownTool"
        let question = params["question"] as? String ?? "Allow \(toolName)?"
        let description = params["description"] as? String ?? "Permission request"
        let riskLevel = params["riskLevel"] as? String ?? "medium"
        let queueDepth = params["queueDepth"] as? Int ?? 0
        let allowOther = params["allowOther"] as? Bool ?? false
        let placeholder = params["placeholder"] as? String

        let paramsDict = params["parameters"] as? [String: Any]
        let command = paramsDict?["command"] as? String
        let filePath = paramsDict?["file_path"] as? String

        // Parse options
        var options: [PromptOption] = []
        if let optionsArray = params["options"] as? [[String: Any]] {
            for opt in optionsArray {
                let label = opt["label"] as? String ?? ""
                let value = opt["value"] as? String ?? label
                let desc = opt["description"] as? String
                options.append(PromptOption(label: label, value: value, description: desc))
            }
        }

        onPrompt?(PromptData(
            requestId: requestId,
            promptType: promptType,
            toolName: toolName,
            question: question,
            description: description,
            riskLevel: riskLevel,
            command: command,
            filePath: filePath,
            queueDepth: queueDepth,
            options: options,
            allowOther: allowOther,
            placeholder: placeholder
        ))
    }
}

// MARK: - Panel Subclasses

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class ClickableView: NSView {
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Overlay Panel Controller

final class OverlayPanelController: NSObject, NSTextFieldDelegate {
    private var panel: KeyablePanel!
    private var contentStack: NSStackView!
    private var container: ClickableView!

    // Common UI elements
    private let riskBadge = NSTextField(labelWithString: "")
    private let queueLabel = NSTextField(labelWithString: "")
    private let questionLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")

    // Binary mode buttons
    private let approveButton = NSButton(title: "Allow", target: nil, action: nil)
    private let denyButton = NSButton(title: "Don't Allow", target: nil, action: nil)

    // Choice/MultiSelect mode
    private var optionButtons: [NSButton] = []
    private var otherTextField: NSTextField?
    private var submitButton: NSButton?
    private var cancelButton: NSButton?

    // Text input mode
    private var inputField: NSTextField?

    // Dynamic content area
    private var dynamicContentView: NSView?

    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?
    private var currentPrompt: PromptData?
    private var onDecision: ((String, String, [String]?, String?) -> Void)?

    override init() {
        super.init()
        setupPanel()
        setupKeyHandling()
    }

    deinit {
        if let localKeyMonitor { NSEvent.removeMonitor(localKeyMonitor) }
        if let globalKeyMonitor { NSEvent.removeMonitor(globalKeyMonitor) }
    }

    private func setupPanel() {
        let rect = NSRect(x: 0, y: 0, width: 480, height: 200)
        panel = KeyablePanel(
            contentRect: rect,
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.title = "Claude Code"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true

        container = ClickableView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 14
        container.layer?.masksToBounds = true
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.97).cgColor
        container.layer?.borderColor = NSColor.separatorColor.cgColor
        container.layer?.borderWidth = 0.5
        panel.contentView = container

        setupCommonUI()
    }

    private func setupCommonUI() {
        contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 10
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        // Risk badge
        riskBadge.font = NSFont.boldSystemFont(ofSize: 10)
        riskBadge.isBezeled = false
        riskBadge.drawsBackground = true
        riskBadge.wantsLayer = true
        riskBadge.layer?.cornerRadius = 4
        riskBadge.layer?.masksToBounds = true

        // Question label
        questionLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        questionLabel.textColor = .labelColor
        questionLabel.lineBreakMode = .byWordWrapping
        questionLabel.maximumNumberOfLines = 2

        // Detail label
        detailLabel.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingMiddle
        detailLabel.maximumNumberOfLines = 2

        // Queue label
        queueLabel.font = NSFont.systemFont(ofSize: 11)
        queueLabel.textColor = .tertiaryLabelColor

        container.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            contentStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 28),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -16),
        ])
    }

    func show(prompt: PromptData, onDecision: @escaping (String, String, [String]?, String?) -> Void) {
        self.currentPrompt = prompt
        self.onDecision = onDecision

        rebuildUI(for: prompt)
        moveToTopCenterOfActiveScreen()

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
        currentPrompt = nil
    }

    private func rebuildUI(for prompt: PromptData) {
        // Clear existing content
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        optionButtons.removeAll()
        otherTextField = nil
        submitButton = nil
        cancelButton = nil
        inputField = nil
        dynamicContentView = nil

        // Header row with risk badge and queue
        let headerRow = NSStackView(views: [riskBadge, NSView(), queueLabel])
        headerRow.orientation = .horizontal
        headerRow.spacing = 8
        headerRow.distribution = .fill

        // Update risk badge
        let riskText: String
        switch prompt.riskLevel.lowercased() {
        case "low":      riskText = "LOW RISK"
        case "medium":   riskText = "MEDIUM RISK"
        case "high":     riskText = "HIGH RISK"
        case "critical": riskText = "CRITICAL"
        default:         riskText = prompt.riskLevel.uppercased()
        }
        riskBadge.stringValue = "  \(riskText)  "
        riskBadge.backgroundColor = riskColor(prompt.riskLevel).withAlphaComponent(0.15)
        riskBadge.textColor = riskColor(prompt.riskLevel)

        // Queue label
        queueLabel.stringValue = prompt.queueDepth > 0 ? "\(prompt.queueDepth) more pending" : ""

        // Question
        questionLabel.stringValue = prompt.question

        // Detail
        if let cmd = prompt.command, !cmd.isEmpty {
            detailLabel.stringValue = cmd
            detailLabel.isHidden = false
        } else if let fp = prompt.filePath, !fp.isEmpty {
            detailLabel.stringValue = fp
            detailLabel.isHidden = false
        } else if !prompt.description.isEmpty && prompt.description != "Permission request" {
            detailLabel.stringValue = prompt.description
            detailLabel.isHidden = false
        } else {
            detailLabel.isHidden = true
        }

        // Separator
        let sep = NSBox()
        sep.boxType = .separator

        contentStack.addArrangedSubview(headerRow)
        contentStack.addArrangedSubview(questionLabel)
        if !detailLabel.isHidden {
            contentStack.addArrangedSubview(detailLabel)
        }
        contentStack.addArrangedSubview(sep)

        // Width constraints for full-width rows
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        sep.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            headerRow.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            headerRow.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
            sep.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
        ])

        // Build type-specific UI
        switch prompt.promptType {
        case .binary:
            buildBinaryUI()
        case .choice:
            buildChoiceUI(prompt: prompt, multiSelect: false)
        case .multiSelect:
            buildChoiceUI(prompt: prompt, multiSelect: true)
        case .textInput:
            buildTextInputUI(prompt: prompt)
        }

        // Resize panel to fit content
        resizePanelToFit()
    }

    private func buildBinaryUI() {
        approveButton.bezelStyle = .rounded
        approveButton.controlSize = .large
        approveButton.keyEquivalent = "\r"
        approveButton.target = self
        approveButton.action = #selector(approveAction)

        denyButton.bezelStyle = .rounded
        denyButton.controlSize = .large
        denyButton.keyEquivalent = "\u{1b}"
        denyButton.target = self
        denyButton.action = #selector(denyAction)

        let buttonRow = NSStackView(views: [NSView(), denyButton, approveButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10
        buttonRow.distribution = .fill

        contentStack.addArrangedSubview(buttonRow)

        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            buttonRow.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            buttonRow.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
        ])
    }

    private func buildChoiceUI(prompt: PromptData, multiSelect: Bool) {
        let optionsStack = NSStackView()
        optionsStack.orientation = .vertical
        optionsStack.alignment = .leading
        optionsStack.spacing = 8

        for (index, option) in prompt.options.enumerated() {
            let button: NSButton
            if multiSelect {
                button = NSButton(checkboxWithTitle: option.label, target: self, action: #selector(optionToggled(_:)))
            } else {
                button = NSButton(radioButtonWithTitle: option.label, target: self, action: #selector(optionSelected(_:)))
            }
            button.tag = index
            button.font = NSFont.systemFont(ofSize: 14)

            // Add description as tooltip if available
            if let desc = option.description {
                button.toolTip = desc
            }

            optionButtons.append(button)
            optionsStack.addArrangedSubview(button)
        }

        // "Other" option with text field
        if prompt.allowOther {
            let otherRow = NSStackView()
            otherRow.orientation = .horizontal
            otherRow.spacing = 8

            let otherButton: NSButton
            if multiSelect {
                otherButton = NSButton(checkboxWithTitle: "Other:", target: self, action: #selector(otherToggled(_:)))
            } else {
                otherButton = NSButton(radioButtonWithTitle: "Other:", target: self, action: #selector(otherSelected(_:)))
            }
            otherButton.tag = -1
            otherButton.font = NSFont.systemFont(ofSize: 14)
            optionButtons.append(otherButton)

            let textField = NSTextField()
            textField.placeholderString = prompt.placeholder ?? "Enter custom value..."
            textField.font = NSFont.systemFont(ofSize: 13)
            textField.delegate = self
            textField.isEnabled = false
            otherTextField = textField

            otherRow.addArrangedSubview(otherButton)
            otherRow.addArrangedSubview(textField)

            textField.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                textField.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            ])

            optionsStack.addArrangedSubview(otherRow)
        }

        contentStack.addArrangedSubview(optionsStack)

        // Submit/Cancel buttons
        let submit = NSButton(title: "Submit", target: self, action: #selector(submitChoice))
        submit.bezelStyle = .rounded
        submit.controlSize = .large
        submit.keyEquivalent = "\r"
        submitButton = submit

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelAction))
        cancel.bezelStyle = .rounded
        cancel.controlSize = .large
        cancel.keyEquivalent = "\u{1b}"
        cancelButton = cancel

        let buttonRow = NSStackView(views: [NSView(), cancel, submit])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10
        buttonRow.distribution = .fill

        contentStack.addArrangedSubview(buttonRow)

        optionsStack.translatesAutoresizingMaskIntoConstraints = false
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            optionsStack.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            optionsStack.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
            buttonRow.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            buttonRow.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
        ])
    }

    private func buildTextInputUI(prompt: PromptData) {
        let textField = NSTextField()
        textField.placeholderString = prompt.placeholder ?? "Enter your response..."
        textField.font = NSFont.systemFont(ofSize: 14)
        textField.delegate = self
        inputField = textField

        contentStack.addArrangedSubview(textField)

        // Submit/Cancel buttons
        let submit = NSButton(title: "Submit", target: self, action: #selector(submitTextInput))
        submit.bezelStyle = .rounded
        submit.controlSize = .large
        submit.keyEquivalent = "\r"
        submitButton = submit

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelAction))
        cancel.bezelStyle = .rounded
        cancel.controlSize = .large
        cancel.keyEquivalent = "\u{1b}"
        cancelButton = cancel

        let buttonRow = NSStackView(views: [NSView(), cancel, submit])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10
        buttonRow.distribution = .fill

        contentStack.addArrangedSubview(buttonRow)

        textField.translatesAutoresizingMaskIntoConstraints = false
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
            buttonRow.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            buttonRow.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
        ])

        // Focus the text field
        DispatchQueue.main.async {
            self.panel.makeFirstResponder(textField)
        }
    }

    private func resizePanelToFit() {
        contentStack.layoutSubtreeIfNeeded()
        let contentSize = contentStack.fittingSize
        let newHeight = contentSize.height + 44 // padding
        let newWidth = max(480, contentSize.width + 40)

        var frame = panel.frame
        let heightDiff = newHeight - frame.height
        frame.size.height = newHeight
        frame.size.width = newWidth
        frame.origin.y -= heightDiff
        panel.setFrame(frame, display: true, animate: false)
    }

    private func setupKeyHandling() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isVisible, let prompt = self.currentPrompt else {
                return event
            }

            // Only handle Enter/Esc for binary mode here; other modes use button key equivalents
            if prompt.promptType == .binary {
                switch event.keyCode {
                case 36, 49: // Enter, Space
                    self.onDecision?(prompt.requestId, "approved", nil, nil)
                    self.hide()
                    return nil
                case 53: // Escape
                    self.onDecision?(prompt.requestId, "denied", nil, nil)
                    self.hide()
                    return nil
                default:
                    break
                }
            }
            return event
        }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isVisible, let prompt = self.currentPrompt else {
                return
            }

            if prompt.promptType == .binary {
                switch event.keyCode {
                case 36, 49: // Enter, Space
                    DispatchQueue.main.async {
                        self.onDecision?(prompt.requestId, "approved", nil, nil)
                        self.hide()
                    }
                case 53: // Escape
                    DispatchQueue.main.async {
                        self.onDecision?(prompt.requestId, "denied", nil, nil)
                        self.hide()
                    }
                default:
                    break
                }
            }
        }
    }

    private func moveToTopCenterOfActiveScreen() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let frame = screen?.visibleFrame else { return }

        let size = panel.frame.size
        let x = frame.origin.x + (frame.width - size.width) / 2.0
        let y = frame.origin.y + frame.height - size.height - 24
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func riskColor(_ risk: String) -> NSColor {
        switch risk.lowercased() {
        case "low":      return .systemBlue
        case "medium":   return .systemOrange
        case "high":     return .systemRed
        case "critical": return .systemPurple
        default:         return .labelColor
        }
    }

    // MARK: - Actions

    @objc private func approveAction() {
        guard let prompt = currentPrompt else { return }
        onDecision?(prompt.requestId, "approved", nil, nil)
        hide()
    }

    @objc private func denyAction() {
        guard let prompt = currentPrompt else { return }
        onDecision?(prompt.requestId, "denied", nil, nil)
        hide()
    }

    @objc private func cancelAction() {
        guard let prompt = currentPrompt else { return }
        onDecision?(prompt.requestId, "cancelled", nil, nil)
        hide()
    }

    @objc private func optionSelected(_ sender: NSButton) {
        // Deselect other radio buttons
        for button in optionButtons where button !== sender {
            button.state = .off
        }
        // Disable other text field if not selected
        if sender.tag != -1 {
            otherTextField?.isEnabled = false
        }
    }

    @objc private func optionToggled(_ sender: NSButton) {
        // Checkboxes can be toggled independently
    }

    @objc private func otherSelected(_ sender: NSButton) {
        for button in optionButtons where button !== sender {
            button.state = .off
        }
        otherTextField?.isEnabled = true
        panel.makeFirstResponder(otherTextField)
    }

    @objc private func otherToggled(_ sender: NSButton) {
        otherTextField?.isEnabled = sender.state == .on
        if sender.state == .on {
            panel.makeFirstResponder(otherTextField)
        }
    }

    @objc private func submitChoice() {
        guard let prompt = currentPrompt else { return }

        var selectedValues: [String] = []
        var textInput: String? = nil

        for (index, button) in optionButtons.enumerated() {
            if button.state == .on {
                if button.tag == -1 {
                    // "Other" option
                    textInput = otherTextField?.stringValue
                    selectedValues.append("__other__")
                } else if index < prompt.options.count {
                    selectedValues.append(prompt.options[index].value)
                }
            }
        }

        if selectedValues.isEmpty {
            // Shake the panel to indicate no selection
            shakePanel()
            return
        }

        onDecision?(prompt.requestId, "selected", selectedValues, textInput)
        hide()
    }

    @objc private func submitTextInput() {
        guard let prompt = currentPrompt else { return }
        let text = inputField?.stringValue ?? ""

        if text.isEmpty {
            shakePanel()
            return
        }

        onDecision?(prompt.requestId, "input", nil, text)
        hide()
    }

    private func shakePanel() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.4
        animation.values = [-10, 10, -8, 8, -5, 5, -2, 2, 0]
        panel.contentView?.layer?.add(animation, forKey: "shake")
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidEndEditing(_ obj: Notification) {
        // Check if editing ended due to Return key
        guard let textField = obj.object as? NSTextField,
              let userInfo = obj.userInfo,
              let movementRaw = userInfo["NSTextMovement"] as? Int,
              movementRaw == NSTextMovement.return.rawValue else {
            return
        }

        if textField === inputField {
            submitTextInput()
        } else if textField === otherTextField {
            submitChoice()
        }
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var client: JsonRpcSocketClient?
    private let panel = OverlayPanelController()
    private let autoDecision = ProcessInfo.processInfo.environment["OVERLAY_AUTO_DECISION"]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let uid = getuid()
        let socket = ProcessInfo.processInfo.environment["OVERLAY_SOCKET"] ?? "/tmp/claude-overlay-\(uid).sock"

        let client = JsonRpcSocketClient(socketPath: socket)
        self.client = client

        client.onPrompt = { [weak self] prompt in
            DispatchQueue.main.async {
                if let auto = self?.autoDecision?.lowercased(), auto == "approved" || auto == "denied" {
                    client.sendDecision(requestId: prompt.requestId, decision: auto)
                    return
                }

                self?.panel.show(prompt: prompt) { requestId, decision, selectedValues, textInput in
                    client.sendDecision(requestId: requestId, decision: decision, selectedValues: selectedValues, textInput: textInput)
                }
            }
        }

        client.connect()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
