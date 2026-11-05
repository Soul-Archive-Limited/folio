import Foundation

/// What App Intents need from the running app (Batch J). Set once in `FolioApp.init`, which
/// also runs when Siri or Shortcuts launch Folio in the background.
@MainActor
enum AppServices {
    static var store: DiaryStore?
}
