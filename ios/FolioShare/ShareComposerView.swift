import SwiftUI

/// The share sheet's mini composer (Batch J): what's coming in, an optional line, the day,
/// a category, and "Add to that day's page" when there is one.
struct ShareComposerView: View {
    @Bindable var model: ShareModel
    let onFinish: (Bool) -> Void

    var body: some View {
        NavigationStack {
            Form {
                if model.isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    preview
                    Section {
                        TextField("Title (optional)", text: $model.title)
                        TextField("Add a line…", text: $model.note, axis: .vertical).lineLimit(2...6)
                    }
                    Section {
                        DatePicker("Day", selection: $model.day, in: ...Date.now.addingTimeInterval(86_400), displayedComponents: .date)
                        if model.dayHasPage {
                            Toggle("Add to that day's page", isOn: $model.appendsToDay)
                        }
                        if let categories = model.context?.categories, !categories.isEmpty {
                            Picker("Category", selection: $model.categoryID) {
                                Text("None").tag(UUID?.none)
                                ForEach(categories) { Text($0.name).tag(Optional($0.id)) }
                            }
                        }
                    } footer: {
                        Text("Saved encrypted on this iPhone. Folio adds it to your diary the next time it opens.")
                    }
                    if let problem = model.problem {
                        Section { Text(problem).foregroundStyle(.red) }
                    }
                }
            }
            .navigationTitle("Folio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onFinish(false) } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { if model.save() { onFinish(true) } }
                        .disabled(model.isLoading || !model.hasContent)
                }
            }
        }
        .tint(Color(red: 0.94, green: 0.38, blue: 0.16))
    }

    @ViewBuilder private var preview: some View {
        if !model.previews.isEmpty {
            Section("^[\(model.previews.count) photo](inflect: true)") {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(Array(model.previews.enumerated()), id: \.offset) { _, image in
                            Image(uiImage: image).resizable().scaledToFill().frame(width: 72, height: 72).clipShape(.rect(cornerRadius: 12))
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        if let link = model.link {
            Section("Link") { Label(link.host() ?? link.absoluteString, systemImage: "link").lineLimit(1) }
        }
        if !model.text.isEmpty {
            Section("Text") { Text(model.text).lineLimit(6).font(.system(.body, design: .serif)) }
        }
    }
}
