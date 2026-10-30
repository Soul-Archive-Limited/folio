import SwiftUI

/// Circular crop for a chosen photo (Batch I): drag to move, pinch to zoom, then Use photo.
/// The result is a 256 px JPEG, small enough to sync inside the encrypted settings record.
struct AvatarCropView: View {
    let image: UIImage
    let onDone: (Data) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scale = 1.0
    @State private var committedScale = 1.0
    @State private var offset = CGSize.zero
    @State private var committedOffset = CGSize.zero

    static let outputSize: Double = 256
    private let diameter: Double = 280

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.l) {
                Spacer()
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: diameter, height: diameter)
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: diameter, height: diameter)
                        .clipShape(.circle)
                    Circle().strokeBorder(.white.opacity(0.9), lineWidth: 2)
                }
                .frame(width: diameter, height: diameter)
                .contentShape(.circle)
                .gesture(drag.simultaneously(with: pinch))
                .accessibilityLabel("Photo crop")
                .accessibilityHint("Drag to move, pinch to zoom")
                Text("Drag to move · pinch to zoom")
                    .folioFont(.callout)
                    .foregroundStyle(.inkSecondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background { AuraBackground() }
            .navigationTitle("Move and scale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use photo") {
                        if let data = render() { onDone(data) }
                        dismiss()
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.emberStrong)
                }
            }
        }
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(width: committedOffset.width + value.translation.width,
                                height: committedOffset.height + value.translation.height)
            }
            .onEnded { _ in committedOffset = clamped(offset, scale: scale); withAnimation(.snappy) { offset = committedOffset } }
    }

    private var pinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in scale = min(max(committedScale * value.magnification, 1), 5) }
            .onEnded { _ in
                committedScale = scale
                committedOffset = clamped(offset, scale: scale)
                withAnimation(.snappy) { offset = committedOffset }
            }
    }

    /// Keeps the photo covering the whole circle.
    private func clamped(_ offset: CGSize, scale: Double) -> CGSize {
        let limit = diameter * (scale - 1) / 2
        return CGSize(width: min(max(offset.width, -limit), limit), height: min(max(offset.height, -limit), limit))
    }

    /// Draws exactly what the circle shows into a square, then to JPEG.
    private func render() -> Data? {
        let size = CGSize(width: Self.outputSize, height: Self.outputSize)
        let ratio = Self.outputSize / diameter
        let imageSize = image.size
        let fill = max(diameter / imageSize.width, diameter / imageSize.height) * scale * ratio
        let drawn = CGSize(width: imageSize.width * fill, height: imageSize.height * fill)
        let origin = CGPoint(x: (size.width - drawn.width) / 2 + offset.width * ratio,
                             y: (size.height - drawn.height) / 2 + offset.height * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let output = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: origin, size: drawn))
        }
        return output.jpegData(compressionQuality: 0.8)
    }
}
