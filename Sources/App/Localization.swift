import Foundation

enum Localizer {
    private static let lock = NSLock()
    private static var language: AppLanguage = .system
    private static let bundles: [String: Bundle] = Dictionary(uniqueKeysWithValues: ["en", "zh-Hans"].compactMap { code in
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"), let bundle = Bundle(path: path) else { return nil }
        return (code, bundle)
    })
    static func select(_ selection: AppLanguage) {
        lock.lock(); language = selection; lock.unlock()
    }
    static func string(_ key: String, _ arguments: [CVarArg]) -> String {
        lock.lock(); let code = language.resolved(); lock.unlock()
        let format = bundles[code]?.localizedString(forKey: key, value: key, table: nil) ?? key
        return arguments.isEmpty ? format : String(format: format, locale: Locale(identifier: code), arguments: arguments)
    }
}

func L(_ key: String, _ arguments: CVarArg...) -> String { Localizer.string(key, arguments) }
