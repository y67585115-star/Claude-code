import Foundation
import SwiftData

// CloudKit-backed SwiftData rules: every attribute needs a default (or is optional),
// every relationship is optional with an inverse, and nothing is marked unique.

@Model
final class Routine {
    var name: String = ""
    var createdAt: Date = Date.now
    var sortOrder: Int = 0
    /// Planned training days as a bitmask. Bit `weekday - 1`, where weekday follows
    /// `Calendar` (1 = Sunday ... 7 = Saturday).
    var scheduleMask: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \RoutineExercise.routine)
    var exercises: [RoutineExercise]? = []

    @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.routine)
    var sessions: [WorkoutSession]? = []

    init(name: String = "", sortOrder: Int = 0) {
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = .now
    }

    var orderedExercises: [RoutineExercise] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }

    var plannedWeekdays: Set<Int> {
        Set((1...7).filter { scheduleMask & (1 << ($0 - 1)) != 0 })
    }

    func isPlanned(weekday: Int) -> Bool {
        scheduleMask & (1 << (weekday - 1)) != 0
    }

    var displayName: String {
        name.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled routine" : name
    }
}

@Model
final class RoutineExercise {
    var name: String = ""
    var order: Int = 0
    var targetSets: Int = 3
    var routine: Routine?

    init(name: String, order: Int, targetSets: Int = 3) {
        self.name = name
        self.order = order
        self.targetSets = targetSets
    }
}

@Model
final class WorkoutSession {
    var startedAt: Date = Date.now
    /// `nil` while the workout is in progress.
    var endedAt: Date?
    /// Snapshot of the routine name so history survives renames and deletes.
    var routineName: String = ""
    var routine: Routine?

    @Relationship(deleteRule: .cascade, inverse: \SetEntry.session)
    var sets: [SetEntry]? = []

    init(routineName: String) {
        self.startedAt = .now
        self.routineName = routineName
    }

    var isFinished: Bool { endedAt != nil }

    var duration: TimeInterval {
        (endedAt ?? .now).timeIntervalSince(startedAt)
    }

    var completedSets: [SetEntry] {
        (sets ?? []).filter(\.isCompleted)
    }

    var volume: Double {
        completedSets.reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    var personalBestCount: Int {
        completedSets.filter(\.isPersonalBest).count
    }

    /// Sets grouped by exercise in routine order.
    func exerciseGroups(completedOnly: Bool = false) -> [ExerciseGroup] {
        let source = completedOnly ? completedSets : (sets ?? [])
        let grouped = Dictionary(grouping: source, by: \.exerciseName)
        return grouped.map { name, sets in
            ExerciseGroup(
                name: name,
                order: sets.map(\.exerciseOrder).min() ?? 0,
                sets: sets.sorted { $0.setNumber < $1.setNumber }
            )
        }
        .sorted { ($0.order, $0.name) < ($1.order, $1.name) }
    }
}

struct ExerciseGroup: Identifiable {
    var id: String { name }
    let name: String
    let order: Int
    let sets: [SetEntry]
}

@Model
final class SetEntry {
    var exerciseName: String = ""
    var exerciseOrder: Int = 0
    var setNumber: Int = 1
    var reps: Int = 0
    var weight: Double = 0
    var isCompleted: Bool = false
    var completedAt: Date = Date.distantPast
    var isPersonalBest: Bool = false
    var session: WorkoutSession?

    init(exerciseName: String, exerciseOrder: Int, setNumber: Int, reps: Int, weight: Double) {
        self.exerciseName = exerciseName
        self.exerciseOrder = exerciseOrder
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
    }
}

@Model
final class BodyweightEntry {
    var date: Date = Date.now
    var weight: Double = 0

    init(date: Date, weight: Double) {
        self.date = date
        self.weight = weight
    }
}

@Model
final class ProgressPhoto {
    /// The day the photo is tagged with (user editable).
    var date: Date = Date.now
    var createdAt: Date = Date.now
    @Attribute(.externalStorage) var imageData: Data?
    @Attribute(.externalStorage) var thumbnailData: Data?

    init(date: Date, imageData: Data, thumbnailData: Data?) {
        self.date = date
        self.createdAt = .now
        self.imageData = imageData
        self.thumbnailData = thumbnailData
    }
}

enum WeightUnit: String, CaseIterable, Identifiable {
    case kg, lb
    var id: String { rawValue }
    var symbol: String { rawValue }
}
