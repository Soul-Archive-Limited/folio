import SwiftUI

struct FolioTextStyleModifier: ViewModifier {
    let style: FolioTextStyle

    @ScaledMetric(relativeTo: .largeTitle) private var displaySize = 56
    @ScaledMetric(relativeTo: .caption2) private var microSize = 10

    func body(content: Content) -> some View {
        content
            .font(font)
            .tracking(tracking)
            .textCase(style == .caption ? .uppercase : nil)
    }

    private var font: Font {
        switch style {
        case .display: .system(size: displaySize, weight: .bold)
        case .title1: .largeTitle.bold()
        case .title2: .title2.weight(.semibold)
        case .headline: .headline
        case .body: .body
        case .callout: .subheadline
        case .caption: .caption.weight(.medium)
        case .micro: .system(size: microSize, weight: .semibold)
        }
    }

    private var tracking: Double {
        switch style {
        case .display: -1.5
        case .caption: 0.6
        default: 0
        }
    }
}
