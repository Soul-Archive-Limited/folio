import Foundation
import Testing
@testable import Folio

@Suite("App smoke tests")
struct AppSmokeTests {
    @Test("Bundle identifier matches SPEC §1")
    func bundleIdentifier() {
        #expect(Bundle.main.bundleIdentifier == "com.devilsense.folio")
    }

    @Test("Display name is Folio")
    func displayName() {
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        #expect(name == "Folio")
    }
}
