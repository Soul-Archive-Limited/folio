import SwiftUI

/// A small read-only category label: colour dot + name.
struct CategoryTag: View {
    let category: Category

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(category.color.color).frame(width: 7, height: 7)
            Text(category.name).folioFont(.caption).foregroundStyle(.inkSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Category \(category.name)")
    }
}
