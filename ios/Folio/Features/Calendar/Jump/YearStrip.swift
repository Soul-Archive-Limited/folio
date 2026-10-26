import SwiftUI

/// Horizontal snapping strip of years; the selected year is shown in `display`.
struct YearStrip: View {
    @Binding var selectedYear: Int
    let years: [Int]

    @State private var position: Int?
    @State private var width: Double = 402

    /// Fixed so view-aligned snapping lands every year dead centre.
    static let itemWidth: Double = 150

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(years, id: \.self) { year in
                    Text(year, format: .number.grouping(.never))
                        .folioFont(year == selectedYear ? .display : .title2)
                        .monospacedDigit()
                        .foregroundStyle(year == selectedYear ? AnyShapeStyle(.ink) : AnyShapeStyle(.inkTertiary))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(width: Self.itemWidth)
                        .onTapGesture { position = year }
                        .accessibilityAddTraits(year == selectedYear ? [.isButton, .isSelected] : .isButton)
                        .id(year)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, max((width - Self.itemWidth) / 2, 0), for: .scrollContent)
        .onGeometryChange(for: Double.self) { $0.size.width } action: { width = $0 }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $position, anchor: .center)
        .scrollIndicators(.hidden)
        .frame(height: 80)
        .onAppear { position = selectedYear }
        .onChange(of: position) { _, year in
            if let year { selectedYear = year }
        }
        .folioHaptic(.selection, trigger: selectedYear)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Year")
        .accessibilityValue(selectedYear.formatted(.number.grouping(.never)))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: position = min(selectedYear + 1, years.last ?? selectedYear)
            case .decrement: position = max(selectedYear - 1, years.first ?? selectedYear)
            @unknown default: break
            }
        }
    }
}
