import SwiftUI
import SwiftData

struct WorkoutsView: View {
    @Environment(\.modelContext) private var context
    @Environment(WorkoutCoordinator.self) private var coordinator
    @AppStorage("weightUnit") private var unit: WeightUnit = .kg

    @Query(sort: [SortDescriptor(\Routine.sortOrder), SortDescriptor(\Routine.createdAt)])
    private var routines: [Routine]

    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt != nil },
           sort: \WorkoutSession.startedAt, order: .reverse)
    private var finished: [WorkoutSession]

    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt == nil },
           sort: \WorkoutSession.startedAt, order: .reverse)
    private var active: [WorkoutSession]

    @Query(sort: \BodyweightEntry.date, order: .reverse)
    private var bodyweights: [BodyweightEntry]

    @State private var path: [Routine] = []
    @State private var showingSettings = false
    @State private var showingBodyweight = false
    @State private var routineToDelete: Routine?

    private var plannedWeekdays: Set<Int> {
        routines.reduce(into: Set<Int>()) { $0.formUnion($1.plannedWeekdays) }
    }

    private var streak: Int {
        Streak.compute(workoutDates: finished.map(\.startedAt), plannedWeekdays: plannedWeekdays)
    }

    private var thisWeekCount: Int {
        guard let week = Calendar.current.dateInterval(of: .weekOfYear, for: .now) else { return 0 }
        return finished.filter { week.contains($0.startedAt) }.count
    }

    private var todayWeekday: Int { Calendar.current.component(.weekday, from: .now) }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if let session = active.first {
                    Section {
                        ResumeCard(session: session) { coordinator.present(session) }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }

                Section {
                    stats
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

                Section {
                    if routines.isEmpty {
                        Button(action: addRoutine) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Create your first routine").font(.headline)
                                Text("Add exercises, pick your training days, then press Start workout.")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(routines) { routine in
                        NavigationLink(value: routine) {
                            RoutineRow(
                                routine: routine,
                                isToday: routine.isPlanned(weekday: todayWeekday),
                                isDisabled: active.first != nil && active.first?.routine != routine
                            ) {
                                start(routine)
                            }
                        }
                        .contextMenu {
                            Button("Start workout", systemImage: "play.fill") { start(routine) }
                            Button("Delete", systemImage: "trash", role: .destructive) { routineToDelete = routine }
                        }
                    }
                    .onMove(perform: move)
                    .onDelete { offsets in routineToDelete = offsets.first.map { routines[$0] } }
                } header: {
                    HStack {
                        Text("Routines")
                        Spacer()
                        Button(action: addRoutine) {
                            Label("New routine", systemImage: "plus")
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                    }
                }
                .listRowBackground(Theme.surface)
            }
            .themedList()
            .navigationTitle("Workouts")
            .navigationDestination(for: Routine.self) { RoutineEditorView(routine: $0) }
            .toolbar {
                #if os(iOS)
                if !routines.isEmpty {
                    ToolbarItem(placement: .topBarLeading) { EditButton() }
                }
                #endif
                ToolbarItem(placement: .primaryAction) {
                    Button { showingSettings = true } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack { SettingsView() }
                    .macSheetSize(width: 440, height: 380)
            }
            .sheet(isPresented: $showingBodyweight) {
                BodyweightEntrySheet()
                    .macSheetSize(width: 380, height: 300)
            }
            .confirmationDialog(
                "Delete \(routineToDelete?.displayName ?? "routine")?",
                isPresented: Binding(get: { routineToDelete != nil }, set: { if !$0 { routineToDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete routine", role: .destructive) {
                    if let routine = routineToDelete {
                        context.delete(routine)
                        try? context.save()
                    }
                    routineToDelete = nil
                }
            } message: {
                Text("Past workouts stay in your history.")
            }
        }
    }

    private var stats: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                StatTile(
                    title: "Streak",
                    value: "\(streak)",
                    caption: plannedWeekdays.isEmpty
                        ? "Set planned days on a routine"
                        : (streak == 1 ? "workout" : "workouts") + " in a row",
                    systemImage: "flame.fill"
                )
                StatTile(
                    title: "This week",
                    value: "\(thisWeekCount)",
                    caption: thisWeekCount == 1 ? "workout" : "workouts",
                    systemImage: "calendar"
                )
                Button { showingBodyweight = true } label: {
                    StatTile(
                        title: "Bodyweight",
                        value: bodyweights.first.map { Format.weight($0.weight, unit) } ?? "—",
                        caption: bodyweights.first.map { $0.date.formatted(.dateTime.month().day()) } ?? "Tap to log",
                        systemImage: "scalemass.fill"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func start(_ routine: Routine) {
        if let session = active.first {
            coordinator.present(session)
            return
        }
        guard !routine.orderedExercises.isEmpty else {
            path.append(routine)
            return
        }
        let session = WorkoutService.start(routine: routine, in: context)
        coordinator.present(session)
    }

    private func addRoutine() {
        let routine = Routine(sortOrder: (routines.map(\.sortOrder).max() ?? -1) + 1)
        context.insert(routine)
        path.append(routine)
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = routines
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, routine) in reordered.enumerated() where routine.sortOrder != index {
            routine.sortOrder = index
        }
    }
}

private struct RoutineRow: View {
    let routine: Routine
    let isToday: Bool
    let isDisabled: Bool
    let onStart: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(routine.displayName).font(.headline)
                    if isToday {
                        Text("TODAY")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .overlay(Capsule().stroke(Color.accentColor, lineWidth: 1))
                    }
                }
                let names = routine.orderedExercises.map(\.name)
                Text(names.isEmpty ? "No exercises yet" : names.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(2)
                if routine.scheduleMask != 0 {
                    WeekdayDots(mask: routine.scheduleMask)
                }
            }
            Spacer(minLength: 8)
            Button(action: onStart) {
                Label("Start", systemImage: "play.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .foregroundStyle(.black)
            .disabled(isDisabled)
        }
        .padding(.vertical, 6)
    }
}

private struct ResumeCard: View {
    let session: WorkoutSession
    let onResume: () -> Void

    var body: some View {
        Button(action: onResume) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Workout in progress").font(.caption).foregroundStyle(.black.opacity(0.6))
                    Text(session.routineName).font(.headline).foregroundStyle(.black)
                }
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(Format.clock(context.date.timeIntervalSince(session.startedAt)))
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.black)
                }
                Image(systemName: "chevron.right").foregroundStyle(.black.opacity(0.6))
            }
            .padding(16)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
