import SwiftUI

/// `bg` plus the aura, which fades in as the mark lifts.
struct GreetingBackdrop: View {
    let stage: GreetingIntroModel.Stage

    var body: some View {
        ZStack {
            Color.bg
            AuraBackground()
                .opacity(stage >= .lifted ? 1 : 0)
        }
        .ignoresSafeArea()
    }
}
