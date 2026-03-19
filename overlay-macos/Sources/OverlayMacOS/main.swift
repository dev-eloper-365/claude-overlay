import AppKit
import Carbon.HIToolbox
import Foundation
import Network

// MARK: - Keybind Settings

final class KeybindSettings {
    static let shared = KeybindSettings()

    private let defaults = UserDefaults.standard
    private let approveKeyKey = "approveKeyCode"
    private let denyKeyKey = "denyKeyCode"
    private let approveLabelKey = "approveKeyLabel"
    private let denyLabelKey = "denyKeyLabel"
    private let approveModifiersKey = "approveModifiers"
    private let denyModifiersKey = "denyModifiers"

    var approveKeyCode: UInt16 {
        get {
            // Use object(forKey:) to distinguish between "key not set" and "key set to 0 (A)"
            if defaults.object(forKey: approveKeyKey) != nil {
                return UInt16(defaults.integer(forKey: approveKeyKey))
            }
            return UInt16(kVK_Return)
        }
        set { defaults.set(Int(newValue), forKey: approveKeyKey); NotificationCenter.default.post(name: .keybindsChanged, object: nil) }
    }

    var denyKeyCode: UInt16 {
        get {
            if defaults.object(forKey: denyKeyKey) != nil {
                return UInt16(defaults.integer(forKey: denyKeyKey))
            }
            return UInt16(kVK_Escape)
        }
        set { defaults.set(Int(newValue), forKey: denyKeyKey); NotificationCenter.default.post(name: .keybindsChanged, object: nil) }
    }

    var approveLabel: String {
        get { defaults.string(forKey: approveLabelKey) ?? "Return ↵" }
        set { defaults.set(newValue, forKey: approveLabelKey) }
    }

    var denyLabel: String {
        get { defaults.string(forKey: denyLabelKey) ?? "Escape ⎋" }
        set { defaults.set(newValue, forKey: denyLabelKey) }
    }

    var approveModifiers: UInt {
        get { UInt(defaults.integer(forKey: approveModifiersKey)) }
        set { defaults.set(Int(newValue), forKey: approveModifiersKey); NotificationCenter.default.post(name: .keybindsChanged, object: nil) }
    }

    var denyModifiers: UInt {
        get { UInt(defaults.integer(forKey: denyModifiersKey)) }
        set { defaults.set(Int(newValue), forKey: denyModifiersKey); NotificationCenter.default.post(name: .keybindsChanged, object: nil) }
    }

    static func modifierString(for modifiers: UInt) -> String {
        var result = ""
        if modifiers & UInt(NSEvent.ModifierFlags.control.rawValue) != 0 { result += "⌃" }
        if modifiers & UInt(NSEvent.ModifierFlags.option.rawValue) != 0 { result += "⌥" }
        if modifiers & UInt(NSEvent.ModifierFlags.shift.rawValue) != 0 { result += "⇧" }
        if modifiers & UInt(NSEvent.ModifierFlags.command.rawValue) != 0 { result += "⌘" }
        return result
    }

