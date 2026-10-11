import Foundation

public enum AppLanguage: String, CaseIterable {
    case system, chinese = "zh-Hans", english = "en"

    public func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        switch self {
        case .chinese: return "zh-Hans"
        case .english: return "en"
        case .system: return preferredLanguages.first?.lowercased().hasPrefix("zh") == true ? "zh-Hans" : "en"
        }
    }
}
