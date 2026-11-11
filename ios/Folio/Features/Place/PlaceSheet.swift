import CoreLocation
import MapKit
import SwiftUI

/// Choosing an entry's place (Batch N): search any place with Apple Maps autocomplete, use the
/// current location (asked only the first time it's tapped, after Folio's explainer), pick a
/// recent place, or remove it. Nothing here runs until the person asks.
struct PlaceSheet: View {
    @Binding var place: Place?

    @Environment(DiaryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var search = PlaceSearch()
    @State private var locator: LocationOnce?
    @State private var showsExplainer = false
    @State private var showsDenied = false
    @State private var isLocating = false
    @State private var resolving: MKLocalSearchCompletion?
    @State private var problem: LocalizedStringKey?

    var body: some View {
        NavigationStack {
            List {
                if search.query.trimmingCharacters(in: .whitespaces).isEmpty {
                    startRows
                } else {
                    resultRows
                }
            }
            .scrollContentBackground(.hidden)
            .searchable(text: $search.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search places")
            .navigationTitle("Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", role: .cancel) { dismiss() } }
            }
            .sensoryFeedback(.selection, trigger: place)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showsExplainer) {
            PermissionExplainer(
                systemImage: "location",
                message: "Folio looks up where you are once, to name this entry's place. It never follows you or runs in the background.",
                footnote: "Approximate location is fine.",
                onContinue: requestAccess
            )
        }
        .alert("Location is off for Folio", isPresented: $showsDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("You can turn it on in Settings, or search for the place instead.")
        }
    }

    // MARK: Rows

    @ViewBuilder private var startRows: some View {
        Section {
            Button(action: useCurrentLocation) {
                HStack {
                    Label("Current location", systemImage: "location")
                    Spacer()
                    if isLocating { ProgressView() }
                }
            }
            .disabled(isLocating)
            .accessibilityIdentifier("place.current")
            if let problem {
                Text(problem).folioFont(.callout).foregroundStyle(.inkSecondary)
            }
        } footer: {
            Text("Searches go to Apple Maps. The place is kept end-to-end encrypted with this entry.")
        }
        let recents = store.recentPlaces().filter { recent in place.map { !recent.isSame(as: $0) } ?? true }
        if !recents.isEmpty {
            Section("Recent") {
                ForEach(recents, id: \.self) { recent in
                    Button { choose(recent) } label: { PlaceRowLabel(name: recent.name, detail: recent.address) }
                }
            }
        }
        if let place {
            Section {
                Button("Remove place", image: .folioTrash, role: .destructive) {
                    self.place = nil
                    dismiss()
                }
                .accessibilityHint(Text("Removes \(place.name) from this entry"))
            }
        }
    }

    @ViewBuilder private var resultRows: some View {
        if search.failed {
            Text("Couldn't search right now. Check your connection and try again.")
                .folioFont(.callout).foregroundStyle(.inkSecondary)
        }
        ForEach(search.completions, id: \.self) { completion in
            Button { resolve(completion) } label: {
                HStack {
                    PlaceRowLabel(name: completion.title, detail: completion.subtitle.isEmpty ? nil : completion.subtitle)
                    Spacer()
                    if resolving == completion { ProgressView() }
                }
            }
            .disabled(resolving != nil)
        }
        // A name of its own, when nothing on the map fits (a friend's flat, "the old bench").
        let typed = search.query.trimmingCharacters(in: .whitespacesAndNewlines)
        Button { choose(Place(name: typed)) } label: {
            Label("Use \u{201C}\(typed)\u{201D}", image: .folioPlace)
        }
    }

    // MARK: Actions

    private func choose(_ chosen: Place) {
        guard let clean = chosen.validated() else { return }
        place = clean
        dismiss()
    }

    private func resolve(_ completion: MKLocalSearchCompletion) {
        resolving = completion
        Task {
            let found = await PlaceResolver.place(for: completion)
            resolving = nil
            if let found { choose(found) } else { choose(Place(name: completion.title, address: completion.subtitle)) }
        }
    }

    private func useCurrentLocation() {
        problem = nil
        let locator = locator ?? LocationOnce()
        self.locator = locator
        switch locator.status {
        case .notDetermined: showsExplainer = true
        case .denied, .restricted: showsDenied = true
        default: Task { await locate(with: locator) }
        }
    }

    private func requestAccess() {
        showsExplainer = false
        guard let locator else { return }
        Task {
            switch await locator.requestAuthorization() {
            case .authorizedWhenInUse, .authorizedAlways: await locate(with: locator)
            default: break
            }
        }
    }

    private func locate(with locator: LocationOnce) async {
        isLocating = true
        defer { isLocating = false }
        do {
            let location = try await locator.locate()
            if let found = await PlaceResolver.place(at: location, approximate: locator.isApproximate) {
                choose(found)
            } else {
                problem = "Couldn't name where you are. Try searching instead."
            }
        } catch LocationOnce.Failure.denied {
            showsDenied = true
        } catch {
            problem = "Couldn't find where you are. Try searching instead."
        }
    }
}

/// A place's name with its address under it.
struct PlaceRowLabel: View {
    let name: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).folioFont(.body).foregroundStyle(.ink)
            if let detail { Text(detail).folioFont(.callout).foregroundStyle(.inkSecondary) }
        }
        .accessibilityElement(children: .combine)
    }
}