    static func keyName(for keyCode: UInt16) -> String {
        let names: [UInt16: String] = [
            UInt16(kVK_Return): "Return ↵",
            UInt16(kVK_Escape): "Escape ⎋",
            UInt16(kVK_Space): "Space ␣",
            UInt16(kVK_Tab): "Tab ⇥",
            UInt16(kVK_Delete): "Delete ⌫",
            UInt16(kVK_ANSI_A): "A", UInt16(kVK_ANSI_B): "B", UInt16(kVK_ANSI_C): "C",
            UInt16(kVK_ANSI_D): "D", UInt16(kVK_ANSI_E): "E", UInt16(kVK_ANSI_F): "F",
            UInt16(kVK_ANSI_G): "G", UInt16(kVK_ANSI_H): "H", UInt16(kVK_ANSI_I): "I",
            UInt16(kVK_ANSI_J): "J", UInt16(kVK_ANSI_K): "K", UInt16(kVK_ANSI_L): "L",
            UInt16(kVK_ANSI_M): "M", UInt16(kVK_ANSI_N): "N", UInt16(kVK_ANSI_O): "O",
            UInt16(kVK_ANSI_P): "P", UInt16(kVK_ANSI_Q): "Q", UInt16(kVK_ANSI_R): "R",
            UInt16(kVK_ANSI_S): "S", UInt16(kVK_ANSI_T): "T", UInt16(kVK_ANSI_U): "U",
            UInt16(kVK_ANSI_V): "V", UInt16(kVK_ANSI_W): "W", UInt16(kVK_ANSI_X): "X",
            UInt16(kVK_ANSI_Y): "Y", UInt16(kVK_ANSI_Z): "Z",
            UInt16(kVK_ANSI_1): "1", UInt16(kVK_ANSI_2): "2", UInt16(kVK_ANSI_3): "3",
            UInt16(kVK_ANSI_4): "4", UInt16(kVK_ANSI_5): "5", UInt16(kVK_ANSI_6): "6",
            UInt16(kVK_ANSI_7): "7", UInt16(kVK_ANSI_8): "8", UInt16(kVK_ANSI_9): "9",
            UInt16(kVK_ANSI_0): "0",
            UInt16(kVK_F1): "F1", UInt16(kVK_F2): "F2", UInt16(kVK_F3): "F3",
            UInt16(kVK_F4): "F4", UInt16(kVK_F5): "F5", UInt16(kVK_F6): "F6",
        ]
        return names[keyCode] ?? "Key \(keyCode)"
    }

    static func keyName(for keyCode: UInt16, modifiers: UInt) -> String {
        let modStr = modifierString(for: modifiers)
        let keyStr = keyName(for: keyCode)
        return modStr.isEmpty ? keyStr : "\(modStr) + \(keyStr)"
    }

    /// Returns the NSButton keyEquivalent string for a key code.
    /// For special keys (F-keys, etc), returns empty string since they can't be keyEquivalents.
    static func keyEquivalent(for keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_Return: return "\r"
        case kVK_Escape: return "\u{1b}"
        case kVK_Space: return " "
        case kVK_Tab: return "\t"
        case kVK_Delete: return "\u{7f}"
        case kVK_ANSI_A: return "a"
        case kVK_ANSI_B: return "b"
        case kVK_ANSI_C: return "c"
        case kVK_ANSI_D: return "d"
        case kVK_ANSI_E: return "e"
        case kVK_ANSI_F: return "f"
        case kVK_ANSI_G: return "g"
        case kVK_ANSI_H: return "h"
        case kVK_ANSI_I: return "i"
        case kVK_ANSI_J: return "j"
        case kVK_ANSI_K: return "k"
        case kVK_ANSI_L: return "l"
        case kVK_ANSI_M: return "m"
        case kVK_ANSI_N: return "n"
        case kVK_ANSI_O: return "o"
        case kVK_ANSI_P: return "p"
        case kVK_ANSI_Q: return "q"
        case kVK_ANSI_R: return "r"
        case kVK_ANSI_S: return "s"
        case kVK_ANSI_T: return "t"
        case kVK_ANSI_U: return "u"
        case kVK_ANSI_V: return "v"
        case kVK_ANSI_W: return "w"
        case kVK_ANSI_X: return "x"
        case kVK_ANSI_Y: return "y"
        case kVK_ANSI_Z: return "z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        default: return "" // F-keys and others don't have simple keyEquivalents
        }
    }

    /// Returns a short label for a key (without symbols), suitable for button titles
    static func shortLabel(for keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_Return: return "Return"
        case kVK_Escape: return "Esc"
        case kVK_Space: return "Space"
        case kVK_Tab: return "Tab"
        case kVK_Delete: return "Delete"
        default:
            let name = keyName(for: keyCode)
            // Strip any symbols at the end
            return name.components(separatedBy: " ").first ?? name
        }
    }

    static func shortLabel(for keyCode: UInt16, modifiers: UInt) -> String {
        let modStr = modifierString(for: modifiers)
        let keyStr = shortLabel(for: keyCode)
        return modStr.isEmpty ? keyStr : "\(modStr) + \(keyStr)"
    }
}

