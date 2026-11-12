import SwiftUI
import SwiftData

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case workouts, history, progress, photos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workouts: "Workouts"
        case .history: "History"
        case .progress: "Progress"
        case .photos: "Photos"
        }
    }

    var systemImage: String {
        switch self {
        case .workouts: "dumbbell.fill"
        case .history: "clock.arrow.circlepath"
        case .progress: "chart.xyaxis.line"
        case .photos: "photo.on.rectangle.angled"
        }
    }

    @MainActor @ViewBuilder
    var screen: some View {
        switch self {
        case .workouts: WorkoutsView()
        case .history: HistoryView()
        case .progress: ProgressTabView()
        case .photos: PhotosView()
        }
    }
}

struct RootView: View {
    @Environment(WorkoutCoordinator.self) private var coordinator
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    var body: some View {
        @Bindable var coordinator = coordinator
        content
            .tint(.accentColor)
            .workoutCover(isPresented: $coordinator.isPresented) {
                WorkoutFlowView()
                    .environment(coordinator)
                    .preferredColorScheme(.dark)
            }
    }

    @ViewBuilder
    private var content: some View {
        #if os(iOS)
        if sizeClass == .compact {
            TabRoot()
        } else {
            SidebarRoot()
        }
        #else
        SidebarRoot()
        #endif
    }
}

/// iPhone
private struct TabRoot: View {
    @State private var selection: AppSection = .workouts

    var body: some View {
        TabView(selection: $selection) {
            ForEach(AppSection.allCases) { section in
                section.screen
                    .tabItem { Label(section.title, systemImage: section.systemImage) }
                    .tag(section)
            }
        }
    }
}

/// iPad and Mac
private struct SidebarRoot: View {
    @State private var selection: AppSection? = .workouts

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationTitle("Ironlog")
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            (selection ?? .workouts).screen
                .id(selection)
        }
    }
}

/// What the workout cover shows: the live workout, then the summary.
struct WorkoutFlowView: View {
    @Environment(WorkoutCoordinator.self) private var coordinator

    var body: some View {
        Group {
            if let summary = coordinator.summary {
                WorkoutSummaryView(session: summary) { coordinator.close() }
            } else if let session = coordinator.session {
                ActiveWorkoutView(session: session)
            } else {
                Theme.background.onAppear { coordinator.close() }
            }
        }
        .background(Theme.background)
    }
}
