import SwiftUI
import SwiftData

struct PhotosView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\ProgressPhoto.date, order: .reverse),
                  SortDescriptor(\ProgressPhoto.createdAt, order: .reverse)])
    private var photos: [ProgressPhoto]

    @State private var showingAdd = false
    @State private var isComparing = false
    @State private var selection: [ProgressPhoto] = []
    @State private var openPhoto: ProgressPhoto?
    @State private var comparePair: ComparePair?

    private let columns = [GridItem(.adaptive(minimum: 104, maximum: 200), spacing: 4)]

    private var days: [(day: Date, photos: [ProgressPhoto])] {
        let calendar = Calendar.current
        return Dictionary(grouping: photos) { calendar.startOfDay(for: $0.date) }
            .map { (day: $0.key, photos: $0.value) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        NavigationStack {
            Group {
                if photos.isEmpty {
                    EmptyStateView(
                        title: "No progress photos",
                        systemImage: "photo.on.rectangle.angled",
                        message: "Add photos and tag them with a date. Pick any two later to compare them side by side."
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 18, pinnedViews: [.sectionHeaders]) {
                            ForEach(days, id: \.day) { day in
                                Section {
                                    LazyVGrid(columns: columns, spacing: 4) {
                                        ForEach(day.photos) { photo in
                                            thumbnail(photo)
                                        }
                                    }
                                } header: {
                                    Text(day.day.formatted(date: .complete, time: .omitted))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 6)
                                        .background(Theme.background)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, isComparing ? 90 : 12)
                    }
                }
            }
            .background(Theme.background)
            .navigationTitle(isComparing ? "Pick two photos" : "Photos")
            .toolbar { toolbar }
            .safeAreaInset(edge: .bottom) {
                if isComparing { compareBar }
            }
            .navigationDestination(item: $openPhoto) { PhotoDetailView(photo: $0) }
            .navigationDestination(item: $comparePair) { CompareView(pair: $0) }
            .sheet(isPresented: $showingAdd) {
                AddPhotosSheet().macSheetSize(width: 520, height: 560)
            }
        }
    }

    private func thumbnail(_ photo: ProgressPhoto) -> some View {
        let index = selection.firstIndex(of: photo)
        return Button {
            if isComparing { toggleSelection(photo) } else { openPhoto = photo }
        } label: {
            Color.clear
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay { PhotoImage(photo: photo) }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if isComparing {
                        ZStack {
                            Circle()
                                .fill(index != nil ? Color.accentColor : Color.black.opacity(0.4))
                                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                            if let index {
                                Text("\(index + 1)").font(.caption.weight(.bold)).foregroundStyle(.black)
                            }
                        }
                        .frame(width: 24, height: 24)
                        .padding(6)
                    }
                }
                .overlay {
                    if index != nil {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.accentColor, lineWidth: 3)
                    }
                }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete", systemImage: "trash", role: .destructive) {
                selection.removeAll { $0 == photo }
                context.delete(photo)
                try? context.save()
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if photos.count >= 2 {
            ToolbarItem(placement: .cancellationAction) {
                Button(isComparing ? "Cancel" : "Compare") {
                    isComparing.toggle()
                    selection = []
                }
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button { showingAdd = true } label: { Label("Add photos", systemImage: "plus") }
                .disabled(isComparing)
        }
    }

    private var compareBar: some View {
        HStack {
            Text(selection.count == 2 ? "Ready to compare" : "\(selection.count) of 2 selected")
                .foregroundStyle(Theme.secondary)
            Spacer()
            Button("Compare") {
                guard selection.count == 2 else { return }
                let sorted = selection.sorted { $0.date < $1.date }
                comparePair = ComparePair(before: sorted[0], after: sorted[1])
                isComparing = false
                selection = []
            }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(.black)
            .disabled(selection.count != 2)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    private func toggleSelection(_ photo: ProgressPhoto) {
        if let index = selection.firstIndex(of: photo) {
            selection.remove(at: index)
        } else {
            if selection.count == 2 { selection.removeFirst() }
            selection.append(photo)
        }
    }
}

struct ComparePair: Hashable {
    let before: ProgressPhoto
    let after: ProgressPhoto
}

struct CompareView: View {
    let pair: ComparePair

    private var daysApart: Int {
        let calendar = Calendar.current
        return abs(calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: pair.before.date),
                                           to: calendar.startOfDay(for: pair.after.date)).day ?? 0)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 8) {
                side(pair.before, label: "Before")
                side(pair.after, label: "After")
            }
            Text(daysApart == 0 ? "Same day" : "\(daysApart) days apart")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.secondary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Theme.background)
        .navigationTitle("Compare")
        .inlineTitle()
    }

    private func side(_ photo: ProgressPhoto, label: String) -> some View {
        VStack(spacing: 8) {
            PhotoImage(photo: photo, thumbnail: false, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(spacing: 0) {
                Text(label.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(Theme.tertiary)
                Text(photo.date.formatted(date: .abbreviated, time: .omitted)).font(.subheadline.weight(.semibold))
            }
        }
    }
}

struct PhotoDetailView: View {
    @Bindable var photo: ProgressPhoto
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        VStack(spacing: 12) {
            PhotoImage(photo: photo, thumbnail: false, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            DatePicker("Tagged date", selection: $photo.date, in: ...Date.now, displayedComponents: .date)
                .card(padding: 12)
        }
        .padding(12)
        .background(Theme.background)
        .navigationTitle(photo.date.formatted(date: .abbreviated, time: .omitted))
        .inlineTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .confirmationDialog("Delete this photo?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete photo", role: .destructive) {
                let target = photo
                dismiss()
                context.delete(target)
                try? context.save()
            }
        }
    }
}
