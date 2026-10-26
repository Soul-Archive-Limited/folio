/// How many items use a category, shown when confirming its deletion (SPEC §5, §6.10).
struct CategoryUsage: Equatable, Sendable {
    let entries: Int
    let tasks: Int
}
