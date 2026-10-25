import SwiftUI

/// Phase 0 placeholder. Replaced by the tab shell in Phase 3.
struct RootView: View {
    var body: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()
            Text("Folio")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
        }
    }
}

#Preview("Light") {
    RootView()
}

#Preview("Dark") {
    RootView()
        .preferredColorScheme(.dark)
}
