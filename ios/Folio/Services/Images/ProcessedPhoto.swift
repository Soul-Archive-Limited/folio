import Foundation

/// A photo ready to store: metadata-free full image plus a small thumbnail (SPEC §5).
nonisolated struct ProcessedPhoto: Sendable, Equatable {
    let imageData: Data
    let thumbnailData: Data
    let pixelWidth: Int
    let pixelHeight: Int
    /// "public.heic", or "public.jpeg" where the device can't encode HEIC.
    let imageType: String
}
