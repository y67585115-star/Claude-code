import Foundation
import SwiftData

enum PersonalBests {
    /// Heaviest completed weight for an exercise across finished workouts, ignoring `excluded`.
    static func previousBest(
        for name: String,
        excluding excluded: WorkoutSession?,
        in context: ModelContext
    ) -> Double? {
        let descriptor = FetchDescriptor<SetEntry>(
            predicate: #Predicate { $0.exerciseName == name && $0.isCompleted == true }
        )
        guard let sets = try? context.fetch(descriptor) else { return nil }
        let excludedID = excluded?.persistentModelID
        return sets
            .filter { set in
                guard let session = set.session else { return false }
                return session.endedAt != nil && session.persistentModelID != excludedID
            }
            .map(\.weight)
            .max()
    }

    /// Rebuilds every PR flag from scratch, in chronological order. A set is a PR when it
    /// is the heaviest set of its workout for that exercise and beats every earlier
    /// workout. The first time an exercise is logged sets the baseline and is not flagged.
    static func recompute(in context: ModelContext) {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.endedAt != nil },
            sortBy: [SortDescriptor(\.startedAt)]
        )
        guard let sessions = try? context.fetch(descriptor) else { return }

        var best: [String: Double] = [:]
        var changed = false

        for session in sessions {
            for group in session.exerciseGroups(completedOnly: true) {
                let top = group.sets.max { lhs, rhs in
                    lhs.weight < rhs.weight || (lhs.weight == rhs.weight && lhs.setNumber > rhs.setNumber)
                }
                let previous = best[group.name]
                for set in group.sets {
                    let flag = set === top
                        && previous != nil
                        && set.weight > (previous ?? 0)
                    if set.isPersonalBest != flag {
                        set.isPersonalBest = flag
                        changed = true
                    }
                }
                if let top {
                    best[group.name] = max(previous ?? top.weight, top.weight)
                }
            }
        }
        if changed { try? context.save() }
    }
}
