import SwiftUI
import SwiftData
import Charts

struct ProgressTabView: View {
    @AppStorage("weightUnit") private var unit: WeightUnit = .kg

    @Query(filter: #Predicate<SetEntry> { $0.isCompleted == true },
           sort: \SetEntry.completedAt, order: .reverse)
    private var allSets: [SetEntry]

    @Query(sort: \BodyweightEntry.date)
    private var bodyweights: [BodyweightEntry]

    private var finishedSets: [SetEntry] {
        allSets.filter { $0.session?.endedAt != nil }
    }

    private var exercises: [(name: String, best: Double, last: Date, sessions: Int)] {
        Dictionary(grouping: finishedSets, by: \.exerciseName)
            .map { name, sets in
                (name: name,
                 best: sets.map(\.weight).max() ?? 0,
                 last: sets.map(\.completedAt).max() ?? Date.distantPast,
                 sessions: Set(sets.compactMap { $0.session?.persistentModelID }).count)
            }
            .sorted { $0.last > $1.last }
    }

    private var recentPRs: [SetEntry] {
        Array(finishedSets.filter(\.isPersonalBest).prefix(8))
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Bodyweight") {
                    NavigationLink {
                        BodyweightView()
                    } label: {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(bodyweights.last.map { Format.weight($0.weight, unit) } ?? "No entries")
                                    .font(.title3.weight(.semibold).monospacedDigit())
                                if let change = bodyweightChange {
                                    Text("\(change >= 0 ? "+" : "")\(Format.weight(change)) \(unit.symbol) in 30 days")
                                        .font(.caption)
                                        .foregroundStyle(Theme.secondary)
                                }
                            }
                            Spacer()
                            if bodyweights.count > 1 {
                                Chart(bodyweights.suffix(30)) {
                                    LineMark(x: .value("Date", $0.date), y: .value("Weight", $0.weight))
                                        .interpolationMethod(.monotone)
                                }
                                .chartXAxis(.hidden)
                                .chartYAxis(.hidden)
                                .chartYScale(domain: .automatic(includesZero: false))
                                .frame(width: 110, height: 36)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listRowBackground(Theme.surface)

                if !recentPRs.isEmpty {
                    Section("Recent personal bests") {
                        ForEach(recentPRs) { set in
                            NavigationLink {
                                ExerciseProgressView(name: set.exerciseName)
                            } label: {
                                HStack {
                                    Image(systemName: "trophy.fill").foregroundStyle(Theme.pr)
                                    VStack(alignment: .leading) {
                                        Text(set.exerciseName)
                                        Text(set.completedAt.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption)
                                            .foregroundStyle(Theme.secondary)
                                    }
                                    Spacer()
                                    Text(Format.weight(set.weight, unit)).monospacedDigit()
                                }
                            }
                        }
                    }
                    .listRowBackground(Theme.surface)
                }

                Section("Exercises") {
                    if exercises.isEmpty {
                        Text("Finish a workout to see a chart for each exercise.")
                            .foregroundStyle(Theme.secondary)
                    }
                    ForEach(exercises, id: \.name) { exercise in
                        NavigationLink {
                            ExerciseProgressView(name: exercise.name)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                    Text("\(exercise.sessions) workouts")
                                        .font(.caption)
                                        .foregroundStyle(Theme.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(Format.weight(exercise.best, unit))
                                        .font(.body.weight(.semibold).monospacedDigit())
                                    Text("best").font(.caption2).foregroundStyle(Theme.tertiary)
                                }
                            }
                        }
                    }
                }
                .listRowBackground(Theme.surface)
            }
            .themedList()
            .navigationTitle("Progress")
        }
    }

    private var bodyweightChange: Double? {
        guard let latest = bodyweights.last else { return nil }
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: latest.date) ?? latest.date
        guard let baseline = bodyweights.first(where: { $0.date >= cutoff }), baseline !== latest else { return nil }
        return latest.weight - baseline.weight
    }
}