extension Notification.Name {
    static let keybindsChanged = Notification.Name("keybindsChanged")
}

// MARK: - Menu Bar Controller

final class MenuBarController {
    /// Shared state to indicate if the settings window is capturing a key
    static var isCapturingKey = false

    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var approveField: NSTextField?
    private var denyField: NSTextField?
    private var capturingField: String? // "approve" or "deny"
    private var keyMonitor: Any?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "shield.checkered", accessibilityDescription: "Claude Overlay")
                ?? NSImage(named: NSImage.lockLockedTemplateName)
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
        }
        rebuildMenu()
        NotificationCenter.default.addObserver(forName: .keybindsChanged, object: nil, queue: .main) { [weak self] _ in
            self?.rebuildMenu()
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let settings = KeybindSettings.shared

        let header = NSMenuItem(title: "Claude Overlay", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(NSMenuItem.separator())

        let allow = NSMenuItem(title: "Allow:  \(settings.approveLabel)", action: nil, keyEquivalent: "")
        allow.isEnabled = false
        menu.addItem(allow)

        let deny = NSMenuItem(title: "Deny:   \(settings.denyLabel)", action: nil, keyEquivalent: "")
        deny.isEnabled = false
        menu.addItem(deny)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Shortcuts…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func openSettings() {
        if let w = settingsWindow, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settings = KeybindSettings.shared
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 180),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "Shortcut Settings"
        w.center()
        w.isReleasedWhenClosed = false

        let container = NSView(frame: w.contentView!.bounds)
        container.autoresizingMask = [.width, .height]
        w.contentView = container

        // Allow shortcut
        let approveTitle = NSTextField(labelWithString: "Allow:")
        approveTitle.font = .systemFont(ofSize: 13, weight: .medium)
        approveTitle.frame = NSRect(x: 20, y: 130, width: 80, height: 20)
        container.addSubview(approveTitle)

        let approveBtn = makeKeyButton(label: settings.approveLabel, x: 110, y: 125)
        approveBtn.target = self
        approveBtn.action = #selector(captureApproveKey)
        approveField = approveBtn
        container.addSubview(approveBtn)

        // Deny shortcut
        let denyTitle = NSTextField(labelWithString: "Deny:")
        denyTitle.font = .systemFont(ofSize: 13, weight: .medium)
        denyTitle.frame = NSRect(x: 20, y: 90, width: 80, height: 20)
        container.addSubview(denyTitle)

        let denyBtn = makeKeyButton(label: settings.denyLabel, x: 110, y: 85)
        denyBtn.target = self
        denyBtn.action = #selector(captureDenyKey)
        denyField = denyBtn
        container.addSubview(denyBtn)

        // Reset button
        let resetBtn = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetDefaults))
        resetBtn.bezelStyle = .rounded
        resetBtn.frame = NSRect(x: 20, y: 20, width: 140, height: 30)
        container.addSubview(resetBtn)

        // Hint
        let hint = NSTextField(labelWithString: "Click a field, then press any key")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 20, y: 55, width: 280, height: 16)
        container.addSubview(hint)

        // Clean up capture state when window closes
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: w,
            queue: .main
        ) { [weak self] _ in
            self?.cleanupCapture()
        }

        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = w
    }

    private func cleanupCapture() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        capturingField = nil
        MenuBarController.isCapturingKey = false
    }

    private func makeKeyButton(label: String, x: CGFloat, y: CGFloat) -> NSTextField {
        let field = NSTextField(string: label)
        field.isEditable = false
        field.isBordered = true
        field.isSelectable = false
        field.bezelStyle = .roundedBezel
        field.alignment = .center
        field.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
        field.frame = NSRect(x: x, y: y, width: 180, height: 30)
        field.focusRingType = .exterior

        let click = NSClickGestureRecognizer(target: self, action: #selector(fieldClicked(_:)))
        field.addGestureRecognizer(click)
        return field
    }

    @objc private func fieldClicked(_ sender: NSClickGestureRecognizer) {
        guard let field = sender.view as? NSTextField else { return }
        if field === approveField {
            startCapture(for: "approve")
        } else if field === denyField {
            startCapture(for: "deny")
        }
    }

    @objc private func captureApproveKey() { startCapture(for: "approve") }
    @objc private func captureDenyKey() { startCapture(for: "deny") }

    private func startCapture(for field: String) {
        capturingField = field
        MenuBarController.isCapturingKey = true
        let target = field == "approve" ? approveField : denyField
        target?.stringValue = "Press a key…"
        target?.textColor = .systemBlue

        // Remove old monitor
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleCapturedKey(event)
            return nil // swallow the event
        }
    }

    private func handleCapturedKey(_ event: NSEvent) {
        guard let field = capturingField else { return }
        let code = event.keyCode
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift]).rawValue
        let name = KeybindSettings.keyName(for: code, modifiers: UInt(modifiers))
        let settings = KeybindSettings.shared

        // Prevent assigning the same key+modifiers to both Allow and Deny
        if field == "approve" && code == settings.denyKeyCode && modifiers == settings.denyModifiers {
            shakeField(approveField)
            return
        } else if field == "deny" && code == settings.approveKeyCode && modifiers == settings.approveModifiers {
            shakeField(denyField)
            return
        }

        if field == "approve" {
            settings.approveKeyCode = code
            settings.approveModifiers = UInt(modifiers)
            settings.approveLabel = name
            approveField?.stringValue = name
            approveField?.textColor = .labelColor
        } else {
            settings.denyKeyCode = code
            settings.denyModifiers = UInt(modifiers)
            settings.denyLabel = name
            denyField?.stringValue = name
            denyField?.textColor = .labelColor
        }

        capturingField = nil
        MenuBarController.isCapturingKey = false
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }

    private func shakeField(_ field: NSTextField?) {
        guard let field = field else { return }
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.4
        animation.values = [-8, 8, -6, 6, -4, 4, -2, 2, 0]
        field.layer?.add(animation, forKey: "shake")
        field.stringValue = "Already in use!"
        field.textColor = .systemRed

        // Reset after a moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, self.capturingField != nil else { return }
            field.stringValue = "Press a key…"
            field.textColor = .systemBlue
        }
    }

    @objc private func resetDefaults() {
        let settings = KeybindSettings.shared
        settings.approveKeyCode = UInt16(kVK_Return)
        settings.approveModifiers = 0
        settings.approveLabel = "Return ↵"
        settings.denyKeyCode = UInt16(kVK_Escape)
        settings.denyModifiers = 0
        settings.denyLabel = "Escape ⎋"
        approveField?.stringValue = settings.approveLabel
        denyField?.stringValue = settings.denyLabel
        approveField?.textColor = .labelColor
        denyField?.textColor = .labelColor
    }
}

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
    private var keybindObserver: Any?
    private var currentPrompt: PromptData?
    private var onDecision: ((String, String, [String]?, String?) -> Void)?

    /// Time when the overlay was shown - used for grace period
    private var showTime: Date?
    /// Grace period in seconds before accepting keyboard shortcuts (prevents accidental triggers while typing)
    private let gracePeriod: TimeInterval = 0.4

    override init() {
        super.init()
        setupPanel()
        setupKeyHandling()

        // Listen for keybind changes to update button titles
        keybindObserver = NotificationCenter.default.addObserver(
            forName: .keybindsChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.updateButtonKeyEquivalents()
        }
    }

    deinit {
        if let localKeyMonitor { NSEvent.removeMonitor(localKeyMonitor) }
        if let globalKeyMonitor { NSEvent.removeMonitor(globalKeyMonitor) }
        if let keybindObserver { NotificationCenter.default.removeObserver(keybindObserver) }
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
        detailLabel.lineBreakMode = .byCharWrapping
        detailLabel.maximumNumberOfLines = 6
        detailLabel.preferredMaxLayoutWidth = 440
        detailLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

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
        self.showTime = Date()  // Start grace period

        rebuildUI(for: prompt)
        moveToTopCenterOfActiveScreen()

        // Show the panel on top of everything WITHOUT stealing focus
        // The global key monitor will handle shortcuts even when not focused
        panel.orderFront(nil)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
        currentPrompt = nil
        showTime = nil
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
        let settings = KeybindSettings.shared

        approveButton.bezelStyle = .rounded
        approveButton.controlSize = .large
        approveButton.title = "Allow (\(KeybindSettings.shortLabel(for: settings.approveKeyCode, modifiers: settings.approveModifiers)))"
        approveButton.keyEquivalent = KeybindSettings.keyEquivalent(for: settings.approveKeyCode)
        approveButton.target = self
        approveButton.action = #selector(approveAction)

        denyButton.bezelStyle = .rounded
        denyButton.controlSize = .large
        denyButton.title = "Don't Allow (\(KeybindSettings.shortLabel(for: settings.denyKeyCode, modifiers: settings.denyModifiers)))"
        denyButton.keyEquivalent = KeybindSettings.keyEquivalent(for: settings.denyKeyCode)
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
        let newWidth = min(600, max(480, contentSize.width + 40))

        var frame = panel.frame
        let heightDiff = newHeight - frame.height
        frame.size.height = newHeight
        frame.size.width = newWidth
        frame.origin.y -= heightDiff
        panel.setFrame(frame, display: true, animate: false)
    }

    private func setupKeyHandling() {
        let settings = KeybindSettings.shared

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isVisible, let prompt = self.currentPrompt else {
                return event
            }

            // Don't process if settings window is capturing a key
            if MenuBarController.isCapturingKey {
                return event
            }

            // Grace period: ignore keys for a short time after overlay appears
            if let showTime = self.showTime, Date().timeIntervalSince(showTime) < self.gracePeriod {
                return event
            }

            if prompt.promptType == .binary {
                let code = event.keyCode
                let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift]).rawValue
                if code == settings.approveKeyCode && UInt(modifiers) == settings.approveModifiers {
                    self.onDecision?(prompt.requestId, "approved", nil, nil)
                    self.hide()
                    return nil
                } else if code == settings.denyKeyCode && UInt(modifiers) == settings.denyModifiers {
                    self.onDecision?(prompt.requestId, "denied", nil, nil)
                    self.hide()
                    return nil
                }
            }
            return event
        }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isVisible, let prompt = self.currentPrompt else {
                return
            }

            // Don't process if settings window is capturing a key
            if MenuBarController.isCapturingKey {
                return
            }

            // Grace period: ignore keys for a short time after overlay appears
            // This prevents accidental triggers when the user is typing in another app
            if let showTime = self.showTime, Date().timeIntervalSince(showTime) < self.gracePeriod {
                return
            }

            if prompt.promptType == .binary {
                let code = event.keyCode
                let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift]).rawValue
                if code == settings.approveKeyCode && UInt(modifiers) == settings.approveModifiers {
                    DispatchQueue.main.async {
                        self.onDecision?(prompt.requestId, "approved", nil, nil)
                        self.hide()
                    }
                } else if code == settings.denyKeyCode && UInt(modifiers) == settings.denyModifiers {
                    DispatchQueue.main.async {
                        self.onDecision?(prompt.requestId, "denied", nil, nil)
                        self.hide()
                    }
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

    private func updateButtonKeyEquivalents() {
        let settings = KeybindSettings.shared
        approveButton.title = "Allow (\(KeybindSettings.shortLabel(for: settings.approveKeyCode, modifiers: settings.approveModifiers)))"
        approveButton.keyEquivalent = KeybindSettings.keyEquivalent(for: settings.approveKeyCode)
        denyButton.title = "Don't Allow (\(KeybindSettings.shortLabel(for: settings.denyKeyCode, modifiers: settings.denyModifiers)))"
        denyButton.keyEquivalent = KeybindSettings.keyEquivalent(for: settings.denyKeyCode)
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
    private var menuBar: MenuBarController?
    private let autoDecision = ProcessInfo.processInfo.environment["OVERLAY_AUTO_DECISION"]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBar = MenuBarController()

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
