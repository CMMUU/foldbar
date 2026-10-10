import AppKit
import ApplicationServices

// User-initiated menu access. Events are limited to verified menu-bar geometry.
// No global input listener or screen capture is used.
@MainActor
enum NativeMenuAccess {
    private static let overflowShow: Set<String> = {
        var labels: Set<String> = ["Show Hidden Menu Bar Items", "显示隐藏菜单栏项目"]
        let url = URL(fileURLWithPath: "/System/Library/CoreServices/MenuBarAgent.app/Contents/Resources/MenuBarCore.loctable")
        if let data = try? Data(contentsOf: url), let root = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            for value in root.values {
                if let strings = value as? [String: Any], let label = strings["menuBar.showOverflowItemsAccessibilityLabel"] as? String { labels.insert(label) }
            }
        }
        return labels
    }()
    private static var agent: AXUIElement? {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.MenuBarAgent").first.map { AXUIElementCreateApplication($0.processIdentifier) }
    }
    static func expandOverflowIfNeeded() async -> Bool {
        guard let agent else { return false }
        let display = CGDisplayBounds(CGMainDisplayID())
        for x in stride(from: display.midX, to: display.maxX - 140, by: 8) {
            var hit: AXUIElement?
            guard AXUIElementCopyElementAtPosition(agent, Float(x), Float(display.minY + 15), &hit) == .success,
                  let hit, let label = MenuInventory.attribute(hit, kAXDescriptionAttribute) as? String,
                  overflowShow.contains(label), let rect = MenuInventory.frame(hit) else { continue }
            await click(at: CGPoint(x: rect.midX, y: rect.midY))
            try? await Task.sleep(nanoseconds: 450_000_000)
            return true
        }
        return false
    }
    static func restoreOverflow(ifOpened: Bool) async {
        guard ifOpened, let agent else { return }
        var labels: Set<String> = ["Hide Menu Bar Items", "隐藏菜单栏项目"]
        let url = URL(fileURLWithPath: "/System/Library/CoreServices/MenuBarAgent.app/Contents/Resources/MenuBarCore.loctable")
        if let data = try? Data(contentsOf: url), let root = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            for value in root.values {
                if let strings = value as? [String: Any], let label = strings["menuBar.hideOverflowItemsAccessibilityLabel"] as? String { labels.insert(label) }
            }
        }
        let display = CGDisplayBounds(CGMainDisplayID())
        for x in stride(from: display.midX, to: display.maxX - 140, by: 8) {
            var hit: AXUIElement?
            guard AXUIElementCopyElementAtPosition(agent, Float(x), Float(display.minY + 15), &hit) == .success,
                  let hit, let label = MenuInventory.attribute(hit, kAXDescriptionAttribute) as? String,
                  labels.contains(label), let rect = MenuInventory.frame(hit) else { continue }
            await click(at: CGPoint(x: rect.midX, y: rect.midY))
            try? await Task.sleep(nanoseconds: 300_000_000)
            return
        }
    }
    static func fixControllerPosition(ownID: String) async -> Bool {
        guard AXIsProcessTrusted(), CGEventSource.flagsState(.hidSystemState).intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]).isEmpty else { return false }
        _ = await expandOverflowIfNeeded()
        guard let start = await Task.detached(operation: { MenuInventory.position(appID: ownID) }).value,
              let boundary = await Task.detached(operation: { MenuInventory.systemBoundary() }).value else { return false }
        let display = CGDisplayBounds(CGMainDisplayID())
        if start.midX > display.midX + 120 { return true }
        let end = CGPoint(x: boundary - 12, y: start.midY)
        let origin = CGPoint(x: start.midX, y: start.midY)
        let pointer = CGEvent(source: nil)?.location
        let source = CGEventSource(stateID: .hidSystemState)
        func event(_ type: CGEventType, _ point: CGPoint) {
            let e = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
            e?.flags = .maskCommand; e?.post(tap: .cghidEventTap)
        }
        CGWarpMouseCursorPosition(origin)
        event(.leftMouseDown, origin)
        try? await Task.sleep(nanoseconds: 150_000_000)
        // Finish the mouse-up even if the enclosing operation was cancelled.
        for step in 1...16 {
            try? await Task.sleep(nanoseconds: 35_000_000)
            let t = CGFloat(step) / 16
            event(.leftMouseDragged, CGPoint(x: origin.x + (end.x - origin.x) * t, y: origin.y + (end.y - origin.y) * t))
        }
        event(.leftMouseUp, end)
        let release = CGEvent(keyboardEventSource: source, virtualKey: 55, keyDown: false)
        release?.flags = []; release?.post(tap: .cghidEventTap)
        try? await Task.sleep(nanoseconds: 100_000_000)
        restorePointer(pointer, ifStillNear: end)
        try? await Task.sleep(nanoseconds: 500_000_000)
        return await Task.detached { MenuInventory.position(appID: ownID).map { $0.midX > display.midX + 120 } ?? false }.value
    }
    static func open(target: MenuTarget) async -> (pressed: Bool, expandedOverflow: Bool) {
        let expanded = await expandOverflowIfNeeded()
        var previous: CGRect?
        for _ in 0..<10 {
            guard let rect = await Task.detached(operation: { MenuInventory.position(targetID: target.id) }).value else {
                try? await Task.sleep(nanoseconds: 150_000_000); continue
            }
            if let previous, abs(previous.midX - rect.midX) < 1, abs(previous.midY - rect.midY) < 1 {
                let point = CGPoint(x: rect.midX, y: rect.midY)
                guard let agent else { return (false, expanded) }
                var hit: AXUIElement?
                guard AXUIElementCopyElementAtPosition(agent, Float(point.x), Float(point.y), &hit) == .success, let hit else { return (false, expanded) }
                var pid: pid_t = 0; AXUIElementGetPid(hit, &pid)
                // Do not click a neighbouring icon or a phantom overflow frame.
                if pid != target.pid {
                    let matches = MenuInventory.children(hit).contains { child in
                        var owner: pid_t = 0; AXUIElementGetPid(child, &owner); return owner == target.pid
                    }
                    guard matches else { return (false, expanded) }
                }
                await click(at: point); return (true, expanded)
            }
            previous = rect
            try? await Task.sleep(nanoseconds: 120_000_000)
        }
        return (false, expanded)
    }
    private static func click(at point: CGPoint) async {
        let pointer = CGEvent(source: nil)?.location
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        down?.flags = []; up?.flags = []
        CGWarpMouseCursorPosition(point)
        down?.post(tap: .cghidEventTap)
        try? await Task.sleep(nanoseconds: 70_000_000)
        up?.post(tap: .cghidEventTap)
        try? await Task.sleep(nanoseconds: 70_000_000)
        restorePointer(pointer, ifStillNear: point)
    }
    private static func restorePointer(_ pointer: CGPoint?, ifStillNear target: CGPoint) {
        guard let pointer, let current = CGEvent(source: nil)?.location,
              hypot(current.x - target.x, current.y - target.y) < 4 else { return }
        CGWarpMouseCursorPosition(pointer)
    }
}
