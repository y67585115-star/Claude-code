import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct AddPhotosSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date.now
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var prepared: [PreparedPhoto] = []
    @State private var isLoading = false
    @State private var showingFileImporter = false

    struct PreparedPhoto: Identifiable {
        let id = UUID()
        let full: Data
        let thumb: Data?
        let preview: CGImage?
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date)
                } footer: {
                    Text("Every photo added here is tagged with this date.")
                }

                Section {
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 20, matching: .images) {
                        Label("Choose from Photos", systemImage: "photo.on.rectangle")
                    }
                    Button {
                        showingFileImporter = true
                    } label: {
                        Label("Choose files", systemImage: "folder")
                    }
                }

                if isLoading || !prepared.isEmpty {
                    Section("\(prepared.count) selected") {
                        if isLoading { ProgressView().frame(maxWidth: .infinity) }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(prepared) { photo in
                                    ZStack(alignment: .topTrailing) {
                                        Group {
                                            if let preview = photo.preview {
                                                Image(decorative: preview, scale: 1).resizable().scaledToFill()
                                            } else {
                                                Theme.surface
                                            }
                                        }
                                        .frame(width: 84, height: 112)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                        Button {
                                            prepared.removeAll { $0.id == photo.id }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .symbolRenderingMode(.palette)
                                                .foregroundStyle(.white, .black.opacity(0.6))
                                        }
                                        .buttonStyle(.plain)
                                        .padding(4)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .themedList()
            .navigationTitle("Add photos")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(prepared.isEmpty || isLoading)
                }
            }
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await loadPickerItems(items) }
            }
            .fileImporter(isPresented: $showingFileImporter,
                          allowedContentTypes: [.image],
                          allowsMultipleSelection: true) { result in
                if case .success(let urls) = result {
                    Task { await loadFiles(urls) }
                }
            }
        }
    }

    @MainActor
    private func loadPickerItems(_ items: [PhotosPickerItem]) async {
        isLoading = true
        defer { isLoading = false; pickerItems = [] }
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            await add(data)
        }
    }

    @MainActor
    private func loadFiles(_ urls: [URL]) async {
        isLoading = true
        defer { isLoading = false }
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            let data = try? Data(contentsOf: url)
            if scoped { url.stopAccessingSecurityScopedResource() }
            if let data { await add(data) }
        }
    }

    @MainActor
    private func add(_ data: Data) async {
        guard let result = await ImageUtil.prepare(data) else { return }
        let preview = await ImageUtil.decode(result.thumb ?? result.full, maxPixel: 240)
        prepared.append(PreparedPhoto(full: result.full, thumb: result.thumb, preview: preview))
    }

    private func save() {
        // Keep the chosen day but stagger seconds so order within the day is stable.
        let base = Calendar.current.startOfDay(for: date).addingTimeInterval(12 * 3600)
        for (index, photo) in prepared.enumerated() {
            let entry = ProgressPhoto(date: base, imageData: photo.full, thumbnailData: photo.thumb)
            entry.createdAt = Date.now.addingTimeInterval(TimeInterval(index))
            context.insert(entry)
        }
        try? context.save()
        dismiss()
    }
}
