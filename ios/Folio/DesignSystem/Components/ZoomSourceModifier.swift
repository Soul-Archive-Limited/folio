import SwiftUI

extension View {
    /// Marks a view as the zoom-transition source when a namespace is available. The source is
    /// clipped to its rounded shape during the zoom, so a photo never draws outside its card
    /// mid-transition (Batch E).
    @ViewBuilder
    func zoomSource(id: some Hashable, in namespace: Namespace.ID?, cornerRadius: Double = Radius.card) -> some View {
        if let namespace {
            matchedTransitionSource(id: id, in: namespace) { source in
                source.clipShape(.rect(cornerRadius: cornerRadius))
            }
        } else {
            self
        }
    }
}
