import AppKit
import ApplicationServices

struct MenuApp: Identifiable, Sendable {
    let id: String
    let name: String
    let path: String?
    let itemCount: Int
}

struct MenuSnapshot: Sendable {
    let apps: [MenuApp]
    let visibleBundles: Set<String>
    let permitted: Bool
}

enum MenuInventory {
    static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    static func children(_ element: AXUIElement) -> [AXUIElement] {
        attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }

    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let p = attribute(element, kAXPositionAttribute), let s = attribute(element, kAXSizeAttribute),
              CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &position),
              AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: position, size: size)
    }

    static func scan() -> MenuSnapshot {
        guard AXIsProcessTrusted() else { return MenuSnapshot(apps: [], visibleBundles: [], permitted: false) }
        guard let host = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.MenuBarAgent").first else {
            return MenuSnapshot(apps: [], visibleBundles: [], permitted: true)
        }
        let root = AXUIElementCreateApplication(host.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.15)
        var screens = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        CGGetActiveDisplayList(16, &screens, &count)
        let bounds = screens.prefix(Int(count)).map(CGDisplayBounds)
        var records: [String: MenuApp] = [:]
        var visible = Set<String>()
        var budget = 1600

        func owners(_ element: AXUIElement, depth: Int, into ids: inout Set<pid_t>) {
            guard depth < 5, budget > 0 else { return }
            budget -= 1
            var pid: pid_t = 0
            if AXUIElementGetPid(element, &pid) == .success, pid > 0, pid != host.processIdentifier {
                ids.insert(pid)
                return
            }
            for child in children(element) { owners(child, depth: depth + 1, into: &ids) }
        }

        for window in children(root) {
            guard attribute(window, kAXRoleAttribute) as? String == kAXWindowRole else { continue }
            for group in children(window) {
                var pids = Set<pid_t>()
                owners(group, depth: 0, into: &pids)
                let rect = frame(group)
                let isVisible = rect.map { r in
                    r.width > 0 && r.height > 0 && bounds.contains { display in
                        r.intersects(display) && abs(r.minY - display.minY) < 65
                    }
                } ?? false
                for pid in pids {
                    guard let app = NSRunningApplication(processIdentifier: pid), let id = app.bundleIdentifier else { continue }
                    if isVisible { visible.insert(id) }
                    let oldCount = records[id]?.itemCount ?? 0
                    records[id] = MenuApp(id: id, name: app.localizedName ?? id, path: app.bundleURL?.path, itemCount: oldCount + 1)
                }
            }
        }
        return MenuSnapshot(apps: records.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }, visibleBundles: visible, permitted: true)
    }
}
