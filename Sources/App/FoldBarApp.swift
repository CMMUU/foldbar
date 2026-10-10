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
    private var window: NSWindow?
    private var subscription: AnyCancellable?
    private var fixture = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        fixture = CommandLine.arguments.contains("--fixture")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if fixture {
            statusItem.button?.title = "FB✓"
            statusItem.button?.setAccessibilityLabel("FoldBar 测试图标")
            return
        }
        if CommandLine.arguments.contains("--smoke-test") {
            Task { await SmokeTest.run(); NSApp.terminate(nil) }
            return
        }
        model = AppModel()
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        subscription = model.$isCollapsed.sink { [weak self] collapsed in
            self?.statusItem.button?.image = NSImage(systemSymbolName: collapsed ? "chevron.left" : "chevron.down", accessibilityDescription: collapsed ? "展开菜单栏" : "收起菜单栏")
            self?.statusItem.button?.toolTip = "折栏 FoldBar · 点击展开/收起 · 右键设置"
        }
        showSettings()
    }

    @objc func statusClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "FoldBar 设置…", action: #selector(showSettings), keyEquivalent: ",").target = self
            menu.addItem(withTitle: "全部展开", action: #selector(restoreAll), keyEquivalent: "").target = self
            menu.addItem(.separator())
            menu.addItem(withTitle: "退出 FoldBar", action: #selector(quit), keyEquivalent: "q").target = self
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else if model.selected.isEmpty || !model.hasPermission {
            showSettings()
        } else { model.toggle() }
    }

    @objc func showSettings() {
        if window == nil {
            let view = NSHostingView(rootView: SettingsView(model: model))
            let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 690), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            panel.title = "折栏 FoldBar"
            panel.contentView = view
            panel.isReleasedWhenClosed = false
            panel.center()
            window = panel
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        model.refresh()
    }

    @objc func restoreAll() { model.restore() }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { model?.restore() }
}
