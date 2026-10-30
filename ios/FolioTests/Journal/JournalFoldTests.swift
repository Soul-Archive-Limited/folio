import Foundation
import Testing
@testable import Folio

@MainActor
@Suite("Journal months fold, remembered (Batch I)")
struct JournalFoldTests {
    let defaults = UserDefaults(suiteName: "JournalFoldTests-\(UUID().uuidString)")!
    let today = DayKey(rawValue: "2026-10-30")!

    private func month(_ raw: String) -> MonthKey { DayKey(rawValue: raw + "-01")!.monthKey }

    @Test("This month and last month open by default; older months closed")
    func defaults_() {
        let model = JournalModel(defaults: defaults)
        #expect(model.isOpen(month("2026-10"), today: today))
        #expect(model.isOpen(month("2026-09"), today: today))
        #expect(!model.isOpen(month("2026-08"), today: today))
        #expect(!model.isOpen(month("2019-03"), today: today))
    }

    @Test("A toggle is remembered across launches, and toggling back forgets it")
    func remembered() {
        let model = JournalModel(defaults: defaults)
        model.toggle(month("2025-01"), today: today)
        model.toggle(month("2026-10"), today: today)
        let relaunched = JournalModel(defaults: defaults)
        #expect(relaunched.isOpen(month("2025-01"), today: today))
        #expect(!relaunched.isOpen(month("2026-10"), today: today))
        relaunched.toggle(month("2025-01"), today: today)
        #expect(relaunched.foldOverrides[month("2025-01").id] == nil)
    }
}
