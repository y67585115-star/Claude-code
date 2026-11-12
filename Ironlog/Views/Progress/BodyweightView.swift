import SwiftUI
import SwiftData
import Charts

struct BodyweightView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("weightUnit") private var unit: WeightUnit = .kg
    @Query(sort: \BodyweightEntry.date) private var entries: [BodyweightEntry]
    @State private var showingAdd = false
    @State private var range: ChartRange = .quarter

    private var visible: [BodyweightEntry] {
        guard let start = range.startDate else { return entries }
        return entries.filter { $0.date >= start }
    }

    var body: some View {
        List {
            Section {
                Picker("Range", selection: $range) {
                    ForEach(ChartRange.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if visible.count < 2 {
                    Text(entries.isEmpty ? "Log your bodyweight to start the chart." : "Log at least two entries in this range to see a trend.")
                        .foregroundStyle(Theme.secondary)
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else {
                    Chart(visible) { entry in
                        LineMark(x: .value("Date", entry.date), y: .value("Weight", entry.weight))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Color.accentColor)
                        PointMark(x: .value("Date", entry.date), y: .value("Weight", entry.weight))
                            .foregroundStyle(Color.accentColor)
                            .symbolSize(20)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 220)
                    .padding(.vertical, 8)
                }
            }
            .listRowBackground(Theme.surface)

            Section("Entries") {
                ForEach(entries.reversed()) { entry in
                    HStack {
                        Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        Spacer()
                        Text(Format.weight(entry.weight, unit)).monospacedDigit()
                    }
                }
                .onDelete { offsets in
                    let reversed = Array(entries.reversed())
                    for index in offsets { context.delete(reversed[index]) }
                    try? context.save()
                }
            }
            .listRowBackground(Theme.surface)
        }
        .themedList()
        .navigationTitle("Bodyweight")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: { Label("Log bodyweight", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $showingAdd) {
            BodyweightEntrySheet().macSheetSize(width: 380, height: 300)
        }
    }
}

struct BodyweightEntrySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("weightUnit") private var unit: WeightUnit = .kg
    @Query(sort: \BodyweightEntry.date, order: .reverse) private var entries: [BodyweightEntry]

    @State private var date = Date.now
    @State private var weight: Double = 0
    @State private var didPrefill = false

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date)
                HStack {
                    Text("Weight")
                    Spacer()
                    NumberField(value: $weight, placeholder: "0")
                        .frame(width: 100)
                        .padding(.vertical, 6)
                        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 8))
                    Text(unit.symbol).foregroundStyle(Theme.secondary)
                }
            }
            .formStyle(.grouped)
            .themedList()
            .navigationTitle("Log bodyweight")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        context.insert(BodyweightEntry(date: date, weight: weight))
                        try? context.save()
                        dismiss()
                    }
                    .disabled(weight <= 0)
                }
            }
            .onAppear {
                guard !didPrefill else { return }
                didPrefill = true
                weight = entries.first?.weight ?? 0
            }
        }
        .presentationDetents([.medium])
    }
}
