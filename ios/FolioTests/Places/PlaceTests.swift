import FolioCrypto
import ImageIO
import Foundation
import SwiftData
import Testing
@testable import Folio

/// Places on entries (Batch N): validation, the encrypted payload, recents, the photo offer's
/// GPS read, drafts and search.
@MainActor
@Suite("Places on entries")
struct PlaceTests {
    let store: DiaryStore
    let container: ModelContainer

    init() throws {
        container = try FolioPersistence.makeContainer(inMemory: true)
        store = DiaryStore(context: container.mainContext, calendar: TestCalendar.london, now: { TestCalendar.date(2026, 11, 11, 9) })
    }

    @Test("Validation trims, cuts to length and drops coordinates off the globe")
    func validation() {
        #expect(Place(name: "   ").validated() == nil)
        let long = Place(name: String(repeating: "a", count: 300), address: "  ", latitude: 91, longitude: 10).validated()
        #expect(long?.name.count == Place.maximumNameLength)
        #expect(long?.address == nil)
        #expect(long?.latitude == nil && long?.longitude == nil)
        let nan = Place(name: "X", latitude: .nan, longitude: 0).validated()
        #expect(nan?.hasCoordinate == false)
        let ok = Place(name: " Tate Modern ", address: "Bankside, London", latitude: 51.5076, longitude: -0.0994).validated()
        #expect(ok == Place(name: "Tate Modern", address: "Bankside, London", latitude: 51.5076, longitude: -0.0994))
    }

    @Test("Apple Maps link: a pin when there's a coordinate, a search by name otherwise")
    func mapsURL() {
        let pinned = Place(name: "Tate Modern", latitude: 51.5076, longitude: -0.0994).mapsURL.absoluteString
        #expect(pinned.hasPrefix("https://maps.apple.com/?") && pinned.contains("ll=51.507600,-0.099400") && pinned.contains("q=Tate%20Modern"))
        let named = Place(name: "Café & bar").mapsURL.absoluteString
        #expect(!named.contains("ll=") && named.contains("q=Caf%C3%A9%20%26%20bar"))
    }

    @Test("setPlace stores, changes and removes; the entry is marked for sync each time")
    func setPlace() throws {
        let entry = try store.createEntry(title: "Walk", day: store.today)
        entry.isDirty = false
        store.setPlace(entry, Place(name: "Hampstead Heath", latitude: 51.56, longitude: -0.16))
        #expect(entry.place?.name == "Hampstead Heath" && entry.isDirty)
        entry.isDirty = false
        store.setPlace(entry, Place(name: "Hampstead Heath", latitude: 51.56, longitude: -0.16))
        #expect(!entry.isDirty, "the same place again changes nothing")
        store.setPlace(entry, nil)
        #expect(entry.place == nil && entry.placeLatitude == nil && entry.isDirty)
    }

