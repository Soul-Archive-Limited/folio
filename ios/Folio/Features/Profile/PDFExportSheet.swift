import PDFKit
import SwiftUI

/// Profile → Your data → Export PDF (Batch J): pick a range, make the book on the device with
/// progress, preview it, then share or print.
struct PDFExportSheet: View {
    @Environment(DiaryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var options: DiaryPDF.Options
    @State private var progress: Double?
    @State private var result: DiaryPDF.Result?
    @State private var problem: String?
    @State private var work: Task<Void, Never>?

    init(today: DayKey) {
        _options = State(initialValue: DiaryPDF.Options(from: DayKey(year: today.year, month: 1, day: 1) ?? today, through: today))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let result {
                    PDFPreview(url: result.url)
                        .ignoresSafeArea(edges: .bottom)
                        .safeAreaInset(edge: .bottom) { actions(result) }
                } else {
                    form
                }
            }
            .navigationTitle(result == nil ? "Export PDF" : "Your diary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(progress != nil && result == nil ? "Stop" : "Done") { work?.cancel(); dismiss() }
                }
            }
        }
        .onDisappear { work?.cancel() }
    }

    private var form: some View {
        Form {
            Section {
                DatePicker("From", selection: dayBinding(\.from), in: ...options.through.utcDate, displayedComponents: .date)
                DatePicker("Until", selection: dayBinding(\.through), in: options.from.utcDate...store.today.utcDate, displayedComponents: .date)
                Menu("Quick ranges") {
                    let today = store.today
                    Button("This year") { set(DayKey(year: today.year, month: 1, day: 1), today) }
                    Button("Last year") { set(DayKey(year: today.year - 1, month: 1, day: 1), DayKey(year: today.year - 1, month: 12, day: 31)) }
                    Button("Last 3 years") { set(DayKey(year: today.year - 2, month: 1, day: 1), today) }
                    Button("Everything") { set(store.firstYearWritten.flatMap { DayKey(year: $0, month: 1, day: 1) }, today) }
                }
                .tint(.emberStrong)
            } header: { Text("Dates") }
            .environment(\.timeZone, .gmt)
            Section {
                Toggle("Photos", isOn: $options.includesPhotos)
                Toggle("Tasks", isOn: $options.includesTasks)
            } footer: {
                Text("A book of your pages: a cover, a page for each month, then every entry with its formatting. Made on this iPhone; it goes nowhere until you share it.")
            }
            .tint(.emberStrong)
            Section {
                if let progress {
                    ProgressView(value: progress) { Text("Making your diary…") } currentValueLabel: {
                        Text(progress.formatted(.percent.precision(.fractionLength(0))))
                    }
                    .tint(.emberStrong)
                } else {
                    Button("Create PDF", systemImage: "doc.richtext", action: create)
                        .font(.headline)
                        .tint(.emberStrong)
                        .accessibilityIdentifier("pdf.create")
                }
                if let problem { Text(problem).foregroundStyle(.danger) }
            }
        }
        .scrollContentBackground(.hidden)
        .background { AuraBackground() }
    }

    private func actions(_ result: DiaryPDF.Result) -> some View {
        VStack(spacing: Spacing.xs) {
            Text("^[\(result.pageCount) page](inflect: true) · ^[\(result.entryCount) entry](inflect: true)")
                .folioFont(.caption).foregroundStyle(.inkSecondary)
            HStack(spacing: Spacing.s) {
                ShareLink(item: result.url) {
                    Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: Spacing.minHitTarget)
                }
                .buttonStyle(.glassProminent)
                .tint(.emberStrong)
                Button { print(result.url) } label: {
                    Label("Print", systemImage: "printer").frame(maxWidth: .infinity, minHeight: Spacing.minHitTarget)
                }
                .buttonStyle(.glass)
            }
        }
        .padding(.horizontal, Spacing.sideMargin)
        .padding(.vertical, Spacing.s)
        .background(.bar)
    }

    private func create() {
        problem = nil
        progress = 0
        let container = store.context.container
        let options = options
        // Keeps going briefly if Folio is sent to the background mid-way.
        let background = UIApplication.shared.beginBackgroundTask(withName: "Folio PDF")
        work = Task {
            defer { UIApplication.shared.endBackgroundTask(background) }
            let made = await Task.detached(priority: .userInitiated) { () -> Swift.Result<DiaryPDF.Result, any Error> in
                Swift.Result {
                    try DiaryPDF.render(container: container, options: options) { value in
                        Task { @MainActor in if self.progress != nil { self.progress = value } }
                    }
                }
            }.value
            switch made {
            case .success(let made): withAnimation(FolioMotion.standard()) { result = made }
            case .failure(DiaryPDF.Failure.nothingInRange): problem = String(localized: "Nothing written in these dates.")
            case .failure(DiaryPDF.Failure.cancelled): break
            case .failure: problem = String(localized: "Couldn't make the PDF. Try a shorter range.")
            }
            progress = nil
        }
    }

    private func print(_ url: URL) {
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo.printInfo()
        info.jobName = url.deletingPathExtension().lastPathComponent
        info.outputType = .general
        controller.printInfo = info
        controller.printingItem = url
        controller.present(animated: true)
    }

    private func set(_ from: DayKey?, _ through: DayKey?) {
        guard let from, let through else { return }
        options.from = from
        options.through = through
    }

    private func dayBinding(_ keyPath: WritableKeyPath<DiaryPDF.Options, DayKey>) -> Binding<Date> {
        Binding { options[keyPath: keyPath].utcDate } set: { options[keyPath: keyPath] = DayKey(date: $0, calendar: DayKey.arithmeticCalendar) }
    }
}

/// PDFKit's view for the preview.
struct PDFPreview: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .secondarySystemBackground
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url { view.document = PDFDocument(url: url) }
    }
}
