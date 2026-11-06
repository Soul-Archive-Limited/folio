import Foundation
import Testing
import UIKit
@testable import Folio

/// Batch K bug: replace an entry's photo, go back — the day panel card kept the old picture
/// until the app restarted, because the card's view kept its image and skipped loading the new one.
@Suite("Photo views show the photo they're given")
@MainActor
struct ShownPhotoTests {
    let old = UIImage()
    let new = UIImage()

    @Test("A different, uncached photo drops the old image and loads")
    func replacedPhotoLoads() {
        var shown = ShownPhoto()
        let first = UUID(), second = UUID()
        let needsFirst = shown.begin(first, cached: nil)
        #expect(needsFirst)
        shown.finish(first, image: old)
        #expect(shown.image === old)

        let needsSecond = shown.begin(second, cached: nil)
        #expect(needsSecond, "the new photo must be loaded")
        #expect(shown.image == nil, "the old photo must not stay on screen")
        shown.finish(second, image: new)
        #expect(shown.image === new)
    }

    @Test("A cached photo shows at once; the same photo keeps its image on a sync revision")
    func cachedAndRevision() {
        var shown = ShownPhoto()
        let id = UUID()
        let needsCached = shown.begin(id, cached: old)
        #expect(!needsCached)
        #expect(shown.image === old)
        // Same photo, new sync revision, nothing cached under that key: keep showing it.
        let needsAgain = shown.begin(id, cached: nil)
        #expect(!needsAgain)
        #expect(shown.image === old)
    }

    @Test("A load that finishes after the view moved on is ignored")
    func lateLoadIgnored() {
        var shown = ShownPhoto()
        let first = UUID(), second = UUID()
        _ = shown.begin(first, cached: nil)
        _ = shown.begin(second, cached: nil)
        shown.finish(first, image: old)
        #expect(shown.image == nil)
        #expect(shown.id == second)
    }
}
