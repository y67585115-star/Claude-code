import SwiftUI
import SwiftData

@main
struct IronlogApp: App {
    @State private var coordinator = WorkoutCoordinator()

    let container: ModelContainer = {
        let schema = Schema([
            Routine.self,
            RoutineExercise.self,
            WorkoutSession.self,
            SetEntry.self,
            BodyweightEntry.self,
            ProgressPhoto.self,
        ])
        do {
            // Syncs through the iCloud container in the entitlements (iPhone, iPad, Mac).
            let cloud = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            return try ModelContainer(for: schema, configurations: cloud)
        } catch {
            // Fall back to on-device storage so the app still runs without iCloud.
            print("CloudKit store unavailable, using local store: \(error)")
            let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            do {
                return try ModelContainer(for: schema, configurations: local)
            } catch {
                fatalError("Could not create the data store: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(coordinator)
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
        #if os(macOS)
        .defaultSize(width: 1120, height: 760)
        #endif

        #if os(macOS)
        Settings {
            SettingsView(showsDoneButton: false)
                .preferredColorScheme(.dark)
                .frame(width: 440, height: 360)
        }
        #endif
    }
}
