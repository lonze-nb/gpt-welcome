import AppKit
import ApplicationServices
import CoreGraphics
import WebKit

final class WelcomeAssistant: NSObject, NSApplicationDelegate, WKScriptMessageHandler {
    private let targetPID: pid_t
    private var window: NSWindow?

    init(targetPID: pid_t) {
        self.targetPID = targetPID
    }
    private var status: NSStatusItem?
    private var pendingPID: pid_t?
    private var activePID: pid_t?
    private var presentation = 0
    private var didFinishWriting = false
    private var isExiting = false
    private var checkingComposer = false
    private var nextAccessibilityRequest = DispatchTime.now()
    private var accessibilityResults = ""
    private var webAreas = 0
    private var inspectedElements = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Welcome"
        let menu = NSMenu()
        menu.addItem(withTitle: "在当前 GPT 窗口预览", action: #selector(preview), keyEquivalent: "").target = self
        menu.addItem(withTitle: "设置输入框检测权限", action: #selector(requestAccessibility), keyEquivalent: "").target = self
        menu.addItem(withTitle: "查看退场检测状态", action: #selector(showDetectionStatus), keyEquivalent: "").target = self
        menu.addItem(withTitle: "关闭欢迎画面", action: #selector(dismissWelcome), keyEquivalent: "").target = self
        menu.addItem(withTitle: "退出欢迎助手", action: #selector(quit), keyEquivalent: "").target = self
        item.menu = menu
        status = item

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(terminated(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(activated(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        guard let app = NSRunningApplication(processIdentifier: targetPID), !app.isTerminated else {
            NSApp.terminate(nil)
            return
        }
        pendingPID = targetPID
        findWindow(for: app, attempts: 60)
    }

    private func application(from notification: Notification) -> NSRunningApplication? {
        notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
    }

    @objc private func terminated(_ notification: Notification) {
        if application(from: notification)?.processIdentifier == targetPID {
            NSApp.terminate(nil)
        }
    }

    @objc private func activated(_ notification: Notification) {
        guard let app = application(from: notification) else { return }
        guard let activePID, let window else { return }
        if activePID == app.processIdentifier {
            window.orderFrontRegardless()
        } else {
            window.orderOut(nil)
        }
    }

    @objc private func preview() {
        guard let app = NSRunningApplication(processIdentifier: targetPID) else { return }
        app.activate()
        pendingPID = app.processIdentifier
        findWindow(for: app, attempts: 25)
    }

    @objc private func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    @objc private func dismissWelcome() {
        fadeOut(generation: presentation)
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func findWindow(for app: NSRunningApplication, attempts: Int) {
        let pid = app.processIdentifier
        guard pendingPID == pid, !app.isTerminated, attempts > 0 else { return }
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
           let target = gptWindow(pid: pid) {
            pendingPID = nil
            show(target: target, pid: pid)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.findWindow(for: app, attempts: attempts - 1)
        }
    }

    private struct GPTWindow {
        let id: CGWindowID
        let frame: CGRect
    }

    private func gptWindow(pid: pid_t, matching windowID: CGWindowID? = nil) -> GPTWindow? {
        guard let entries = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]], let primary = NSScreen.screens.first else { return nil }
        for entry in entries {
            guard entry[kCGWindowOwnerPID as String] as? Int32 == pid,
                  entry[kCGWindowLayer as String] as? Int == 0,
                  let id = entry[kCGWindowNumber as String] as? CGWindowID,
                  windowID == nil || id == windowID,
                  let dictionary = entry[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: dictionary as CFDictionary),
                  rect.width >= 400, rect.height >= 260 else { continue }
            let frame = CGRect(x: rect.minX, y: primary.frame.maxY - rect.maxY,
                               width: rect.width, height: rect.height)
            return GPTWindow(id: id, frame: frame)
        }
        return nil
    }

    private func syncFrame(pid: pid_t, windowID: CGWindowID, generation: Int) {
        guard generation == presentation, activePID == pid, let panel = window else { return }
        let target = gptWindow(pid: pid, matching: windowID) ?? gptWindow(pid: pid)
        if let target, panel.frame != target.frame {
            panel.setFrame(target.frame, display: true, animate: false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            self?.syncFrame(pid: pid, windowID: target?.id ?? windowID, generation: generation)
        }
    }

    private func greetingScript() -> WKUserScript? {
        let profile = Bundle.main.bundleURL.deletingLastPathComponent()
            .appendingPathComponent("greeting.json")
        guard let file = try? FileHandle(forReadingFrom: profile) else { return nil }
        defer { try? file.close() }
        guard let data = try? file.read(upToCount: 4097), data.count <= 4096,
              let settings = try? JSONDecoder().decode([String: String].self, from: data),
              let greeting = settings["greeting"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !greeting.isEmpty, greeting.utf8.count <= 512,
              greeting.unicodeScalars.allSatisfy({ $0.value >= 32 && !(127...159).contains($0.value) }),
              let json = try? JSONEncoder().encode(greeting),
              let literal = String(data: json, encoding: .utf8) else { return nil }
        return WKUserScript(
            source: "globalThis.welcomeGreeting = " + literal,
            injectionTime: .atDocumentStart, forMainFrameOnly: true
        )
    }

    private func show(target: GPTWindow, pid: pid_t) {
        guard let page = Bundle.main.url(forResource: "Welcome", withExtension: "html") else { return }
        hide()
        presentation += 1
        let current = presentation
        didFinishWriting = false
        isExiting = false
        checkingComposer = false
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.userContentController.add(self, name: "finished")
        if let script = greetingScript() {
            config.userContentController.addUserScript(script)
        }
        let view = WKWebView(frame: .zero, configuration: config)
        let panel = NSPanel(contentRect: target.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        view.wantsLayer = true
        view.layer?.cornerRadius = 14
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        panel.contentView = view
        panel.setFrame(target.frame, display: false)
        window = panel
        activePID = pid
        view.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        panel.orderFrontRegardless()
        syncFrame(pid: pid, windowID: target.id, generation: current)
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self, self.presentation == current, !self.didFinishWriting else { return }
            self.beginComposerCheck(pid: pid, generation: current)
        }
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let view = window?.contentView as? WKWebView,
              controller === view.configuration.userContentController else { return }
        guard !didFinishWriting, let pid = activePID else { return }
        didFinishWriting = true
        beginComposerCheck(pid: pid, generation: presentation)
    }

    private func beginComposerCheck(pid: pid_t, generation: Int) {
        guard !checkingComposer else { return }
        checkingComposer = true
        waitForComposer(pid: pid, generation: generation)
    }

    private func waitForComposer(pid: pid_t, generation: Int, readyChecks: Int = 0) {
        guard presentation == generation, activePID == pid, window != nil, !isExiting else { return }
        let nextChecks = AXIsProcessTrusted() && composerIsReady(pid: pid) ? readyChecks + 1 : 0
        if nextChecks >= 3 {
            fadeOut(generation: generation)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.waitForComposer(pid: pid, generation: generation, readyChecks: nextChecks)
        }
    }

    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    @objc private func showDetectionStatus() {
        let alert = NSAlert()
        alert.messageText = "欢迎画面退场检测"
        if !AXIsProcessTrusted() {
            alert.informativeText = "当前运行的 GPT Welcome 未获得辅助功能权限。"
        } else if composerIsReady(pid: targetPID) {
            alert.informativeText = "已识别到可用的对话输入框。"
        } else {
            alert.informativeText = inspectedElements == 0
                ? "辅助功能权限已开启，但 GPT 尚未提供窗口控件。"
                : "辅助功能权限已开启。已检查 \(inspectedElements) 个控件，其中网页区域 \(webAreas) 个。尚未识别到对话输入框。"
            alert.informativeText += "\n控件树请求：\(accessibilityResults)"
        }
        alert.runModal()
    }

    private func isComposer(_ element: AXUIElement, focused: Bool) -> Bool {
        guard let role = attribute(element, kAXRoleAttribute) as? String,
              [kAXTextAreaRole, kAXTextFieldRole, "AXComboBox"].contains(role),
              (attribute(element, kAXEnabledAttribute) as? Bool) != false else { return false }

        let labels = [kAXTitleAttribute, kAXDescriptionAttribute, kAXPlaceholderValueAttribute, kAXIdentifierAttribute, kAXHelpAttribute]
            .compactMap { attribute(element, $0) as? String }
            .joined(separator: " ").lowercased()
        guard !["search", "搜索", "搜尋", "查找"].contains(where: labels.contains) else { return false }
        let namedComposer = ["composer", "message input", "message chatgpt", "ask anything",
                             "给 chatgpt 发消息", "发送消息", "询问任何问题", "问任何问题", "输入消息", "提出任何问题", "问点什么", "发消息给", "询问 chatgpt", "ask codex", "ask chatgpt", "type a message", "chat input", "prompt input"]
            .contains(where: labels.contains)
        guard namedComposer || role == kAXTextAreaRole else { return false }

        if (attribute(element, "AXEditable") as? Bool) == true { return true }
        for name in [kAXValueAttribute, kAXSelectedTextAttribute, kAXSelectedTextRangeAttribute] {
            var settable = DarwinBoolean(false)
            if AXUIElementIsAttributeSettable(element, name as CFString, &settable) == .success,
               settable.boolValue { return true }
        }
        return (namedComposer || (focused && role == kAXTextAreaRole))
            && attribute(element, kAXSelectedTextRangeAttribute) != nil
    }

    private func composerIsReady(pid: pid_t) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.25)
        if DispatchTime.now() >= nextAccessibilityRequest {
            nextAccessibilityRequest = .now() + 2
            let manual = AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
            let enhanced = AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
            accessibilityResults = "Manual \(manual.rawValue)，Enhanced \(enhanced.rawValue)"
        }
        inspectedElements = 0
        webAreas = 0
        if let focused = attribute(app, kAXFocusedUIElementAttribute),
           CFGetTypeID(focused) == AXUIElementGetTypeID(),
           isComposer(focused as! AXUIElement, focused: true) { return true }

        let focusedWindow = attribute(app, kAXFocusedWindowAttribute) ?? attribute(app, kAXMainWindowAttribute)
        let windows = attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? []
        var queue: [AXUIElement]
        if let focusedWindow, CFGetTypeID(focusedWindow) == AXUIElementGetTypeID() {
            let focused = focusedWindow as! AXUIElement
            queue = [focused] + windows.filter { $0 != focused }.prefix(2)
        } else {
            queue = Array(windows.prefix(3))
        }
        let applicationChildren = attribute(app, kAXChildrenAttribute) as? [AXUIElement] ?? []
        var seen = Set(queue)
        for child in applicationChildren.prefix(12) {
            if (attribute(child, kAXRoleAttribute) as? String) != "AXMenuBar",
               seen.insert(child).inserted { queue.append(child) }
        }
        var visited = 0
        while visited < min(queue.count, 720) {
            let element = queue[visited]
            visited += 1
            inspectedElements = visited
            if (attribute(element, kAXRoleAttribute) as? String) == "AXWebArea" { webAreas += 1 }
            if isComposer(element, focused: false) { return true }
            guard queue.count < 720 else { continue }
            let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
            let visible = attribute(element, kAXVisibleChildrenAttribute) as? [AXUIElement] ?? []
            let contents = attribute(element, kAXContentsAttribute) as? [AXUIElement] ?? []
            let navigation = attribute(element, "AXChildrenInNavigationOrder") as? [AXUIElement] ?? []
            for child in visible + children + contents + navigation {
                if queue.count == 720 { break }
                if seen.insert(child).inserted { queue.append(child) }
            }
        }
        return false
    }

    private func fadeOut(generation: Int) {
        guard let window, !isExiting else { return }
        isExiting = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.32
            window.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self, self.presentation == generation else { return }
            self.hide()
        }
    }

    private func hide() {
        window?.orderOut(nil)
        window = nil
        activePID = nil
    }
}

final class LaunchMonitor: NSObject, NSApplicationDelegate {
    private var launchedPIDs = Set<pid_t>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(launched(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(terminated(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)

        for app in NSWorkspace.shared.runningApplications where
            app.bundleIdentifier == "com.openai.codex" || app.bundleIdentifier == "com.openai.chat" {
            startAssistant(for: app)
        }
    }

    @objc private func launched(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        startAssistant(for: app)
    }

    @objc private func terminated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        launchedPIDs.remove(app.processIdentifier)
    }

    private func startAssistant(for app: NSRunningApplication) {
        guard !app.isTerminated,
              app.bundleIdentifier == "com.openai.codex" || app.bundleIdentifier == "com.openai.chat",
              launchedPIDs.insert(app.processIdentifier).inserted else { return }
        let pid = app.processIdentifier
        let config = NSWorkspace.OpenConfiguration()
        config.arguments = ["--gpt-pid", String(pid)]
        config.activates = false
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { [weak self] _, error in
            if let error {
                NSLog("GPT Welcome could not start its display process: %@", error.localizedDescription)
                DispatchQueue.main.async { [weak self] in self?.launchedPIDs.remove(pid) }
            }
        }
    }
}

let application = NSApplication.shared
let delegate: NSApplicationDelegate
if CommandLine.arguments.count == 3,
   CommandLine.arguments[1] == "--gpt-pid",
   let pid = pid_t(CommandLine.arguments[2]), pid > 0 {
    delegate = WelcomeAssistant(targetPID: pid)
} else {
    delegate = LaunchMonitor()
}
application.setActivationPolicy(.accessory)
application.delegate = delegate
withExtendedLifetime(delegate) { application.run() }
