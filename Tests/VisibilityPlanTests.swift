import XCTest
@testable import FoldBarCore

final class VisibilityPlanTests: XCTestCase {
    func testNeverHidesControllerOrSystemEvenWithStalePreferences() {
        let plan = VisibilityPlan(selected: ["self", "com.apple.controlcenter", "third"], running: ["self", "com.apple.controlcenter", "third"], ownBundle: "self")
        XCTAssertEqual(plan.hidden, ["third"])
        XCTAssertEqual(Set(plan.allowed), ["self", "com.apple.controlcenter"])
    }
    func testOnlyChosenRunningApplicationIsRemoved() {
        let plan = VisibilityPlan(selected: ["old", "chosen"], running: ["chosen", "new", "untouched"], ownBundle: "self")
        XCTAssertEqual(plan.hidden, ["chosen"])
        XCTAssertEqual(Set(plan.allowed), ["self", "new", "untouched"])
    }
    func testEmptySelectionLeavesEverythingVisible() {
        let plan = VisibilityPlan(selected: [], running: ["one", "two"], ownBundle: "self")
        XCTAssertTrue(plan.hidden.isEmpty)
        XCTAssertEqual(Set(plan.allowed), ["self", "one", "two"])
    }
}
