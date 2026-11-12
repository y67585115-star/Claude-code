import Foundation

/// Streak = completed workouts in a row, measured against the planned schedule.
///
/// Walking back from today, every day with a workout adds to the streak. A planned day
/// with no workout ends the streak. Rest days (not planned) never break it, and today
/// gets a grace period because the day is not over yet.
enum Streak {
    static func compute(
        workoutDates: [Date],
        plannedWeekdays: Set<Int>,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        guard !workoutDates.isEmpty else { return 0 }

        var countsByDay: [Date: Int] = [:]
        for date in workoutDates {
            countsByDay[calendar.startOfDay(for: date), default: 0] += 1
        }

        // No schedule means there is no planned day to miss.
        if plannedWeekdays.isEmpty { return workoutDates.count }

        let today = calendar.startOfDay(for: now)
        guard let earliest = countsByDay.keys.min() else { return 0 }

        var streak = 0
        var day = today
        while day >= earliest {
            let done = countsByDay[day] ?? 0
            let isPlanned = plannedWeekdays.contains(calendar.component(.weekday, from: day))
            if done > 0 {
                streak += done
            } else if isPlanned && day != today {
                break
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
}
