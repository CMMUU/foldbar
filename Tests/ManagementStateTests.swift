import XCTest
@testable import FoldBarCore

final class ManagementStateTests: XCTestCase {
    func testLocalEditPreservesUnselectedAndOfflineChoices() {
        var state = ManagementState(applied: ["a", "offline"])
        state.stage(["b"], folded: true, editable: ["a", "b"])
        XCTAssertEqual(state.applied, ["a", "offline"])
        XCTAssertEqual(state.draft, ["a", "b", "offline"])
        XCTAssertEqual(state.changed, ["b"])
    }
    func testBatchCannotMutateReadOnlyItems() {
        var state = ManagementState(applied: ["a", "b"])
        state.stage(["a", "system"], folded: false, editable: ["a", "b"])
        state.stage(["system"], folded: true, editable: ["a", "b"])
        XCTAssertEqual(state.draft, ["b"])
    }
    func testCancelRestoresAppliedAndClearsUndo() {
        var state = ManagementState(applied: ["a"])
        state.stage(["b"], folded: true, editable: ["a", "b"])
        state.cancel()
        XCTAssertEqual(state.draft, ["a"])
        XCTAssertFalse(state.canUndoDraft)
    }
    func testDraftUndoRestoresEachBatch() {
        var state = ManagementState(applied: [])
        state.stage(["a", "b"], folded: true, editable: ["a", "b", "c"])
        state.stage(["c"], folded: true, editable: ["a", "b", "c"])
        state.undoDraft(); XCTAssertEqual(state.draft, ["a", "b"])
        state.undoDraft(); XCTAssertEqual(state.draft, [])
    }
    func testAppliedUndoRestoresPreviousConfiguration() {
        var state = ManagementState(applied: ["a"])
        state.stage(["b"], folded: true, editable: ["a", "b"])
        state.acceptApply()
        XCTAssertEqual(state.applied, ["a", "b"])
        XCTAssertEqual(state.previousApplied, ["a"])
        state.acceptAppliedUndo()
        XCTAssertEqual(state.applied, ["a"])
        XCTAssertEqual(state.draft, state.applied)
    }
    func testReturningToOriginalIsNotPending() {
        var state = ManagementState(applied: [])
        state.stage(["a"], folded: true, editable: ["a"])
        state.stage(["a"], folded: false, editable: ["a"])
        XCTAssertFalse(state.isDirty)
        state.acceptApply()
        XCTAssertNil(state.previousApplied)
    }
    func testUnacceptedPlanKeepsDraftForRetry() {
        var state = ManagementState(applied: ["a"])
        state.stage(["b"], folded: true, editable: ["a", "b"])
        // A failed platform operation must not call acceptApply.
        XCTAssertEqual(state.applied, ["a"])
        XCTAssertEqual(state.draft, ["a", "b"])
        XCTAssertTrue(state.isDirty)
    }
}
