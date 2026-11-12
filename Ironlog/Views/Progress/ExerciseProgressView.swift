import SwiftUI
import SwiftData
import Charts

struct ExerciseProgressView: View {
    let name: String
    @AppStorage("weightUnit") private var unit: WeightUnit = .kg
    @Query private var sets: [SetEntry]
    @State private var range: ChartRange = .all
    @State private var selectedDate: Date?

    init(name: String) {
        self.name = name
        _sets = Query(
            filter: #Predicate<SetEntry> { $0.exerciseName == name && $0.isCompleted == true },
            sort: \SetEntry.completedAt
        )
    }

    struct Point: Identifiable {
        let id: PersistentIdentifier
        let date: Date
        let top: Double
        let isPR: Bool
        let sets: [SetEntry]
    }

    private var points: [Point] {
        let finished = sets.filter { $0.session?.endedAt != nil }
        return Dictionary(grouping: finished) { $0.session!.persistentModelID }
            .map { id, sets in
                Point(
                    id: id,
                    date: sets.first?.session?.startedAt ?? .distantPast,
                    top: sets.map(\.weight).max() ?? 0,
                    isPR: sets.contains(where: \.isPersonalBest),
                    sets: sets.sorted { $0.setNumber < $1.setNumber }
                )
            }
            .sorted { $0.date < $1.date }
    }

    private var visible: [Point] {
        guard let start = range.startDate else { return points }
        return points.filter { $0.date >= start }
    }

    private var selectedPoint: Point? {
        guard let selectedDate else { return nil }
        return visible.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }

    var body: some View {
        List {
            Section {
                Grid(horizontalSpacing: 10) {
                    GridRow {
                        StatTile(title: "Best", value: Format.weight(points.map(\.top).max() ?? 0), caption: unit.symbol, systemImage: "trophy.fill")
                        StatTile(title: "Last", value: Format.weight(points.last?.top ?? 0), caption: unit.symbol, systemImage: "clock")
                        StatTile(title: "Change", value: change, caption: range.label, systemImage: "arrow.up.right")
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                Picker("Range", selection: $range) {
                    ForEach(ChartRange.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if visible.isEmpty {
                    Text("No workouts in this range.")
                        .foregroundStyle(Theme.secondary)
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    chart.frame(height: 240).padding(.vertical, 8)
                }
            } header: {
                Text("Top set weight")
            }
            .listRowBackground(Theme.surface)

            Section("Workouts") {
                ForEach(points.reversed()) { point in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(point.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline.weight(.medium))
                            if point.isPR { PRBadge(compact: true) }
                            Spacer()
                            Text(Format.weight(point.top, unit))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                        }
                        Text(point.sets.map(Format.set).joined(separator: "  ·  "))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
            .listRowBackground(Theme.surface)
        }
        .themedList()
        .navigationTitle(name)
    }

    private var chart: some View {
        Chart {
            ForEach(visible) { point in
                AreaMark(x: .value("Date", point.date), y: .value("Weight", point.top))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(
                        LinearGradient(colors: [Color.accentColor.opacity(0.25), .clear],
                                       startPoint: .top, endPoint: .bottom)
                    )
                LineMark(x: .value("Date", point.date), y: .value("Weight", point.top))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                PointMark(x: .value("Date", point.date), y: .value("Weight", point.top))
                    .foregroundStyle(point.isPR ? Theme.pr : Color.accentColor)
                    .symbolSize(point.isPR ? 90 : 28)
            }
            if let selected = selectedPoint {
                RuleMark(x: .value("Date", selected.date))
                    .foregroundStyle(Theme.tertiary)
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(spacing: 2) {
                            Text(Format.weight(selected.top, unit)).font(.caption.weight(.bold))
                            Text(selected.date.formatted(.dateTime.month().day())).font(.caption2)
                        }
                        .padding(6)
                        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 6))
                    }
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXSelection(value: $selectedDate)
    }

    private var change: String {
        guard let first = visible.first, let last = visible.last, visible.count > 1 else { return "—" }
        let delta = last.top - first.top
        return (delta >= 0 ? "+" : "") + Format.weight(delta)
    }
}

enum ChartRange: String, CaseIterable, Identifiable {
    case month = "1M", quarter = "3M", half = "6M", year = "1Y", all = "All"
    var id: String { rawValue }

    var startDate: Date? {
        let calendar = Calendar.current
        switch self {
        case .month: return calendar.date(byAdding: .month, value: -1, to: .now)
        case .quarter: return calendar.date(byAdding: .month, value: -3, to: .now)
        case .half: return calendar.date(byAdding: .month, value: -6, to: .now)
        case .year: return calendar.date(byAdding: .year, value: -1, to: .now)
        case .all: return nil
        }
    }

    var label: String {
        switch self {
        case .month: "past month"
        case .quarter: "past 3 months"
        case .half: "past 6 months"
        case .year: "past year"
        case .all: "all time"
        }
    }
}
