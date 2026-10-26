import AVFoundation
import SwiftUI

/// Camera (SPEC §6.4, §7): a one-line glass explainer before the system prompt, the
/// prompt only at first use, and a gentle "Open Settings" path if access was denied.
struct ComposerCameraButton: View {
    @Bindable var model: ComposerModel

    @State private var showsExplainer = false
    @State private var showsCamera = false
    @State private var showsDenied = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button("Camera", systemImage: "camera", action: tap)
            .disabled(!CameraPicker.isAvailable || model.remainingPhotoSlots == 0)
            .accessibilityHint(CameraPicker.isAvailable ? "" : "This device has no camera")
            .sheet(isPresented: $showsExplainer) {
                PermissionExplainer(
                    systemImage: "camera",
                    message: "Folio uses the camera only when you choose to take a photo for an entry.",
                    onContinue: requestAccess
                )
            }
            .fullScreenCover(isPresented: $showsCamera) {
                CameraPicker { data in
                    Task { await model.addPhoto(data: data) }
                }
                .ignoresSafeArea()
                .privacyCovered()
            }
            .alert("Camera is off for Folio", isPresented: $showsDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                Button("Not now", role: .cancel) {}
            } message: {
                Text("You can turn it on in Settings whenever you'd like to take photos for entries.")
            }
    }

    private func tap() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: showsCamera = true
        case .notDetermined: showsExplainer = true
        default: showsDenied = true
        }
    }

    private func requestAccess() {
        showsExplainer = false
        Task {
            if await AVCaptureDevice.requestAccess(for: .video) { showsCamera = true } else { showsDenied = true }
        }
    }
}