    @Test("The place travels inside the encrypted entry payload, and back")
    func payloadRoundTrip() throws {
        let entry = try store.createEntry(title: "Lunch", day: store.today)
        store.setPlace(entry, Place(name: "Borough Market", address: "Southwark, London", latitude: 51.5055, longitude: -0.091))
        let json = try store.payload(of: entry)
        let object = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])
        let place = try #require(object["place"] as? [String: Any])
        #expect(place["name"] as? String == "Borough Market" && place["latitude"] as? Double == 51.5055)
        let decoded = try RecordPayload.decoder.decode(RecordPayload.Entry.self, from: json)
        #expect(decoded.place == entry.place)
    }

    @Test("A payload without a place (older app) or with a crafted one is handled safely")
    func remotePayloads() throws {
        let other = try FolioPersistence.makeContainer(inMemory: true)
        let device = DiaryStore(context: other.mainContext, calendar: TestCalendar.london, now: { TestCalendar.date(2026, 11, 11, 9) })
        let key = DataKey.generate(), userID = UUID()
        func deliver(_ json: String, id: UUID) throws {
            let sealed = try RecordCipher.seal(Data(json.utf8), recordID: id, type: .entry, userID: userID, using: key)
            let remote = SyncWire.Remote(id: id, type: "entry", version: 1, ciphertext: sealed.ciphertextAndTag.base64EncodedString(),
                                         nonce: sealed.nonce.base64EncodedString(), clientUpdatedAt: 1, deleted: false)
            let plain = try RecordCipher.open(sealed, recordID: id, type: .entry, userID: userID, using: key)
            device.isApplyingRemote = true
            device.applyRemote(remote, type: .entry, plaintext: plain)
            device.commit()
            device.isApplyingRemote = false
        }
        let old = UUID(), crafted = UUID(), nameOnly = UUID()
        try deliver(#"{"bodyMarkdown":"","createdAt":1,"dayKey":"2026-11-10","title":"Old"}"#, id: old)
        try deliver(#"{"bodyMarkdown":"","createdAt":1,"dayKey":"2026-11-10","place":{"name":"  ","latitude":10,"longitude":10},"title":"Crafted"}"#, id: crafted)
        try deliver(#"{"bodyMarkdown":"","createdAt":1,"dayKey":"2026-11-10","place":{"name":"The Eagle","latitude":500},"title":"Web"}"#, id: nameOnly)
        #expect(try #require(device.entry(id: old)).place == nil)
        #expect(try #require(device.entry(id: crafted)).place == nil)
        let web = try #require(device.entry(id: nameOnly)).place
        #expect(web?.name == "The Eagle" && web?.hasCoordinate == false)
    }

    @Test("Recent places come from the diary, newest first, one per place, never from Recently Deleted")
    func recents() throws {
        var clock = TestCalendar.date(2026, 11, 1, 9)
        let timed = DiaryStore(context: container.mainContext, calendar: TestCalendar.london, now: { clock })
        let a = try timed.createEntry(title: "A", day: timed.today)
        timed.setPlace(a, Place(name: "Tate Modern", latitude: 51.5076, longitude: -0.0994))
        clock = TestCalendar.date(2026, 11, 2, 9)
        let b = try timed.createEntry(title: "B", day: timed.today)
        timed.setPlace(b, Place(name: "Kew Gardens", latitude: 51.4787, longitude: -0.2956))
        clock = TestCalendar.date(2026, 11, 3, 9)
        let c = try timed.createEntry(title: "C", day: timed.today)
        timed.setPlace(c, Place(name: "Tate Modern", latitude: 51.50761, longitude: -0.09941))
        clock = TestCalendar.date(2026, 11, 4, 9)
        let d = try timed.createEntry(title: "D", day: timed.today)
        timed.setPlace(d, Place(name: "Secret", latitude: 1, longitude: 1))
        timed.trash(d)
        #expect(timed.recentPlaces().map(\.name) == ["Tate Modern", "Kew Gardens"])
        #expect(timed.entriesWithPlaces().count == 3)
    }

    @Test("Duplicating an entry keeps its place and mood")
    func duplicate() throws {
        let entry = try store.createEntry(title: "Swim", day: store.today)
        store.setMood(entry, .good)
        store.setPlace(entry, Place(name: "Hampstead Ponds", latitude: 51.56, longitude: -0.16))
        let copy = try #require(store.duplicate(entry))
        #expect(copy.place == entry.place && copy.mood == entry.mood)
    }

    @Test("A photo's GPS is read for the offer, and the stored photo still carries none")
    func photoCoordinate() async throws {
        let data = try PhotoProcessorTests.photoWithGPS()
        let coordinate = try #require(PhotoProcessor.capturedCoordinate(in: data))
        #expect(abs(coordinate.latitude - 51.5007) < 0.0001 && abs(coordinate.longitude + 0.1246) < 0.0001)
        let processed = try await PhotoProcessor().process(data)
        #expect(PhotoProcessor.capturedCoordinate(in: processed.imageData) == nil)
        #expect(try PhotoProcessorTests.properties(of: processed.imageData)[kCGImagePropertyGPSDictionary] == nil)
    }

    @Test("Drafts keep the place; a place change is an unsaved change")
    func drafts() throws {
        let draft = ComposerDraft(entryID: nil, dayKey: "2026-11-11", minutesFromMidnight: nil, title: "T", bodyMarkdown: "",
                                  categoryID: nil, savedAt: .now)
        let placed = draft.withPlace(Place(name: "Kew Gardens", latitude: 51.4787, longitude: -0.2956))
        #expect(!draft.hasSameContent(as: placed))
        let encoded = try JSONEncoder().encode(placed)
        #expect(try JSONDecoder().decode(ComposerDraft.self, from: encoded).place?.name == "Kew Gardens")
    }

    @Test("The offer only appears once and never replaces a chosen place")
    func offer() throws {
        let model = ComposerModel(day: store.today, categoryID: nil, writingFont: .newYork, drafts: DraftStore(directory: .temporaryDirectory.appending(path: UUID().uuidString)))
        model.place = Place(name: "Chosen")
        model.acceptPlaceOffer()
        #expect(model.place?.name == "Chosen" && model.placeOffer == nil)
    }
}
