import SwiftUI

/// The font used for diary text (SPEC §3.3). New York by default.
nonisolated enum WritingFont: String, CaseIterable, Identifiable, Sendable {
    case newYork
    case sfPro

    var id: Self { self }

    var displayName: LocalizedStringResource {
        switch self {
        case .newYork: "New York"
        case .sfPro: "SF Pro"
        }
    }

    var design: Font.Design {
        switch self {
        case .newYork: .serif
        case .sfPro: .default
        }
    }

    func font(_ textStyle: Font.TextStyle = .body) -> Font {
        .system(textStyle, design: design)
    }
}
