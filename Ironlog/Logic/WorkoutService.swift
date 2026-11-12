import Foundation
import SwiftData

enum WorkoutService {
    static func activeSession(in context: ModelContext) -> WorkoutSession? {
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Starts a workout from a routine, pre-filling each set with what was lifted last time.
    /// If a workout is already running, that one is returned instead.
    @discardableResult
    static func start(routine: Routine, in context: ModelContext) -> WorkoutSession {
        if let active = activeSession(in: context) { return active }

        let session = WorkoutSession(routineName: routine.displayName)
        context.insert(session)
        session.routine = routine

        for exercise in routine.orderedExercises {
            let previous = lastSessionSets(for: exercise.name, excluding: nil, in: context)
            for index in 0..<max(exercise.targetSets, 1) {
                let template = previous.indices.contains(index) ? previous[index] : previous.last
                let set = SetEntry(
                    exerciseName: exercise.name,
                    exerciseOrder: exercise.order,
                    setNumber: index + 1,
                    reps: template?.reps ?? 0,
                    weight: template?.weight ?? 0
                )
                context.insert(set)
                set.session = session
            }
        }
        try? context.save()
        return session
    }

    /// Completed sets for an exercise from the most recent finished workout that included it.
    static func lastSessionSets(
        for name: String,
        excluding excluded: WorkoutSession?,
        in context: ModelContext
    ) -> [SetEntry] {
        let descriptor = FetchDescriptor<SetEntry>(
            predicate: #Predicate { $0.exerciseName == name && $0.isCompleted == true },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        guard let candidates = try? context.fetch(descriptor) else { return [] }
        let excludedID = excluded?.persistentModelID
        guard let session = candidates
            .lazy
            .compactMap(\.session)
            .first(where: { $0.endedAt != nil && $0.persistentModelID != excludedID })
        else { return [] }

        return (session.sets ?? [])
            .filter { $0.exerciseName == name && $0.isCompleted }
            .sorted { $0.setNumber < $1.setNumber }
    }

    /// Appends a set to an exercise, copying the last set's numbers.
    static func addSet(to session: WorkoutSession, exercise group: ExerciseGroup, in context: ModelContext) {
        let last = group.sets.last
        let set = SetEntry(
            exerciseName: group.name,
            exerciseOrder: group.order,
            setNumber: (group.sets.map(\.setNumber).max() ?? 0) + 1,
            reps: last?.reps ?? 0,
            weight: last?.weight ?? 0
        )
        context.insert(set)
        set.session = session
    }

    /// Ends the workout. Unticked sets are dropped. Returns `false` (and deletes the
    /// session) when nothing was logged.
    @discardableResult
    static func finish(_ session: WorkoutSession, in context: ModelContext) -> Bool {
        let logged = session.completedSets
        guard !logged.isEmpty else {
            context.delete(session)
            try? context.save()
            return false
        }
        for set in session.sets ?? [] where !set.isCompleted {
            context.delete(set)
        }
        session.endedAt = .now
        try? context.save()
        PersonalBests.recompute(in: context)
        return true
    }

    static func discard(_ session: WorkoutSession, in context: ModelContext) {
        context.delete(session)
        try? context.save()
    }
}
