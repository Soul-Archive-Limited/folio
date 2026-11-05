import SwiftUI

/// The compact title with the Timeline / Photos toggle beside it, then the category chips.
/// "Write for a past day" lives in the top bar (Batch I: one row less, one pill less).
struct JournalControls: View {
    @Bindable var model: JournalModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var toggle

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .center) {
                CompactTitleText(title: "Journal")
                Spacer()
                GlassEffectContainer(spacing: Spacing.xs) {
                    HStack(spacing: 4) {
                        ForEach(JournalModel.Mode.allCases) { mode in
                            Button {
                                withAnimation(FolioMotion.standard(reduceMotion: reduceMotion)) { model.mode = mode }
                            } label: {
                                Label(mode.title, systemImage: mode.symbol)
                                    .labelStyle(.iconOnly)
                                    .padding(.horizontal, Spacing.s)
                                    .frame(minWidth: Spacing.minHitTarget, minHeight: 36)
                                    .contentShape(.capsule)
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(model.mode == mode ? AnyShapeStyle(.white) : AnyShapeStyle(.ink))
                            .background {
                                if model.mode == mode {
                                    Capsule().fill(.emberStrong).matchedGeometryEffect(id: "mode", in: toggle)
                                }
                            }
                            .accessibilityAddTraits(model.mode == mode ? .isSelected : [])
                        }
                    }
                    .padding(2)
                    .glassEffect(.regular, in: .capsule)
                }
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
        }
    }

    var symbol: String {
        switch self {
        case .timeline: "list.bullet.below.rectangle"
        case .photos: "square.grid.3x3"
        case .year: "square.grid.4x3.fill"
        }
    }
}
