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
                            Button {
                                withAnimation(FolioMotion.standard(reduceMotion: reduceMotion)) { model.mode = mode }
                            } label: {
                                Label(mode == .timeline ? "Timeline" : "Photos",
                                      systemImage: mode == .timeline ? "list.bullet.below.rectangle" : "square.grid.3x3")
                                    .padding(.horizontal, Spacing.s)
                                    .frame(minHeight: Spacing.minHitTarget)
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
                Spacer()
                // A labelled pill, not an icon: the calendar glyph alone didn't say what it does
                // (owner's iPhone test, Batch E).
                Button(action: onWritePast) {
                    Label("Past day", systemImage: "calendar.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: Spacing.minHitTarget - 8)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .accessibilityLabel("Write for a past day")
                .accessibilityIdentifier("journal.pastDay")
            }
            .padding(.horizontal, Spacing.sideMargin)
        }
    }
}
