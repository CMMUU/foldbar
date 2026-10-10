import AppKit

enum SmokeTest {
    @MainActor static func run() async -> Bool {
        let fixtureID = "com.cmmuu.FoldBar.Fixture"
        let before = await Task.detached { MenuInventory.scan() }.value
        print("SMOKE supported=\(FBVisibilitySession.isSupported()) permission=\(before.permitted) discovered=\(before.apps.count) visible=\(before.visibleBundles.count)")
        guard before.permitted, before.visibleBundles.contains(fixtureID) else {
            print("SMOKE FAIL: visible fixture or Accessibility permission missing")
            return false
        }
        let session = FBVisibilitySession()
        defer { session.restore() }
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let plan = VisibilityPlan(selected: [fixtureID], running: running, ownBundle: "com.cmmuu.FoldBar")
        let error: Error? = await withCheckedContinuation { continuation in
            session.beginAllowingBundles(plan.allowed) { continuation.resume(returning: $0) }
        }
        if let error { print("SMOKE FAIL: \(error)"); return false }
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        let collapsed = await Task.detached { MenuInventory.scan() }.value
        session.restore()
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        let restored = await Task.detached { MenuInventory.scan() }.value
        let hidden = !collapsed.visibleBundles.contains(fixtureID)
        let back = restored.visibleBundles.contains(fixtureID)
        let otherMissing = before.visibleBundles.subtracting([fixtureID, "com.cmmuu.FoldBar"]).subtracting(collapsed.visibleBundles)
        print("SMOKE fixtureHidden=\(hidden) fixtureRestored=\(back) otherBundlesMissing=\(otherMissing.sorted())")
        print("SMOKE controllerNativeVisible=\(collapsed.visibleBundles.contains("com.cmmuu.FoldBar")) (independent fallback entry verified separately in UI)")
        let passed = hidden && back && otherMissing.isEmpty
        print(passed ? "SMOKE PASS" : "SMOKE FAIL")
        return passed
    }
}
