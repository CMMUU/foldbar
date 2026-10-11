import AppKit
import ApplicationServices
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var apps: [MenuApp] = []
    @Published private(set) var state: ManagementState
    @Published private(set) var isCollapsed = false
    @Published private(set) var temporarilyExpanded = true
    @Published private(set) var isBusy = false
    @Published private(set) var isScanning = false
    @Published private(set) var activeItem: String?
    @Published var hasPermission = AXIsProcessTrusted()
    @Published var errorMessage: String?
    @Published var notice: String?
    @Published var language: AppLanguage {
        didSet {
            Localizer.select(language)
            defaults.set(language.rawValue, forKey: "interfaceLanguage")
            notice = nil
            languageChanged?()
            refresh()
        }
    }
    var languageChanged: (() -> Void)?
    let supported = FBVisibilitySession.isSupported()
    let ownID = Bundle.main.bundleIdentifier ?? "com.cmmuu.FoldBar"
    var editableIDs: Set<String> { Set(apps.filter(\.editable).map(\.id)) }
    var unavailable: Bool { isBusy || activeItem != nil || !hasPermission || !supported }
    var canUndo: Bool { state.canUndoDraft || (!state.isDirty && state.previousApplied != nil) }
    var closeTray: (() -> Void)?
    var showManager: (() -> Void)?
    private let defaults: UserDefaults
    private let driver = VisibilityDriver()
    private var observers: [NSObjectProtocol] = []
    private var environmentTask: Task<Void, Never>?
    private var openingTask: Task<Void, Never>?
    private var shuttingDown = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let override = CommandLine.arguments.first { $0.hasPrefix("--language=") }?.components(separatedBy: "=").last
        language = AppLanguage(rawValue: override ?? defaults.string(forKey: "interfaceLanguage") ?? "system") ?? .system
        state = ManagementState(applied: Set(defaults.stringArray(forKey: "foldedApplications") ?? []))
        Localizer.select(language)
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didWakeNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.environmentChanged() }
            })
        }
        Task {
            await rescan()
            if hasPermission, supported, !state.applied.isEmpty { await setExpanded(false) }
        }
    }

    func refresh() { Task { await rescan() } }
    func rescan() async {
        guard !isScanning, !shuttingDown else { return }
        isScanning = true
        let snapshot = await Task.detached(priority: .userInitiated) { MenuInventory.scan() }.value
        hasPermission = snapshot.permitted
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        var records = Dictionary(uniqueKeysWithValues: snapshot.apps.filter { $0.id != ownID }.map { ($0.id, $0) })
        // Folded items may disappear from AX entirely. Keep the last known live app record.
        for app in apps where records[app.id] == nil && running.contains(app.id) && state.applied.contains(app.id) {
            records[app.id] = app
        }
        apps = records.values.sorted { a, b in a.isSystem == b.isSystem ? a.name.localizedStandardCompare(b.name) == .orderedAscending : !a.isSystem }
        isScanning = false
    }

    func stage(_ ids: Set<String>, folded: Bool) {
        guard !isBusy else { return }
        state.stage(ids, folded: folded, editable: editableIDs)
        notice = nil
    }
    func cancelDraft() { guard !isBusy else { return }; state.cancel(); notice = L("已取消待应用修改") }
    func applyDraft() async {
        guard !unavailable, state.isDirty else { return }
        isBusy = true; errorMessage = nil
        defer { isBusy = false }
        do {
            try await driver.apply(hidden: state.draft, ownID: ownID)
            guard !shuttingDown else { return }
            state.acceptApply(); persist()
            temporarilyExpanded = false; isCollapsed = !state.applied.isEmpty
            notice = L("配置已应用"); try? await Task.sleep(nanoseconds: 450_000_000); await rescan()
        } catch { failOpen(error) }
    }
    func undo() async {
        guard !isBusy else { return }
        if state.canUndoDraft { state.undoDraft(); notice = L("已撤销上一步修改"); return }
        guard !unavailable, !state.isDirty, let previous = state.previousApplied else { return }
        isBusy = true; errorMessage = nil
        defer { isBusy = false }
        do {
            try await driver.apply(hidden: previous, ownID: ownID)
            guard !shuttingDown else { return }
            state.acceptAppliedUndo(); persist()
            temporarilyExpanded = false; isCollapsed = !state.applied.isEmpty
            notice = L("已撤销上次应用"); try? await Task.sleep(nanoseconds: 450_000_000); await rescan()
        } catch { failOpen(error) }
    }
    func setExpanded(_ expanded: Bool) async {
        guard !isBusy, activeItem == nil, !shuttingDown else { return }
        if !expanded && (!hasPermission || !supported) { return }
        isBusy = true; errorMessage = nil
        defer { isBusy = false }
        do {
            try await driver.apply(hidden: expanded ? [] : state.applied, ownID: ownID)
            temporarilyExpanded = expanded
            isCollapsed = !expanded && !state.applied.isEmpty
            notice = expanded ? L("临时展开中，已保存的配置未改变") : L("已恢复折叠配置")
            try? await Task.sleep(nanoseconds: 450_000_000)
            await rescan()
        } catch { failOpen(error) }
    }
    func fixEntry() async {
        guard !isBusy, activeItem == nil, hasPermission else { return }
        isBusy = true
        driver.restore()
        temporarilyExpanded = true; isCollapsed = false
        let fixed = await NativeMenuAccess.fixControllerPosition(ownID: ownID)
        notice = fixed ? L("折栏入口已固定到右侧，可继续按配置折叠") : L("请展开系统的 «，按住 ⌘ 将折栏箭头拖到右侧可见区")
        isBusy = false
        await rescan()
    }
    private func persist() { defaults.set(state.applied.sorted(), forKey: "foldedApplications") }
    private func failOpen(_ error: Error) {
        driver.restore(); temporarilyExpanded = true; isCollapsed = false
        if !shuttingDown { errorMessage = L(error.localizedDescription) }
    }

    func open(_ target: MenuTarget) {
        guard !unavailable else { return }
        closeTray?()
        activeItem = target.id; errorMessage = nil; notice = nil
        openingTask = Task {
            var expandedOverflow = false
            do {
                // Native overflow contents can be suppressed by an assessment assertion.
                // Release it during the original menu interaction; saved choices stay intact.
                driver.restore()
                try await Task.sleep(nanoseconds: 450_000_000)
                let baseline = MenuInventory.popupWindows(pid: target.pid)
                let access = await NativeMenuAccess.open(target: target)
                expandedOverflow = access.expandedOverflow
                guard access.pressed else { throw menuError(L("这个图标暂时无法打开。可以先临时展开全部，再从菜单栏操作。")) }
                var observed = false
                var missingSamples = 0
                // No time limit while a menu is actually open. Only bound the initial detection period.
                for sample in 0..<18_000 {
                    try await Task.sleep(nanoseconds: 200_000_000)
                    let open = await Task.detached {
                        !MenuInventory.popupWindows(pid: target.pid).subtracting(baseline).isEmpty || MenuInventory.hasOpenMenu(pid: target.pid)
                    }.value
                    if open { observed = true; missingSamples = 0 }
                    else if observed { missingSamples += 1; if missingSamples >= 2 { break } }
                    else if sample >= 24 { throw menuError(L("未检测到可交互菜单。请临时展开全部，从原图标操作。")) }
                }
            } catch is CancellationError { }
            catch { if !shuttingDown { errorMessage = error.localizedDescription } }
            if !shuttingDown {
                await NativeMenuAccess.restoreOverflow(ifOpened: expandedOverflow)
                do { try await driver.apply(hidden: temporarilyExpanded ? [] : state.applied, ownID: ownID) }
                catch { failOpen(error) }
            }
            activeItem = nil; openingTask = nil
        }
    }
    private func menuError(_ text: String) -> NSError {
        NSError(domain: "FoldBar.Menu", code: 2, userInfo: [NSLocalizedDescriptionKey: text])
    }
    private func environmentChanged() {
        environmentTask?.cancel()
        environmentTask = Task {
            do { try await Task.sleep(nanoseconds: 700_000_000) } catch { return }
            guard !shuttingDown else { return }
            await rescan()
            if !isBusy, activeItem == nil, !temporarilyExpanded { await setExpanded(false) }
        }
    }
    func shutdown() {
        shuttingDown = true
        environmentTask?.cancel(); openingTask?.cancel(); driver.restore()
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observers.removeAll()
    }
    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}
