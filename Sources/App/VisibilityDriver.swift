import AppKit

@MainActor
final class VisibilityDriver {
    private var session: FBVisibilitySession?
    private var pending: CheckedContinuation<Void, Error>?
    private var generation = 0
    private var timeout: Task<Void, Never>?

    func restore() {
        generation += 1
        timeout?.cancel(); timeout = nil
        session?.restore(); session = nil
        let continuation = pending; pending = nil
        continuation?.resume(throwing: CancellationError())
    }

    func apply(hidden: Set<String>, ownID: String) async throws {
        restore()
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let plan = VisibilityPlan(selected: hidden, running: running, ownBundle: ownID)
        guard !plan.hidden.isEmpty else { return }
        let current = generation
        let next = FBVisibilitySession()
        session = next
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            pending = continuation
            next.beginAllowingBundles(plan.allowed) { [weak self] error in
                Task { @MainActor in
                    guard let self, self.generation == current, let pending = self.pending else { return }
                    self.pending = nil
                    self.timeout?.cancel(); self.timeout = nil
                    if let error {
                        self.session?.restore(); self.session = nil
                        pending.resume(throwing: error)
                    } else { pending.resume() }
                }
            }
            timeout = Task { [weak self] in
                do { try await Task.sleep(nanoseconds: 4_000_000_000) } catch { return }
                guard let self, self.generation == current, let pending = self.pending else { return }
                self.pending = nil; self.session?.restore(); self.session = nil
                pending.resume(throwing: NSError(domain: "FoldBar", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: L("系统没有及时响应，已临时展开。修改仍保留，可重新应用。 ")]))
            }
        }
    }
}
