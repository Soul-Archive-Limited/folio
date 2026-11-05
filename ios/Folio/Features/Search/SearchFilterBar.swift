import SwiftUI

/// Filters under the search field (Batch J): category, has photos, date range, open/done.
struct SearchFilterBar: View {
    @Bindable var model: SearchModel
    @Environment(DiaryStore.self) private var store
    @State private var choosingDates = false

    var body: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 0) {
                HStack(spacing: Spacing.xs) {
                    categoryMenu
                    if model.filters.scope == .everything {
                        Chip(title: String(localized: "Photos"), systemImage: "photo", isSelected: model.filters.hasPhotos) {
                            model.filters.hasPhotos.toggle()
                        }
                    }
                    dateMenu
                    statusMenu
                    if model.filters.isActive {
                        Chip(title: String(localized: "Clear"), systemImage: "xmark") {
                            model.filters = SearchFilters(scope: model.filters.scope)
                        }
                        .accessibilityLabel("Clear filters")
                    }
                }
            }
            .padding(.horizontal, Spacing.sideMargin)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .sheet(isPresented: $choosingDates) { SearchDateRangeSheet(filters: $model.filters, today: store.today) }
    }

    private var categoryMenu: some View {
        let categories = store.categories()
        let selected = categories.filter { model.filters.categories.contains($0.id) }
        return Menu {
            ForEach(categories) { category in
                Toggle(category.name, isOn: Binding(
                    get: { model.filters.categories.contains(category.id) },
                    set: { on in
                        if on { model.filters.categories.insert(category.id) } else { model.filters.categories.remove(category.id) }
                    }))
            }
        } label: {
            FilterLabel(title: selected.count == 1 ? selected[0].name : selected.isEmpty ? String(localized: "Category")
                            : String(localized: "\(selected.count) categories"),
                        systemImage: "tag", isOn: !selected.isEmpty)
        }
        .disabled(categories.isEmpty)
    }

    private var dateMenu: some View {
        let today = store.today
        return Menu {
            Button("Any time") { setRange(nil, nil) }
            Button("This month") { setRange(DayKey(year: today.year, month: today.month, day: 1), today) }
            Button("Past 3 months") { setRange(today.adding(days: -91), today) }
            Button("This year") { setRange(DayKey(year: today.year, month: 1, day: 1), today) }
            Button("Last year") { setRange(DayKey(year: today.year - 1, month: 1, day: 1), DayKey(year: today.year - 1, month: 12, day: 31)) }
            Button("Choose dates…") { choosingDates = true }
        } label: {
            FilterLabel(title: rangeTitle, systemImage: "calendar", isOn: model.filters.from != nil || model.filters.through != nil)
        }
    }

    private var statusMenu: some View {
        Menu {
            Picker("Tasks", selection: $model.filters.status) {
                Text("Any").tag(SearchFilters.Status.any)
                Text("Open tasks").tag(SearchFilters.Status.open)
                Text("Done tasks").tag(SearchFilters.Status.done)
            }
        } label: {
            FilterLabel(title: statusTitle, systemImage: "checklist", isOn: model.filters.status != .any)
        }
    }

    private var statusTitle: String {
        switch model.filters.status {
        case .any: String(localized: "Open or done")
        case .open: String(localized: "Open")
        case .done: String(localized: "Done")
        }
    }

    private var rangeTitle: String {
        let style = Date.FormatStyle(timeZone: .gmt).day().month(.abbreviated).year(.twoDigits)
        switch (model.filters.from, model.filters.through) {
        case (nil, nil): return String(localized: "Any time")
        case let (from?, through?): return "\(from.utcDate.formatted(style)) – \(through.utcDate.formatted(style))"
        case let (from?, nil): return String(localized: "From \(from.utcDate.formatted(style))")
        case let (nil, through?): return String(localized: "Until \(through.utcDate.formatted(style))")
        }
    }

    private func setRange(_ from: DayKey?, _ through: DayKey?) {
        model.filters.from = from
        model.filters.through = through
    }
}

/// A chip-looking menu label; filled when the filter is on.
private struct FilterLabel: View {
    let title: String
    let systemImage: String
    let isOn: Bool

    var body: some View {
        HStack(spacing: Spacing.xs - 2) {
            Image(systemName: isOn ? "checkmark" : systemImage).font(.caption.weight(.semibold))
            Text(title).folioFont(.caption)
            Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
        }
        .foregroundStyle(isOn ? Color.white : .ink)
        .padding(.horizontal, Spacing.s)
        .frame(minHeight: Spacing.minHitTarget - 12)
        .folioGlass(in: .capsule, interactive: true, solidFill: isOn ? .emberStrong : nil)
        .padding(.vertical, 6)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// "Choose dates…": two date pickers for the range.
private struct SearchDateRangeSheet: View {
    @Binding var filters: SearchFilters
    let today: DayKey
    @Environment(\.dismiss) private var dismiss
    @State private var from = Date()
    @State private var through = Date()

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("From", selection: $from, displayedComponents: .date)
                DatePicker("Until", selection: $through, in: from..., displayedComponents: .date)
            }
            .environment(\.timeZone, .gmt)
            .navigationTitle("Dates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        filters.from = DayKey(date: from, calendar: DayKey.arithmeticCalendar)
                        filters.through = DayKey(date: through, calendar: DayKey.arithmeticCalendar)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            from = (filters.from ?? today.adding(days: -30)).utcDate
            through = (filters.through ?? today).utcDate
        }
    }
}
