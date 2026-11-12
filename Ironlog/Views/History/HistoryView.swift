import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("weightUnit") private var unit: WeightUnit = .kg

    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt != nil },
           sort: \WorkoutSession.startedAt, order: .reverse)
    private var sessions: [WorkoutSession]

    private var months: [(month: Date, sessions: [WorkoutSession])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) {
            calendar.dateInterval(of: .month, for: $0.startedAt)?.start ?? $0.startedAt
        }
        return grouped
            .map { (month: $0.key, sessions: $0.value) }
            .sorted { $0.month > $1.month }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    EmptyStateView(
                        title: "No workouts yet",
                        systemImage: "clock.arrow.circlepath",
                        message: "Finished workouts show up here with their duration, sets and weights."
                    )
                } else {
                    List {
                        ForEach(months, id: \.month) { month in
                            Section {
                                ForEach(month.sessions) { session in
                                    NavigationLink(value: session) {
                                        SessionRow(session: session, unit: unit)
                                    }
                                }
                                .onDelete { offsets in delete(offsets.map { month.sessions[$0] }) }
                            } header: {
                                HStack {
                                    Text(month.month.formatted(.dateTime.month(.wide).year()))
                                    Spacer()
                                    Text("\(month.sessions.count) workouts")
                                }
                            }
                            .listRowBackground(Theme.surface)
                        }
                    }
                }
            }
            .themedList()
            .navigationTitle("History")
            .navigationDestination(for: WorkoutSession.self) { SessionDetailView(session: $0) }
        }
    }

    private func delete(_ targets: [WorkoutSession]) {
        for session in targets { context.delete(session) }
        try? context.save()
        PersonalBests.recompute(in: context)
    }
}

private struct SessionRow: View {
    let session: WorkoutSession
    let unit: WeightUnit

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 0) {
                Text(session.startedAt.formatted(.dateTime.day()))
                    .font(.title3.weight(.semibold).monospacedDigit())
                Text(session.startedAt.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.secondary)
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(session.routineName).font(.headline)
                    if session.personalBestCount > 0 { PRBadge(compact: true) }
                }
                Text("\(Format.duration(session.duration)) · \(session.completedSets.count) sets · \(Format.weight(session.volume, unit))")
                    .font(.caption)
                    .foregroundStyle(Theme.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SessionDetailView: View {
    let session: WorkoutSession
    @AppStorage("weightUnit") private var unit: WeightUnit = .kg

    var body: some View {
        List {
            Section {
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        StatTile(title: "Duration", value: Format.duration(session.duration), systemImage: "timer")
                        StatTile(title: "Sets", value: "\(session.completedSets.count)", systemImage: "list.number")
                        StatTile(title: "Volume", value: Format.weight(session.volume), caption: unit.symbol, systemImage: "scalemass")
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } footer: {
                Text("\(session.startedAt.formatted(date: .complete, time: .shortened)) – \((session.endedAt ?? session.startedAt).formatted(date: .omitted, time: .shortened))")
            }

            ForEach(session.exerciseGroups(completedOnly: true)) { group in
                Section {
                    ForEach(group.sets) { set in
                        HStack {
                            Text("\(set.setNumber)")
                                .foregroundStyle(Theme.secondary)
                                .frame(width: 28, alignment: .leading)
                            Text("\(Format.weight(set.weight)) \(unit.symbol)")
                                .monospacedDigit()
                            Spacer()
                            Text("\(set.reps) reps")
                                .monospacedDigit()
                                .foregroundStyle(Theme.secondary)
                            if set.isPersonalBest { PRBadge(compact: true) }
                        }
                    }
                } header: {
                    NavigationLink {
                        ExerciseProgressView(name: group.name)
                    } label: {
                        HStack {
                            Text(group.name).font(.headline).foregroundStyle(.primary).textCase(nil)
                            Image(systemName: "chart.xyaxis.line").font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(Theme.surface)
            }
        }
        .themedList()
        .navigationTitle(session.routineName)
        .inlineTitle()
    }
}
