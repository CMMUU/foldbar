import Foundation

/// The first version groups status items by their owning application.
/// System hosts and the controlling application can never be selected.
struct VisibilityPlan: Equatable {
    let hidden: Set<String>
    let allowed: [String]

    init(selected: Set<String>, running: Set<String>, ownBundle: String) {
        hidden = selected.intersection(running).filter {
            !$0.hasPrefix("com.apple.") && $0 != ownBundle && !$0.isEmpty
        }
        allowed = running.union([ownBundle]).subtracting(hidden).sorted()
    }
}
