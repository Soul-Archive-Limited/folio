import SwiftUI

/// Optional symbol from the 40 curated SF Symbols, plus "None".
struct SymbolGrid: View {
    @Binding var selection: String?
    let tint: Color

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 6), spacing: Spacing.xs) {
            cell(nil)
            ForEach(CategorySymbols.all, id: \.self) { symbol in cell(symbol) }
        }
        .folioHaptic(.selection, trigger: selection)
    }

    private func cell(_ symbol: String?) -> some View {
        let isSelected = selection == symbol
        return Button { selection = symbol } label: {
            Image(systemName: symbol ?? "nosign")
                .font(.title3)
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.ink))
                .frame(width: Spacing.minHitTarget, height: Spacing.minHitTarget)
                .background(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 12))
                .folioGlass(in: .rect(cornerRadius: 12), interactive: true, solidFill: isSelected ? tint : nil)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(symbol.map { $0.replacing(".", with: " ") } ?? String(localized: "No symbol"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
