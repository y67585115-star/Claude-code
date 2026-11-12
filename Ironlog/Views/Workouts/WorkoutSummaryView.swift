import SwiftUI

struct WorkoutSummaryView: View {
    let session: WorkoutSession
    let onDone: () -> Void
    @AppStorage("weightUnit") private var unit: WeightUnit = .kg

    private var prs: [SetEntry] {
        session.completedSets.filter(\.isPersonalBest).sorted { $0.exerciseOrder < $1.exerciseOrder }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 24)
                    VStack(spacing: 4) {
                        Text("Workout complete").font(.title2.weight(.semibold))
                        Text(session.routineName).foregroundStyle(Theme.secondary)
                    }

                    Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                        GridRow {
                            StatTile(title: "Duration", value: Format.duration(session.duration), systemImage: "timer")
                            StatTile(title: "Sets", value: "\(session.completedSets.count)", systemImage: "list.number")
                        }
                        GridRow {
                            StatTile(title: "Volume", value: Format.weight(session.volume, unit), systemImage: "scalemass")
                            StatTile(title: "PRs", value: "\(prs.count)", systemImage: "trophy")
                        }
                    }

                    if !prs.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Personal bests").font(.headline)
                            ForEach(prs) { set in
                                HStack {
                                    Image(systemName: "trophy.fill").foregroundStyle(Theme.pr)
                                    Text(set.exerciseName)
                                    Spacer()
                                    Text(Format.weight(set.weight, unit)).monospacedDigit()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                    }
                }
                .padding()
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone).fontWeight(.semibold)
                }
            }
        }
    }
}
