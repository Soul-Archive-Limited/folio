import Testing
@testable import Folio

@Suite("Calendar collapse always rests fully open or fully collapsed (Batch I)")
struct CollapseSnapTests {
    @Test("A half-way stop snaps to the nearer end", arguments: [
        (10.0, 0.0), (99.0, 0.0), (101.0, 200.0), (199.0, 200.0),
    ])
    func snapsToNearestEnd(progress: Double, rest: Double) {
        #expect(CollapseSnapBehavior.restingProgress(progress, distance: 200) == rest)
    }

    @Test("Already open, already collapsed or scrolled past the collapse stays put", arguments: [0.0, 200.0, 640.0, -30.0])
    func leavesEndsAlone(progress: Double) {
        #expect(CollapseSnapBehavior.restingProgress(progress, distance: 200) == progress)
    }
}
