import SwiftUI

/// All photos in a 3-column masonry (SPEC §6.6). Each photo goes to the shortest column,
/// so columns stay balanced; tapping opens its entry.
struct JournalPhotoGrid: View {
    let photos: [EntryPhoto]
    let zoom: Namespace.ID

    var body: some View {
        if photos.isEmpty {
            EmptyStateView(systemImage: "photo.on.rectangle", message: "No photos yet.")
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        } else {
            HStack(alignment: .top, spacing: 6) {
                ForEach(Array(Self.columns(for: photos).enumerated()), id: \.offset) { _, column in
                    LazyVStack(spacing: 6) {
                        ForEach(column, id: \.id) { photo in
                            if let entryID = photo.entry?.id {
                                NavigationLink(value: entryID) {
                                    FullPhotoImage(photoID: photo.id, rendition: .display, maxPixel: 600, cornerRadius: 12)
                                        .aspectRatio(Self.aspect(photo), contentMode: .fit)
                                        .matchedTransitionSource(id: entryID, in: zoom)
                                }
                                .buttonStyle(.pressable)
                                .accessibilityLabel(photo.entry?.title.isEmpty == false ? photo.entry?.title ?? "" : "Photo")
                            }
                        }
                    }
                }
            }
        }
    }

    static func aspect(_ photo: EntryPhoto) -> Double {
        guard photo.pixelHeight > 0 else { return 1 }
        return Double(photo.pixelWidth) / Double(photo.pixelHeight)
    }

    /// Greedy shortest-column placement by height-to-width ratio.
    static func columns(for photos: [EntryPhoto], count: Int = 3) -> [[EntryPhoto]] {
        var columns = Array(repeating: [EntryPhoto](), count: count)
        var heights = Array(repeating: 0.0, count: count)
        for photo in photos {
            let index = heights.indices.min { heights[$0] < heights[$1] } ?? 0
            columns[index].append(photo)
            heights[index] += 1 / aspect(photo) + 0.05
        }
        return columns
    }
}
