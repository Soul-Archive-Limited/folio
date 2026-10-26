import SwiftUI

/// The white day number (top-leading) and "+2" badge (bottom-trailing) on a photo tile.
struct PhotoTileOverlay: View {
    let state: DayCellState
    let size: Double

    var body: some View {
        ZStack {
            Text(state.day.day, format: .number)
                .folioFont(.micro)
                .monospacedDigit()
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.55), radius: 2)
                .padding(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            if let extra = state.marker?.extraPhotoCount, extra > 0 {
                Text("+\(extra)")
                    .folioFont(.micro)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3)
                    .background(.black.opacity(0.45), in: .capsule)
                    .padding(3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            if state.isToday {
                Circle().fill(.ember).frame(width: 6, height: 6)
                    .overlay { Circle().strokeBorder(.white, lineWidth: 1) }
                    .padding(4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .frame(width: size, height: size)
        .opacity(state.isInMonth ? 1 : 0.5)
    }
}
