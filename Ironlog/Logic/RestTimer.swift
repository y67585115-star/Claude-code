import Foundation
import Observation

@MainActor
@Observable
final class RestTimer {
    private(set) var endDate: Date?
    private(set) var total: TimeInterval = 0
    /// Bumps each time a rest period runs out (drives haptics).
    private(set) var finishedCount = 0

    @ObservationIgnored private var task: Task<Void, Never>?

    var isRunning: Bool { endDate != nil }

    func start(seconds: Int) {
        total = TimeInterval(max(seconds, 1))
        endDate = Date.now.addingTimeInterval(total)
        schedule()
    }

    func adjust(by seconds: Int) {
        guard let end = endDate else { return }
        let newEnd = end.addingTimeInterval(TimeInterval(seconds))
        guard newEnd > .now else { stop(); return }
        endDate = newEnd
        total = max(total + TimeInterval(seconds), newEnd.timeIntervalSinceNow)
        schedule()
    }

    func stop() {
        task?.cancel()
        task = nil
        endDate = nil
    }

    private func schedule() {
        task?.cancel()
        guard let end = endDate else { return }
        task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, end.timeIntervalSinceNow)))
            guard !Task.isCancelled, let self else { return }
            self.endDate = nil
            self.finishedCount += 1
        }
    }
}

@MainActor
@Observable
final class WorkoutCoordinator {
    var isPresented = false
    var session: WorkoutSession?
    /// Set after finishing, shows the summary screen.
    var summary: WorkoutSession?
    let restTimer = RestTimer()

    func present(_ session: WorkoutSession) {
        summary = nil
        self.session = session
        isPresented = true
    }

    func showSummary(for session: WorkoutSession) {
        restTimer.stop()
        self.session = nil
        summary = session
    }

    func close() {
        isPresented = false
        session = nil
        summary = nil
    }

    func endWithoutSummary() {
        restTimer.stop()
        close()
    }
}
