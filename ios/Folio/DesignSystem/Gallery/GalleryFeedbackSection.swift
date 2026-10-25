#if DEBUG
import SwiftUI

struct GalleryFeedbackSection: View {
    let toasts: ToastCenter

    @State private var selectionTick = 0
    @State private var successTick = 0
    @State private var lightTick = 0
    @State private var warningTick = 0

    var body: some View {
        GallerySection(title: "Toasts & haptics") {
            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack {
                    Button("Saved toast", action: showSaved).buttonStyle(.glass)
                    Button("Undo toast", action: showDeleted).buttonStyle(.glass)
                }
                HStack {
                    Button("Selection") { selectionTick += 1 }.buttonStyle(.glass)
                    Button("Success") { successTick += 1 }.buttonStyle(.glass)
                    Button("Light") { lightTick += 1 }.buttonStyle(.glass)
                    Button("Warning") { warningTick += 1 }.buttonStyle(.glass)
                }
                .folioHaptic(.selection, trigger: selectionTick)
                .folioHaptic(.success, trigger: successTick)
                .folioHaptic(.lightImpact, trigger: lightTick)
                .folioHaptic(.warning, trigger: warningTick)
            }
        }
    }

    private func showSaved() {
        toasts.show(ToastMessage(text: "Entry saved"))
    }

    private func showDeleted() {
        toasts.show(ToastMessage(text: "Entry deleted", systemImage: "trash", undo: ToastUndo {
            toasts.show(ToastMessage(text: "Entry restored"))
        }))
    }
}
#endif
