import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Bindable var session: WorkoutSession

    @Environment(\.modelContext) private var context
    @Environment(WorkoutCoordinator.self) private var coordinator
    @AppStorage("restSeconds") private var restSeconds = 90
    @AppStorage("weightUnit") private var unit: WeightUnit = .kg

    @State private var lastTime: [String: [SetEntry]] = [:]
    @State private var confirmFinish = false
    @State private var confirmDiscard = false
    @State private var prMessage: String?
    @State private var completedTick = 0

    private var groups: [ExerciseGroup] { session.exerciseGroups() }
    private var completedCount: Int { session.completedSets.count }
    private var totalCount: Int { (session.sets ?? []).count }

    var body: some View {
        NavigationStack {
            List {
                header
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))

                ForEach(groups) { group in
                    Section {
                        SetHeaderRow(unit: unit)
                        ForEach(group.sets) { set in
                            SetRow(set: set, unit: unit) { toggle(set) }
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(group.sets[index]) }
                        }
                        Button {
                            WorkoutService.addSet(to: session, exercise: group, in: context)
                        } label: {
                            Label("Add set", systemImage: "plus")
                                .font(.subheadline.weight(.medium))
                        }
                        .buttonStyle(.borderless)
                    } header: {
                        ExerciseHeader(name: group.name, last: lastTime[group.name] ?? [], unit: unit)
                    }
                    .listRowBackground(Theme.surface)
                }
            }
            .themedList()
            .navigationTitle(session.routineName)
            .inlineTitle()
            .toolbar { toolbar }
            .safeAreaInset(edge: .bottom) {
                RestTimerBar(timer: coordinator.restTimer, defaultSeconds: restSeconds)
            }
            .overlay(alignment: .top) {
                if let prMessage {
                    PRToast(message: prMessage)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.35), value: prMessage)
            .animation(.easeInOut(duration: 0.2), value: coordinator.restTimer.isRunning)
            .sensoryFeedback(.impact(weight: .light), trigger: completedTick)
            .sensoryFeedback(.success, trigger: coordinator.restTimer.finishedCount)
            .confirmationDialog("Finish workout?", isPresented: $confirmFinish, titleVisibility: .visible) {
                Button("Finish workout") { finish() }
                Button("Keep going", role: .cancel) {}
            } message: {
                if completedCount == 0 {
                    Text("No sets are ticked off, so nothing will be saved.")
                } else if completedCount < totalCount {
                    Text("\(totalCount - completedCount) unticked sets will be left out.")
                }
            }
            .confirmationDialog("Discard this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard workout", role: .destructive) { discard() }
            } message: {
                Text("Nothing from this session will be saved.")
            }
            .task { loadLastTime() }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Duration").font(.caption).foregroundStyle(Theme.secondary)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(Format.clock(context.date.timeIntervalSince(session.startedAt)))
                        .font(.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText())
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Sets").font(.caption).foregroundStyle(Theme.secondary)
                Text("\(completedCount)/\(totalCount)")
                    .font(.title2.weight(.semibold).monospacedDigit())
            }
        }
        .padding(.horizontal, 4)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Menu {
                Button("Hide", systemImage: "chevron.down") { coordinator.isPresented = false }
                Button("Discard workout", systemImage: "trash", role: .destructive) { confirmDiscard = true }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Finish") { confirmFinish = true }
                .fontWeight(.semibold)
        }
    }

    private func loadLastTime() {
        var result: [String: [SetEntry]] = [:]
        for group in groups {
            result[group.name] = WorkoutService.lastSessionSets(for: group.name, excluding: session, in: context)
        }
        lastTime = result
    }

    private func toggle(_ set: SetEntry) {
        if set.isCompleted {
            set.isCompleted = false
            set.isPersonalBest = false
            return
        }
        set.isCompleted = true
        set.completedAt = .now
        completedTick += 1

        if let previous = PersonalBests.previousBest(for: set.exerciseName, excluding: session, in: context),
           set.weight > previous {
            let otherSets = session.completedSets.filter { $0 !== set && $0.exerciseName == set.exerciseName }
            let bestToday = otherSets.map(\.weight).max() ?? 0
            if set.weight > bestToday {
                for other in otherSets { other.isPersonalBest = false }
                set.isPersonalBest = true
                showPR("\(set.exerciseName) · \(Format.weight(set.weight, unit))")
            }
        }

        coordinator.restTimer.start(seconds: restSeconds)
        try? context.save()
    }

    private func showPR(_ message: String) {
        prMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if prMessage == message { prMessage = nil }
        }
    }

    private func finish() {
        guard !session.completedSets.isEmpty else {
            discard()
            return
        }
        WorkoutService.finish(session, in: context)
        coordinator.showSummary(for: session)
    }

    private func discard() {
        let target = session
        coordinator.endWithoutSummary()
        WorkoutService.discard(target, in: context)
    }
}

