import Foundation

/// A photo ready to store (SPEC §5), metadata-free in three renditions: the full image,
/// a 1080 px "display" rendition for cards and grids, and a 240 px thumbnail for day cells.
nonisolated struct ProcessedPhoto: Sendable, Equatable {
    let imageData: Data
    let thumbnailData: Data
    let pixelWidth: Int
    let pixelHeight: Int
    /// "public.heic", or "public.jpeg" where the device can't encode HEIC.
    let imageType: String
    /// 1080 px long-edge HEIC (~150 KB). Empty only for photos made before it existed.
    var displayData = Data()
}
