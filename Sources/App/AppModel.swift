import AppKit
import ApplicationServices
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var apps: [MenuApp] = []
    @Published var selected: Set<String>
    @Published var isCollapsed = false
    @Published var isBusy = false
    @Published var isScanning = false
    @Published var hasPermission = AXIsProcessTrusted()
    @Published var errorMessage: String?
    let supported = FBVisibilitySession.isSupported()
    let ownID = Bundle.main.bundleIdentifier ?? "com.cmmuu.FoldBar"
    private var session: FBVisibilitySession?
    private var revision = 0
    private var observers: [NSObjectProtocol] = []

    init() {
        selected = Set(UserDefaults.standard.stringArray(forKey: "foldedApplications") ?? [])
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didWakeNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    if self.isCollapsed || self.isBusy {
                        // Fail open on an environment change; never hide a newly launched app unexpectedly.
                        self.restore()
                    }
                    self.refresh()
                }
            })
        }
        refresh()
    }

    func refresh() {
        guard !isScanning else { return }
        isScanning = true
        Task {
            let snapshot = await Task.detached(priority: .userInitiated) { MenuInventory.scan() }.value
            hasPermission = snapshot.permitted
            if !isCollapsed && !isBusy {
                apps = snapshot.apps.filter { !$0.id.hasPrefix("com.apple.") && $0.id != ownID }
            }
            isScanning = false
        }
    }

    func setSelected(_ appID: String, value: Bool) {
        restore()
        if value { selected.insert(appID) } else { selected.remove(appID) }
        UserDefaults.standard.set(selected.sorted(), forKey: "foldedApplications")
    }

    func toggle() {
        if isCollapsed || isBusy { restore() } else { collapse() }
    }

    func collapse() {
        guard supported, hasPermission, !isBusy else { return }
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let plan = VisibilityPlan(selected: selected, running: running, ownBundle: ownID)
        guard !plan.hidden.isEmpty else {
            errorMessage = "先在列表中选择至少一个要收起的应用。"
            return
        }
        revision += 1
        let current = revision
        errorMessage = nil
        isBusy = true
        let next = FBVisibilitySession()
        session = next
        next.beginAllowingBundles(plan.allowed) { [weak self] error in
            Task { @MainActor in
                guard let self, self.revision == current else { return }
                self.isBusy = false
                if let error {
                    self.restore()
                    self.errorMessage = error.localizedDescription
                } else {
                    self.isCollapsed = true
                }
            }
        }
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard revision == current, isBusy else { return }
            restore()
            errorMessage = "系统没有及时响应，已恢复展开。请重试。"
        }
    }

    func restore() {
        revision += 1
        session?.restore()
        session = nil
        isCollapsed = false
        isBusy = false
    }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}
