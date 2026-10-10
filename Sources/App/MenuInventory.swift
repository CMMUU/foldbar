import AppKit
import ApplicationServices

struct MenuTarget: Identifiable, Sendable {
    let id: String
    let appID: String
    let name: String
    let pid: pid_t
    let visible: Bool
}

struct MenuApp: Identifiable, Sendable {
    let id: String
    let name: String
    let path: String?
    let isSystem: Bool
    let targets: [MenuTarget]
    var itemCount: Int { targets.count }
    var editable: Bool { !isSystem }
}

struct MenuSnapshot: Sendable {
    let apps: [MenuApp]
    let visibleBundles: Set<String>
    let permitted: Bool
}

enum MenuInventory {
    private struct LiveTarget {
        let target: MenuTarget
        let appName: String
        let path: String?
        let system: Bool
        let rank: Int
        let rect: CGRect?
    }

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
        guard AXValueGetValue(p as! AXValue, .cgPoint, &position), AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: position, size: size)
    }

    private static func liveTargets(preferredDisplay: CGDirectDisplayID? = nil) -> [LiveTarget] {
        guard AXIsProcessTrusted(), let host = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.MenuBarAgent").first else { return [] }
        let root = AXUIElementCreateApplication(host.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.15)
        var screens = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        CGGetActiveDisplayList(16, &screens, &count)
        let bounds = screens.prefix(Int(count)).map(CGDisplayBounds)
        let preferred = preferredDisplay.map(CGDisplayBounds)
        var records: [String: LiveTarget] = [:]
        for window in children(root).prefix(32) {
            guard attribute(window, kAXRoleAttribute) as? String == kAXWindowRole else { continue }
            var ordinals: [String: Int] = [:]
            for group in children(window).prefix(120) {
                var owner: NSRunningApplication?
                var element = group
                var ownerElement: AXUIElement?
                var systemID: String?
                var label = ""
                for child in children(group) {
                    var pid: pid_t = 0
                    AXUIElementGetPid(child, &pid)
                    if pid != host.processIdentifier, let app = NSRunningApplication(processIdentifier: pid), app.bundleIdentifier != nil {
                        owner = app; ownerElement = child
                        label = (attribute(child, kAXDescriptionAttribute) as? String) ?? (attribute(child, kAXTitleAttribute) as? String) ?? ""
                        break
                    }
                    let candidates = [child] + children(child)
                    if let leaf = candidates.first(where: { attribute($0, kAXRoleAttribute) as? String == kAXMenuBarItemRole }),
                       let identifier = attribute(leaf, kAXIdentifierAttribute) as? String {
                        systemID = identifier; element = leaf
                        label = (attribute(leaf, kAXDescriptionAttribute) as? String) ?? identifier
                        break
                    }
                }
                guard let appID = owner?.bundleIdentifier ?? systemID.map({ "system:" + $0 }) else { continue }
                let ordinal = ordinals[appID, default: 0]
                ordinals[appID] = ordinal + 1
                let id = systemID ?? "\(appID)#\(ordinal)"
                let name: String
                switch appID {
                case "com.apple.TextInputMenuAgent": name = "输入法"
                case "com.apple.WeatherMenu", "com.apple.weather.menu": name = "天气"
                default: name = owner?.localizedName ?? label
                }
                let rect = frame(group) ?? frame(element)
                let visible = rect.map { r in
                    r.width > 0 && r.height > 0 && bounds.contains { $0.contains(CGPoint(x: r.midX, y: r.midY)) && abs(r.minY - $0.minY) < 65 }
                } ?? false
                let isPreferred = rect.map { r in preferred?.contains(CGPoint(x: r.midX, y: r.midY)) ?? false } ?? false
                let liveButton = ownerElement.map { attribute($0, kAXRoleAttribute) as? String != kAXApplicationRole } ?? false
                let rank = (visible ? 10 : 0) + (isPreferred ? 20 : 0) + (liveButton ? 5 : 0)
                let target = MenuTarget(id: id, appID: appID, name: label.isEmpty ? name : label,
                                        pid: owner?.processIdentifier ?? host.processIdentifier, visible: visible)
                let live = LiveTarget(target: target, appName: name,
                                      path: owner?.bundleURL?.path, system: systemID != nil || appID.hasPrefix("com.apple."), rank: rank, rect: rect)
                if records[id] == nil || rank > records[id]!.rank { records[id] = live }
            }
        }
        return records.values.sorted { $0.target.id < $1.target.id }
    }

    static func scan() -> MenuSnapshot {
        let targets = liveTargets()
        let grouped = Dictionary(grouping: targets, by: { $0.target.appID })
        let apps = grouped.compactMap { id, values -> MenuApp? in
            guard let first = values.first else { return nil }
            return MenuApp(id: id, name: first.appName, path: first.path, isSystem: first.system, targets: values.map(\.target))
        }.sorted { a, b in a.isSystem == b.isSystem ? a.name.localizedStandardCompare(b.name) == .orderedAscending : !a.isSystem }
        return MenuSnapshot(apps: apps, visibleBundles: Set(targets.filter { $0.target.visible }.map { $0.target.appID }), permitted: AXIsProcessTrusted())
    }

    static func position(targetID: String) -> CGRect? {
        liveTargets(preferredDisplay: CGMainDisplayID()).first { $0.target.id == targetID && $0.target.visible }?.rect
    }
    static func position(appID: String) -> CGRect? {
        liveTargets(preferredDisplay: CGMainDisplayID()).first { $0.target.appID == appID && $0.target.visible }?.rect
    }
    static func systemBoundary() -> CGFloat? {
        liveTargets(preferredDisplay: CGMainDisplayID()).filter {
            ["com.apple.menuextra.battery", "com.apple.menuextra.controlcenter", "com.apple.menuextra.clock"].contains($0.target.id)
        }.compactMap { $0.rect?.minX }.min()
    }

    static func popupWindows(pid: pid_t) -> Set<CGWindowID> {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return Set(windows.compactMap { window in
            guard let owner = window[kCGWindowOwnerPID as String] as? Int32,
                  owner != ProcessInfo.processInfo.processIdentifier,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  let dictionary = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: dictionary), rect.height > 45, rect.width > 60,
                  layer > 0 || (owner == pid && rect.width < 800 && rect.minY < 90) else { return nil }
            return window[kCGWindowNumber as String] as? CGWindowID
        })
    }

    static func hasOpenMenu(pid: pid_t) -> Bool {
        let root = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(root, 0.1)
        var budget = 70
        func inspect(_ element: AXUIElement, depth: Int) -> Bool {
            guard depth < 4, budget > 0 else { return false }
            budget -= 1
            let role = attribute(element, kAXRoleAttribute) as? String
            if role == kAXMenuRole { return !children(element).isEmpty }
            // Do not confuse the application's static menu definitions with an open menu.
            if role == kAXMenuBarRole { return false }
            return children(element).prefix(25).contains { inspect($0, depth: depth + 1) }
        }
        return inspect(root, depth: 0)
    }
}
