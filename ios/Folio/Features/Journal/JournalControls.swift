import SwiftUI

/// Category chips, the Timeline / Photos toggle and "Write for a past day".
struct JournalControls: View {
    @Bindable var model: JournalModel
    let onWritePast: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var toggle

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            CategoryFilterBar(selection: $model.filter)
            HStack {
                GlassEffectContainer(spacing: Spacing.xs) {
                    HStack(spacing: 4) {
                        ForEach(JournalModel.Mode.allCases) { mode in
                            Button(mode == .timeline ? "Timeline" : "Photos",
                                   systemImage: mode == .timeline ? "list.bullet.below.rectangle" : "square.grid.3x3") {
                                withAnimation(FolioMotion.standard(reduceMotion: reduceMotion)) { model.mode = mode }
                            }
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, Spacing.s)
                            .frame(minHeight: 36)
                            .foregroundStyle(model.mode == mode ? AnyShapeStyle(.white) : AnyShapeStyle(.ink))
                            .background {
                                if model.mode == mode {
                                    Capsule().fill(.ember).matchedGeometryEffect(id: "mode", in: toggle)
                                }
                            }
                            .accessibilityAddTraits(model.mode == mode ? .isSelected : [])
                        }
                    }
                    .padding(4)
                    .glassEffect(.regular, in: .capsule)
                }
                Spacer()
                Button("Write for a past day", systemImage: "calendar.badge.plus", action: onWritePast)
                    .labelStyle(.iconOnly)
                    .font(.body.weight(.semibold))
                    .frame(width: Spacing.minHitTarget, height: Spacing.minHitTarget)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
            }
            .padding(.horizontal, Spacing.sideMargin)
        }
    }
}
