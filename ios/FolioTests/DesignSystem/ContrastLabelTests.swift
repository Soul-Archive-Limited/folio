import SwiftUI
import Testing
@testable import Folio

@Suite("Category colours (SPEC §3.2)")
struct ContrastLabelTests {
    @Test("Every category label passes WCAG AA (4.5:1) in light and dark",
          arguments: CategoryColor.allCases, [ColorScheme.light, .dark])
    func labelContrast(category: CategoryColor, scheme: ColorScheme) {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        let fill = category.color.resolve(in: environment)
        let fillLuminance = ContrastLabel.relativeLuminance(red: Double(fill.red), green: Double(fill.green), blue: Double(fill.blue))
        let labelLuminance = ContrastLabel.prefersLightLabel(fillLuminance: fillLuminance) ? 1.0 : ContrastLabel.darkLuminance
        #expect(ContrastLabel.contrastRatio(fillLuminance, labelLuminance) >= 4.5)
    }

    @Test("Known WCAG reference values")
    func wcagReference() {
        #expect(abs(ContrastLabel.contrastRatio(1, 0) - 21) < 0.001)
        #expect(abs(ContrastLabel.relativeLuminance(red: 1, green: 1, blue: 1) - 1) < 0.0001)
    }

    @Test("Unknown colour keys fall back to graphite")
    func fallback() {
        #expect(CategoryColor(key: "ultraviolet") == .graphite)
        #expect(CategoryColor(key: "teal") == .teal)
    }

    @Test("Reduce Motion swaps every spring for the short ease")
    func reducedMotion() {
        #expect(FolioMotion.standard(reduceMotion: true) == FolioMotion.reduced)
        #expect(FolioMotion.confirm(reduceMotion: true) == FolioMotion.reduced)
        #expect(FolioMotion.standard() != FolioMotion.reduced)
    }
}
