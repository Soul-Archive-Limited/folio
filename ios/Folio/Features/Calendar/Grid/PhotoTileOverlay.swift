import SwiftUI

/// The white day number (top-leading; on an ember pill when it's today) and "+2" badge
/// (bottom-trailing) on a photo tile; the task mark has the top-trailing corner (Batch I),
/// over a scrim that keeps them readable on any photo: a ~15 % dim over the whole tile and a
/// soft dark-to-clear gradient behind the number's corner (owner's iPhone test, Batch E).
struct PhotoTileOverlay: View {
    let state: DayCellState
    let size: Double

    var body: some View {
        ZStack {
            PhotoTileScrim()
            Text(state.day.day, format: .number)
                .folioFont(.micro)
                .monospacedDigit()
                .foregroundStyle(.white)
                .shadow(color: state.isToday ? .clear : .black.opacity(0.55), radius: 2)
                .padding(.horizontal, state.isToday ? 3 : 0)
                .background { if state.isToday { Capsule().fill(.emberStrong) } }
                .padding(state.isToday ? 2.5 : 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            if let extra = state.marker?.extraEntryCount, extra > 0 {
                Text("+\(extra)")
                    .folioFont(.micro)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3)
                    .background(.black.opacity(0.45), in: .capsule)
                    .padding(3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .frame(width: size, height: size)
        .opacity(state.isInMonth ? 1 : 0.5)
    }
}

/// Darkens a photo tile just enough for white micro text: 15 % overall, up to ~55 % in the
/// top-leading corner where the day number sits, fading out before the middle.
struct PhotoTileScrim: View {
    static let dim = 0.15
    static let cornerDim = 0.4

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.dayCell)
            .fill(.black.opacity(Self.dim))
            .overlay {
                LinearGradient(stops: [.init(color: .black.opacity(Self.cornerDim), location: 0),
                                       .init(color: .clear, location: 0.55)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            .clipShape(.rect(cornerRadius: Radius.dayCell))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
