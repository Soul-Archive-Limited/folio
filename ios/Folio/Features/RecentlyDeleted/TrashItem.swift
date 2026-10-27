import Foundation

/// The three kinds of thing Recently Deleted holds (SPEC §5.2), one per segment.
enum TrashKind: String, CaseIterable, Identifiable {
    case entries, tasks, categories

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .entries: "Entries"
        case .tasks: "Tasks"
        case .categories: "Categories"
        }
    }
}

/// One trashed record, by kind and id.
struct TrashItem: Identifiable, Hashable {
    let kind: TrashKind
    let id: UUID
}
