import SwiftUI

/// Create or edit a category (SPEC §6.10): name, 12-swatch colour grid, optional symbol from
/// 40, and a live chip preview.
struct CategoryEditSheet: View {
    let target: CategoryEditTarget

    @Environment(DiaryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var color: CategoryColor
    @State private var symbol: String?
    @State private var error: StoreError?

    init(target: CategoryEditTarget) {
        self.target = target
        if case .existing(let category) = target {
            _name = State(initialValue: category.name)
            _color = State(initialValue: category.color)
            _symbol = State(initialValue: category.symbol)
        } else {
            _name = State(initialValue: "")
            _color = State(initialValue: .ocean)
            _symbol = State(initialValue: nil)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    HStack {
                        Spacer()
                        Chip(title: name.isEmpty ? String(localized: "Preview") : name, systemImage: symbol,
                             category: color, isSelected: true) {}
                            .allowsHitTesting(false)
                            .accessibilityLabel("Preview")
                        Spacer()
                    }
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        TextField("Name", text: $name)
                            .folioFont(.headline)
                            .padding(Spacing.m)
                            .folioGlass(in: .rect(cornerRadius: Radius.card))
                            .onChange(of: name) { _, new in if new.count > 24 { name = String(new.prefix(24)) } }
                        if let error { Text(message(for: error)).folioFont(.callout).foregroundStyle(.danger) }
                    }
                    PanelSectionTitle(title: "Colour")
                    ColorSwatchGrid(selection: $color)
                    PanelSectionTitle(title: "Symbol")
                    SymbolGrid(selection: $symbol, tint: color.color)
                }
                .padding(Spacing.sideMargin)
            }
            .navigationTitle(isNew ? "New category" : "Edit category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .buttonStyle(.glassProminent)
                        .tint(.emberStrong)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(.thickMaterial)
        .privacyCovered()
    }

    private var isNew: Bool {
        if case .new = target { true } else { false }
    }

    private func save() {
        do {
            switch target {
            case .new: try store.createCategory(name: name, color: color, symbol: symbol)
            case .existing(let category): try store.updateCategory(category, name: name, color: color, symbol: symbol)
            }
            dismiss()
        } catch {
            self.error = error
        }
    }

    private func message(for error: StoreError) -> LocalizedStringKey {
        switch error {
        case .duplicateCategoryName: "You already have a category with this name."
        case .categoryNameTooLong: "Names can be up to 24 characters."
        case .tooManyCategories: "You can have up to 30 categories."
        default: "Please give the category a name."
        }
    }
}
