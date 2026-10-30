import SwiftUI

/// "Folio avatars": the 24 page spirits in a grid; tap to choose (Batch I).
struct AvatarPickerSheet: View {
    var onPick: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(DiaryStore.self) private var store

    var body: some View {
        let current = FolioAvatar.number(from: store.settings().avatar)
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.m), count: 4), spacing: Spacing.m) {
                    ForEach(1...FolioAvatar.count, id: \.self) { number in
                        Button {
                            onPick(number)
                            dismiss()
                        } label: {
                            VStack(spacing: Spacing.xxs) {
                                Image(FolioAvatar.assetName(number))
                                    .resizable()
                                    .scaledToFit()
                                    .padding(4)
                                    .overlay {
                                        if current == number { Circle().strokeBorder(.ember, lineWidth: 3) }
                                    }
                                Text(FolioAvatar.name(number))
                                    .folioFont(.caption)
                                    .foregroundStyle(.inkSecondary)
                            }
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel(Text(FolioAvatar.name(number)))
                        .accessibilityAddTraits(current == number ? .isSelected : [])
                    }
                }
                .padding(Spacing.sideMargin)
            }
            .background { AuraBackground() }
            .navigationTitle("Folio avatars")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
