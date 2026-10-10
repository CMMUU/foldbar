import Foundation

struct ManagementState: Equatable {
    private(set) var applied: Set<String>
    private(set) var draft: Set<String>
    private var draftHistory: [Set<String>] = []
    private var appliedHistory: [Set<String>] = []

    init(applied: Set<String>) { self.applied = applied; self.draft = applied }
    var changed: Set<String> { applied.symmetricDifference(draft) }
    var isDirty: Bool { !changed.isEmpty }
    var canUndoDraft: Bool { !draftHistory.isEmpty }
    var previousApplied: Set<String>? { appliedHistory.last }

    mutating func stage(_ ids: Set<String>, folded: Bool, editable: Set<String>) {
        let affected = ids.intersection(editable)
        let next = folded ? draft.union(affected) : draft.subtracting(affected)
        guard next != draft else { return }
        draftHistory.append(draft)
        if draftHistory.count > 40 { draftHistory.removeFirst() }
        draft = next
    }
    mutating func cancel() { draft = applied; draftHistory.removeAll() }
    mutating func undoDraft() {
        if let previous = draftHistory.popLast() { draft = previous }
    }
    // Commit only after the platform accepted the new visibility plan.
    mutating func acceptApply() {
        guard isDirty else { return }
        appliedHistory.append(applied)
        if appliedHistory.count > 20 { appliedHistory.removeFirst() }
        applied = draft
        draftHistory.removeAll()
    }
    mutating func acceptAppliedUndo() {
        guard let previous = appliedHistory.popLast() else { return }
        applied = previous; draft = previous; draftHistory.removeAll()
    }
}
