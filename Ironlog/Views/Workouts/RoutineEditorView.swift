import SwiftUI
import SwiftData

struct RoutineEditorView: View {
    @Bindable var routine: Routine
    @Environment(\.modelContext) private var context
    @Environment(WorkoutCoordinator.self) private var coordinator

    @State private var newExercise = ""
    @FocusState private var addFieldFocused: Bool

    var body: some View {
        Form {
            Section("Name") {
                TextField("e.g. Push, Legs, Upper A", text: $routine.name)
                    .font(.headline)
            }

            Section {
                WeekdayPicker(mask: $routine.scheduleMask)
                    .padding(.vertical, 4)
            } header: {
                Text("Planned days")
            } footer: {
                Text("Your streak counts completed workouts. Missing a planned day resets it; rest days never do.")
            }

            Section {
                ForEach(routine.orderedExercises) { exercise in
                    ExerciseEditRow(exercise: exercise)
                }
                .onDelete(perform: delete)
                .onMove(perform: move)

                HStack {
                    TextField("Add exercise", text: $newExercise)
                        .focused($addFieldFocused)
                        .onSubmit(addExercise)
                    Button(action: addExercise) {
                        Image(systemName: "plus.circle.fill").font(.title3)
                    }
                    .buttonStyle(.borderless)
                    .disabled(trimmedNewExercise.isEmpty)
                }
            } header: {
                Text("Exercises")
            } footer: {
                Text("You'll log sets, reps and weight for each exercise. Your last weight is filled in for you.")
            }

            if !routine.orderedExercises.isEmpty {
                Section {
                    Button {
                        let session = WorkoutService.start(routine: routine, in: context)
                        coordinator.present(session)
                    } label: {
                        Label("Start workout", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(.black)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
        }
        .formStyle(.grouped)
        .themedList()
        .navigationTitle(routine.displayName)
        .inlineTitle()
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .primaryAction) { EditButton() }
            #endif
        }
        .onDisappear(perform: cleanUp)
    }

    private var trimmedNewExercise: String {
        newExercise.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addExercise() {
        let name = trimmedNewExercise
        guard !name.isEmpty else { return }
        let exercise = RoutineExercise(
            name: name,
            order: (routine.orderedExercises.map(\.order).max() ?? -1) + 1
        )
        context.insert(exercise)
        exercise.routine = routine
        newExercise = ""
        addFieldFocused = true
    }

    private func delete(at offsets: IndexSet) {
        let current = routine.orderedExercises
        for index in offsets { context.delete(current[index]) }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = routine.orderedExercises
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, exercise) in reordered.enumerated() { exercise.order = index }
    }

    /// Drop routines that were created and left completely empty.
    private func cleanUp() {
        guard routine.modelContext != nil else { return }
        if routine.name.trimmingCharacters(in: .whitespaces).isEmpty,
           (routine.exercises ?? []).isEmpty,
           (routine.sessions ?? []).isEmpty {
            context.delete(routine)
        }
        try? context.save()
    }
}

private struct ExerciseEditRow: View {
    @Bindable var exercise: RoutineExercise

    var body: some View {
        HStack {
            TextField("Exercise", text: $exercise.name)
            Stepper(value: $exercise.targetSets, in: 1...20) {
                Text("\(exercise.targetSets) sets")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.secondary)
            }
            .fixedSize()
        }
    }
}
