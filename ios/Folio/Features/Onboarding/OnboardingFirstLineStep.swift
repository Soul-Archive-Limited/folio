import PhotosUI
import SwiftUI

/// Step 2, the interactive moment (docs/ONBOARDING.md): write one line or pick today's photo,
/// and watch it fly into today's square. It saves a real first entry for today.
struct OnboardingFirstLineStep: View {
    let onContinue: () -> Void

    @Environment(DiaryStore.self) private var store
    @Environment(OnboardingModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var text = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var photo: UIImage?
    @State private var landed = false
    @State private var saveCount = 0
    @FocusState private var focused: Bool
    @Namespace private var flight

    var body: some View {
        VStack(spacing: Spacing.l) {
            OnboardingHeading(title: "Start with today", subtitle: "One line, or a photo from today. You can always add more.")
                .padding(.top, Spacing.m)
            // The field sits above the month, so it stays clear of the keyboard; the month below
            // is where the line lands once the keyboard has gone.
            if landed {
                Label("It's on your calendar.", systemImage: "checkmark.circle.fill")
                    .folioFont(.headline)
                    .foregroundStyle(.ink)
                    .symbolRenderingMode(.multicolor)
                    .frame(minHeight: 56)
                    .transition(.opacity)
            } else {
                composer
                    .padding(.horizontal, Spacing.xl)
            }
            OnboardingMiniMonth(today: store.today, firstWeekday: store.settings().firstWeekday ?? store.calendar.firstWeekday) {
                if landed { landedMarker }
            }
            .padding(.horizontal, Spacing.xl)
            .contentShape(.rect)
            .onTapGesture { focused = false }
            Spacer(minLength: 0)
            VStack(spacing: Spacing.xs) {
                if landed {
                    OnboardingPrimaryButton(title: "Continue", action: onContinue)
                } else {
                    OnboardingPrimaryButton(title: "Add to today", isEnabled: canAdd, action: add)
                    Button("Not now", action: onContinue)
                        .foregroundStyle(.inkSecondary)
                        .frame(minHeight: Spacing.minHitTarget)
                }
            }
            .padding(.horizontal, Spacing.xxl)
        }
        .padding(.bottom, Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // A tap outside the field puts the keyboard away; it lives behind the step, so it never
        // takes a tap meant for the field or a button.
        .background {
            Color.clear.contentShape(.rect).onTapGesture {
                focused = false
                KeyboardDismissal.dismiss()
            }
        }
        .onDisappear { focused = false }
        .onChange(of: photoItem) { _, item in loadPhoto(item) }
        .folioHaptic(.success, trigger: saveCount)
    }

    private var canAdd: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || photoData != nil
    }

    /// The line (and photo) before it flies; the same geometry lands in today's square.
    private var composer: some View {
        HStack(spacing: Spacing.s) {
            if let photo {
                Image(uiImage: photo).resizable().scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(.rect(cornerRadius: Radius.dayCell))
                    .accessibilityLabel("Today's photo")
            }
            TextField("One line about today…", text: $text)
                .frame(maxWidth: .infinity, minHeight: 56)
                .contentShape(.rect)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit { focused = false }
                .folioFont(.body)
                .accessibilityIdentifier("onboarding.firstLine")
            PhotosPicker(selection: $photoItem, matching: .images) { PhotoPickerGlyph() }
            .accessibilityLabel("Pick today's photo")
        }
        .padding(.leading, Spacing.m)
        .padding(.trailing, Spacing.xxs)
        .frame(minHeight: 56)
        // Plain glass, not interactive: interactive glass took the tap meant for the field, and
        // keys typed then reached the focused button instead (a space "pressed" Not now).
        .folioGlass(in: .rect(cornerRadius: Radius.card))
        .matchedGeometryEffect(id: "first", in: flight, isSource: !landed)
    }

    /// What sits in today's square after landing: the photo tile, or an ember page dot.
    private var landedMarker: some View {
        Group {
            if let photo {
                Image(uiImage: photo).resizable().scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.dayCell / 2).fill(.ember.opacity(0.18))
                    Circle().fill(.ember).frame(width: 6, height: 6).offset(y: 9)
                }
            }
        }
        .clipShape(.rect(cornerRadius: Radius.dayCell / 2))
        .matchedGeometryEffect(id: "first", in: flight, isSource: landed)
        .accessibilityHidden(true)
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            photoData = data
            photo = EntryShareImages.uiImage(data, maxPixel: 400)
        }
    }

    private func add() {
        focused = false
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let entry = try store.createEntry(body: line, day: store.today)
            model.firstEntryID = entry.id
            if let photoData {
                Task {
                    if let processed = try? await PhotoProcessor().process(photoData) { _ = try? store.addPhoto(processed, to: entry) }
                }
            }
            saveCount += 1
            withAnimation(reduceMotion ? FolioMotion.reduced : .spring(duration: 0.6, bounce: 0.25)) { landed = true }
        } catch {
            // The entry couldn't be saved; stay on the step so nothing is lost.
        }
    }
}

/// The photo button's glyph (its own view: the picker's label closure is `Sendable`).
private struct PhotoPickerGlyph: View {
    var body: some View {
        Image(systemName: "photo.badge.plus")
            .font(.title3)
            .foregroundStyle(.ember)
            .frame(width: Spacing.minHitTarget, height: Spacing.minHitTarget)
    }
}

/// A small, real month with today marked — the landing place for the first line.
struct OnboardingMiniMonth<Marker: View>: View {
    let today: DayKey
    let firstWeekday: Int
    @ViewBuilder let marker: () -> Marker

    var body: some View {
        let month = today.monthKey
        let days = month.gridDays(firstWeekday: firstWeekday)
        let rows = days.chunked(7).filter { $0.contains { $0.monthKey == month } }
        VStack(spacing: Spacing.s) {
            Text(month.firstDay.utcDate, format: Date.FormatStyle(timeZone: .gmt).month(.wide).year())
                .folioFont(.headline)
                .foregroundStyle(.ink)
            VStack(spacing: 4) {
                ForEach(rows.indices, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(rows[row], id: \.self) { day in
                            cell(day, inMonth: day.monthKey == month)
                        }
                    }
                }
            }
        }
        .padding(Spacing.s)
        .folioGlass(in: .rect(cornerRadius: Radius.card))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("This month, with today marked"))
    }

    private func cell(_ day: DayKey, inMonth: Bool) -> some View {
        let isToday = day == today
        return ZStack {
            if isToday { marker() }
            Text(day.day, format: .number)
                .font(.caption.weight(isToday ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(isToday ? AnyShapeStyle(.emberText) : inMonth ? AnyShapeStyle(.ink) : AnyShapeStyle(.inkTertiary))
                .opacity(inMonth ? 1 : 0.5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .overlay {
            if isToday { RoundedRectangle(cornerRadius: Radius.dayCell / 2).strokeBorder(.ember, lineWidth: 1.5) }
        }
    }
}

extension Array {
    func chunked(_ size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
