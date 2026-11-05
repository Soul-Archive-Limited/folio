import AVFoundation
import PhotosUI
import SwiftUI

/// "Scan a page" (Batch J): scan paper diary pages or pick photos of them, check the text and
/// the date found on the page, then save a new entry.
struct ScanSheet: View {
    @State private var model: ScanModel
    @State private var showsCamera = false
    @State private var showsExplainer = false
    @State private var showsDenied = false
    @State private var picked: [PhotosPickerItem] = []
    @Environment(DiaryStore.self) private var store
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.tabRouter) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    init(today: DayKey) {
        _model = State(initialValue: ScanModel(today: today))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch model.phase {
                case .choosing: choosing
                case .reading:
                    ProgressView("Reading your pages…").frame(maxWidth: .infinity, maxHeight: .infinity)
                case .review: ScanReview(model: model)
                }
            }
            .background { AuraBackground() }
            .navigationTitle("Bring in a page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                if model.phase == .review {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { Task { await save() } }
                            .buttonStyle(.glassProminent)
                            .tint(.emberStrong)
                            .disabled(model.isSaving)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showsCamera) {
            DocumentCamera { pages in
                showsCamera = false
                Task { await model.read(pages, today: store.today) }
            }
            .ignoresSafeArea()
            .privacyCovered()
        }
        .sheet(isPresented: $showsExplainer) {
            PermissionExplainer(systemImage: "doc.viewfinder",
                                message: "Folio uses the camera only while you scan a page. The text is read on your iPhone.",
                                onContinue: requestCamera)
        }
        .alert("Camera is off for Folio", isPresented: $showsDenied) {
            Button("Open Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("You can still choose photos of your pages.")
        }
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var pages: [Data] = []
                for item in items { if let data = try? await item.loadTransferable(type: Data.self) { pages.append(data) } }
                picked = []
                await model.read(pages, today: store.today)
            }
        }
        #if DEBUG
        .task {
            // `-FolioScanSample /path/page.jpg`: read a sample page (the Simulator has no document camera).
            if let path = DebugLaunchOptions.string("FolioScanSample"), let data = FileManager.default.contents(atPath: path) {
                await model.read([data], today: store.today)
            }
        }
        #endif
    }

    private var choosing: some View {
        // Read here: the PhotosPicker label closure is Sendable.
        let height = Spacing.minHitTarget
        return VStack(spacing: Spacing.m) {
            Image(systemName: "doc.text.viewfinder").font(.system(size: 52)).foregroundStyle(.ember)
            Text("Move your paper diary in, a page at a time. The text is read on your iPhone; the scan is kept as a photo.")
                .folioFont(.callout)
                .foregroundStyle(.inkSecondary)
                .multilineTextAlignment(.center)
            if DocumentCamera.isAvailable {
                Button { scanTapped() } label: {
                    Label("Scan pages", systemImage: "doc.viewfinder").frame(maxWidth: .infinity, minHeight: Spacing.minHitTarget)
                }
                .buttonStyle(.glassProminent)
                .tint(.emberStrong)
            }
            PhotosPicker(selection: $picked, maxSelectionCount: Entry.maximumPhotos, matching: .images) {
                Label("Choose photos of pages", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity, minHeight: height)
            }
            .buttonStyle(.glass)
        }
        .padding(Spacing.l)
        .frame(maxHeight: .infinity)
    }

    private func scanTapped() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: showsCamera = true
        case .notDetermined: showsExplainer = true
        default: showsDenied = true
        }
    }

    private func requestCamera() {
        showsExplainer = false
        Task {
            if await AVCaptureDevice.requestAccess(for: .video) { showsCamera = true } else { showsDenied = true }
        }
    }

    private func save() async {
        guard let entry = await model.save(to: store), let day = entry.day else { return }
        dismiss()
        let label = day.utcDate.formatted(Date.FormatStyle(timeZone: .gmt).weekday(.abbreviated).day().month(.abbreviated).year())
        toasts.show(ToastMessage(text: "Saved to \(label)", undo: ToastUndo(title: "Show") { router?.open(.day(day)) }))
    }
}
