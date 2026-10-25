import SwiftUI

/// The Folio mark, identical to the launch screen image (SPEC §4.1).
struct AppMark: View {
    var size: Double = 72

    var body: some View {
        Image(.appMark)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .accessibilityLabel("Folio")
    }
}

#Preview {
    AppMark().padding().background(.bg)
}
