import AppKit
import SwiftUI
import Combine

@main
struct FoldBarApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var statusItem: NSStatusItem!
    private var fixtureItem: NSStatusItem?
    private var window: NSWindow?
    private var popover: NSPopover?
    private var subscription: AnyCancellable?
    private var fallbackPanel: NSPanel?
    private var fallbackButton: NSButton?
    private var entryTimer: Timer?
    private var entryCheckRunning = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: ["NSStatusItem Preferred Position FoldBar": 0])
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if Bundle.main.object(forInfoDictionaryKey: "FoldBarTestFixture") as? Bool != true && !CommandLine.arguments.contains("--fixture") {
            statusItem.autosaveName = "FoldBar"
        }
        if CommandLine.arguments.contains("--fixture") || Bundle.main.object(forInfoDictionaryKey: "FoldBarTestFixture") as? Bool == true {
            statusItem.button?.title = "FB✓"
            statusItem.button?.setAccessibilityLabel("FoldBar 测试图标一")
            let menu = NSMenu()
            menu.addItem(withTitle: "FoldBar 验证菜单", action: nil, keyEquivalent: "")
            menu.addItem(withTitle: "关闭验证菜单", action: #selector(fixtureAction), keyEquivalent: "").target = self
            menu.addItem(withTitle: "退出验证程序", action: #selector(quit), keyEquivalent: "").target = self
            statusItem.menu = menu
            fixtureItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            fixtureItem?.button?.title = "FB②"
            fixtureItem?.button?.setAccessibilityLabel("FoldBar 测试图标二")
            fixtureItem?.menu = menu.copy() as? NSMenu
            return
        }
        if CommandLine.arguments.contains("--smoke-test") {
            Task { let passed = await SmokeTest.run(); exit(passed ? 0 : 1) }
            return
        }
        if CommandLine.arguments.contains("--ui-test") {
            let isolated = UserDefaults(suiteName: "com.cmmuu.FoldBar.InteractionTests")!
            isolated.removePersistentDomain(forName: "com.cmmuu.FoldBar.InteractionTests")
            model = AppModel(defaults: isolated)
        } else { model = AppModel() }
        model.closeTray = { [weak self] in self?.popover?.performClose(nil) }
        model.showManager = { [weak self] in self?.showSettings() }
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusClicked(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.setAccessibilityLabel("折栏图标浮窗")
        statusItem.button?.toolTip = "折栏 · 点击打开图标浮窗 · 右键更多操作"
        subscription = model.$isCollapsed.sink { [weak self] collapsed in
            self?.statusItem.button?.image = NSImage(systemSymbolName: collapsed ? "chevron.up" : "chevron.down", accessibilityDescription: "折栏图标浮窗")
        }
        entryTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.updateFallbackEntry() }
        }
        showSettings()
    }

    private func updateFallbackEntry() async {
        guard !entryCheckRunning, model != nil else { return }
        guard model.isCollapsed else { fallbackPanel?.orderOut(nil); return }
        entryCheckRunning = true
        defer { entryCheckRunning = false }
        let id = model.ownID
        let visible = await Task.detached { MenuInventory.position(appID: id) != nil }.value
        guard model.isCollapsed else { fallbackPanel?.orderOut(nil); return }
        if visible { fallbackPanel?.orderOut(nil); return }
        if fallbackPanel == nil {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 34, height: 28), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.title = "折栏快捷入口"
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.hidesOnDeactivate = false
            panel.isFloatingPanel = true
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            let button = NSButton(frame: NSRect(x: 0, y: 0, width: 34, height: 28))
            button.image = NSImage(systemSymbolName: "chevron.up", accessibilityDescription: "折栏图标浮窗")
            button.title = ""
            button.bezelStyle = .regularSquare
            button.wantsLayer = true
            button.layer?.cornerRadius = 8
            button.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            button.setAccessibilityLabel("折栏图标浮窗")
            button.toolTip = "折栏 · 系统隐藏菜单栏入口时，在此打开图标浮窗"
            button.target = self; button.action = #selector(statusClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            panel.contentView = button
            fallbackButton = button; fallbackPanel = panel
        }
        if let screen = NSScreen.screens.first {
            let barHeight = max(24, screen.safeAreaInsets.top)
            fallbackPanel?.setFrameOrigin(NSPoint(x: screen.frame.maxX - 240, y: screen.frame.maxY - barHeight - 36))
        }
        fallbackPanel?.orderFrontRegardless()
    }

    @objc func statusClicked(_ sender: NSButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "管理全部图标…", action: #selector(showSettings), keyEquivalent: ",").target = self
            menu.addItem(withTitle: model.temporarilyExpanded ? "恢复折叠配置" : "临时展开全部", action: #selector(toggleExpanded), keyEquivalent: "").target = self
            menu.addItem(.separator())
            menu.addItem(withTitle: "退出折栏（恢复全部图标）", action: #selector(quit), keyEquivalent: "q").target = self
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.minY), in: sender)
        } else {
            if popover?.isShown == true { popover?.performClose(nil); return }
            let button = sender
            // A fresh view resets search and selection, while shared drafts stay in the model.
            let panel = NSPopover()
            panel.behavior = .transient
            panel.animates = false
            panel.contentViewController = NSHostingController(rootView: TrayView(model: model))
            popover = panel
            NSApp.activate(ignoringOtherApps: true)
            panel.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            model.refresh()
        }
    }

    @objc func showSettings() {
        popover?.performClose(nil)
        if window == nil {
            let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 790, height: 710), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            panel.title = "折栏 FoldBar · 图标管理"
            panel.contentView = NSHostingView(rootView: SettingsView(model: model))
            panel.minSize = NSSize(width: 740, height: 610)
            panel.isReleasedWhenClosed = false
            panel.center(); window = panel
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        model.refresh()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if model != nil { showSettings() }
        return true
    }
    @objc func toggleExpanded() { Task { await model.setExpanded(!model.temporarilyExpanded) } }
    @objc func fixtureAction() { print("FIXTURE action invoked") }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { entryTimer?.invalidate(); fallbackPanel?.orderOut(nil); model?.shutdown() }
}
