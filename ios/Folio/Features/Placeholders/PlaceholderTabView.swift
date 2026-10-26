import SwiftUI

/// Journal and To-do until Phases 5–6.
struct PlaceholderTabView: View {
    let title: LocalizedStringKey
    let systemImage: String
    let message: LocalizedStringKey

    var body: some View {
        NavigationStack {
            ScrollView {
                EmptyStateView(systemImage: systemImage, message: message)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 120)
            }
            .background { AuraBackground() }
            .navigationTitle(title)
        }
    }
}

#Preview {
    PlaceholderTabView(title: "Journal", systemImage: "book.pages", message: "Your journal is empty.")
}
