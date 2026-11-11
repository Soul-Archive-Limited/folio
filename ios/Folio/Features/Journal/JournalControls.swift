import SwiftUI

/// The compact title with the Timeline / Photos toggle beside it, then the category chips.
/// "Write for a past day" lives in the top bar (Batch I: one row less, one pill less).
struct JournalControls: View {
    @Bindable var model: JournalModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Namespace private var toggle

    var body: some View {
        // Batch O: at accessibility sizes the title beside the four-mode toggle split into
        // "Jour-nal"; there the toggle goes under the title, and its icons stop growing.
        let header = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.s))
            : AnyLayout(HStackLayout(alignment: .center))
        VStack(alignment: .leading, spacing: Spacing.s) {
            header {
                CompactTitleText(title: "Journal")
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                GlassEffectContainer(spacing: Spacing.xs) {
                    HStack(spacing: 4) {
                        ForEach(JournalModel.Mode.allCases) { mode in
                            Button {
                                withAnimation(FolioMotion.standard(reduceMotion: reduceMotion)) { model.mode = mode }
                            } label: {
                                Label { Text(mode.title) } icon: { mode.icon }
                                    .labelStyle(.iconOnly)
                                    .padding(.horizontal, Spacing.s)
                                    .frame(minWidth: Spacing.minHitTarget, minHeight: 36)
                                    .contentShape(.capsule)
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(model.mode == mode ? AnyShapeStyle(.white) : AnyShapeStyle(.ink))
                            .background {
                                if model.mode == mode {
                                    Capsule().fill(.accentStrong).matchedGeometryEffect(id: "mode", in: toggle)
                                }
                            }
                            .accessibilityAddTraits(model.mode == mode ? .isSelected : [])
                        }
                    }
                    .padding(2)
                    .glassEffect(.regular, in: .capsule)
                }
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
            .padding(.horizontal, Spacing.sideMargin)
            if model.mode != .year { CategoryFilterBar(selection: $model.filter) }
        }
    }
}

extension JournalModel.Mode {
    var title: LocalizedStringKey {
        switch self {
        case .timeline: "Timeline"
        case .photos: "Photos"
        case .year: "Year in Pixels"
        case .places: "Places"
        }
    }

    var symbol: String {
        switch self {
        case .timeline: "list.bullet.below.rectangle"
        case .photos: "square.grid.3x3"
        case .year: "square.grid.4x3.fill"
        case .places: "map"
        }
    }

    /// Places uses Folio's own map glyph (Batch N); the others keep their SF Symbols.
    var icon: Image {
        self == .places ? Image(.folioMap) : Image(systemName: symbol)
    }
}