private struct SetHeaderRow: View {
    let unit: WeightUnit
    var body: some View {
        HStack {
            Text("SET").frame(width: 32, alignment: .leading)
            Text(unit.symbol.uppercased()).frame(maxWidth: .infinity)
            Text("REPS").frame(maxWidth: .infinity)
            Color.clear.frame(width: 36, height: 1)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Theme.tertiary)
    }
}

private struct SetRow: View {
    @Bindable var set: SetEntry
    let unit: WeightUnit
    let onToggle: () -> Void

    var body: some View {
        HStack {
            ZStack {
                if set.isPersonalBest {
                    Image(systemName: "trophy.fill").foregroundStyle(Theme.pr)
                } else {
                    Text("\(set.setNumber)").foregroundStyle(Theme.secondary)
                }
            }
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .frame(width: 32, alignment: .leading)

            NumberField(value: $set.weight, placeholder: unit.symbol)
                .padding(.vertical, 8)
                .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            NumberField(value: $set.reps.asDouble, placeholder: "reps", allowsDecimal: false)
                .padding(.vertical, 8)
                .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button(action: onToggle) {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.isCompleted ? Color.accentColor : Theme.tertiary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.borderless)
            .frame(width: 36)
            .accessibilityLabel(set.isCompleted ? "Mark set \(set.setNumber) not done" : "Complete set \(set.setNumber)")
        }
        .opacity(set.isCompleted ? 0.75 : 1)
    }
}

private struct ExerciseHeader: View {
    let name: String
    let last: [SetEntry]
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.headline)
                .foregroundStyle(.primary)
                .textCase(nil)
            Text(last.isEmpty ? "First time" : "Last: " + last.map(Format.set).joined(separator: ", ") + " \(unit.symbol)")
                .font(.caption)
                .foregroundStyle(Theme.secondary)
                .textCase(nil)
                .lineLimit(1)
        }
        .padding(.top, 6)
    }
}

private struct PRToast: View {
    let message: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "trophy.fill")
            VStack(alignment: .leading, spacing: 0) {
                Text("New personal best").font(.caption.weight(.bold))
                Text(message).font(.subheadline.weight(.semibold))
            }
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.pr, in: Capsule())
        .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
    }
}

struct RestTimerBar: View {
    let timer: RestTimer
    let defaultSeconds: Int

    var body: some View {
        if let end = timer.endDate {
            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                let remaining = max(0, end.timeIntervalSince(context.date))
                let progress = timer.total > 0 ? remaining / timer.total : 0
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        Button("−15") { timer.adjust(by: -15) }
                            .buttonStyle(.bordered)
                        Spacer()
                        VStack(spacing: 0) {
                            Text("Rest").font(.caption).foregroundStyle(Theme.secondary)
                            Text(Format.clock(remaining.rounded(.up)))
                                .font(.system(size: 28, weight: .semibold, design: .rounded).monospacedDigit())
                        }
                        Spacer()
                        Button("+15") { timer.adjust(by: 15) }
                            .buttonStyle(.bordered)
                        Button("Skip") { timer.stop() }
                            .buttonStyle(.borderedProminent)
                            .foregroundStyle(.black)
                    }
                    ProgressView(value: progress)
                        .tint(.accentColor)
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
