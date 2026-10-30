import SwiftUI

/// Folio's 24 avatars ("page spirits", Batch I). The art is vector SVG in the asset catalog,
/// generated with the web's copies by `scripts/avatars/generate.py`.
nonisolated enum FolioAvatar {
    static let count = 24
    static let names = ["Spark", "Margin", "Doodle", "Pebble", "Sunny", "Ink", "Bloom", "Tide", "Moss", "Plume", "Comet",
                        "Ember", "Echo", "Clover", "Dusk", "Maple", "Quill", "Fig", "Ripple", "Honey", "Pip", "Fern", "Nova", "Petal"]

    /// The settings value for avatar `number` (1…24): "folio:07".
    static func key(_ number: Int) -> String { String(format: "folio:%02d", number) }

    /// The avatar number in a settings value, or nil.
    static func number(from key: String?) -> Int? {
        guard let key, key.hasPrefix("folio:"), let n = Int(key.dropFirst(6)), (1...count).contains(n) else { return nil }
        return n
    }

    static func assetName(_ number: Int) -> String { String(format: "avatar-%02d", number) }
    static func name(_ number: Int) -> String { names[(number - 1) % names.count] }
}

/// The profile picture wherever it shows: a Folio avatar, the chosen photo, or the monogram.
struct ProfileAvatar: View {
    var size: Double = 64

    @Environment(DiaryStore.self) private var store

    var body: some View {
        let settings = store.settings()
        Group {
            if let number = FolioAvatar.number(from: settings.avatar) {
                Image(FolioAvatar.assetName(number))
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel(Text("Avatar: \(FolioAvatar.name(number))"))
            } else if settings.avatar == "photo", let data = settings.avatarPhoto, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(.circle)
                    .overlay { Circle().strokeBorder(.hairline, lineWidth: 1) }
                    .accessibilityLabel("Profile photo")
            } else {
                Monogram(name: settings.displayName, size: size)
            }
        }
        .frame(width: size, height: size)
    }
}
