import SwiftUI

struct SettingsView: View {
    var showsDoneButton = true
    @AppStorage("weightUnit") private var unit: WeightUnit = .kg
    @AppStorage("restSeconds") private var restSeconds = 90
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Units") {
                Picker("Weight", selection: $unit) {
                    ForEach(WeightUnit.allCases) { Text($0.symbol).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section {
                Stepper(value: $restSeconds, in: 15...600, step: 15) {
                    HStack {
                        Text("Rest between sets")
                        Spacer()
                        Text(Format.clock(TimeInterval(restSeconds)))
                            .monospacedDigit()
                            .foregroundStyle(Theme.secondary)
                    }
                }
            } header: {
                Text("Rest timer")
            } footer: {
                Text("Starts when you tick off a set. Adjust it with −15 / +15 during a workout.")
            }
            Section("Sync") {
                Label("Routines, workouts, bodyweight and photos sync through iCloud to every iPhone, iPad and Mac signed in to the same Apple Account.", systemImage: "icloud")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary)
            }
        }
        .formStyle(.grouped)
        .themedList()
        .navigationTitle("Settings")
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
