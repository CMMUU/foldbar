import XCTest
@testable import FoldBarCore

final class AppLanguageTests: XCTestCase {
    func testSystemChineseVariantsAndEnglishFallback() {
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["zh-Hans-CN", "en"]), "zh-Hans")
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["zh-Hant-TW"]), "zh-Hans")
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["fr-FR", "zh"]), "en")
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: []), "en")
    }
    func testExplicitLanguageOverridesSystem() {
        XCTAssertEqual(AppLanguage.english.resolved(preferredLanguages: ["zh-CN"]), "en")
        XCTAssertEqual(AppLanguage.chinese.resolved(preferredLanguages: ["en-US"]), "zh-Hans")
    }
}
