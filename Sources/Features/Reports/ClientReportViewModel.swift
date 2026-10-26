import Foundation
import Observation

@MainActor
@Observable
final class ClientReportViewModel {
    let reporting: any ReportingQueries
    private let exerciseRepo: any ExerciseRepository
    let client: ClientDTO

    struct TopExercise: Identifiable {
        let summary: ExerciseSummary
        let exercise: ExerciseDTO
        var id: UUID { exercise.id }
    }

    var topExercises: [TopExercise] = []
    var errorMessage: String?
    var window: ReportWindow = .twelveWeeks
    var consistency: ConsistencySummary?
    var weeklyVolumes: [WeeklyVolume] = []
    var sessionVolumes: [SessionVolume] = []

    init(reporting: any ReportingQueries, exerciseRepo: any ExerciseRepository, client: ClientDTO) {
        self.reporting = reporting
        self.exerciseRepo = exerciseRepo
        self.client = client
    }

    func load() async {
        errorMessage = nil
        do {
            let summaries = try await reporting.topExercises(clientId: client.id)
            let byId = Dictionary(uniqueKeysWithValues: try await exerciseRepo.all().map { ($0.id, $0) })
            topExercises = summaries.compactMap { summary in
                byId[summary.id].map { TopExercise(summary: summary, exercise: $0) }
            }
            try await loadWindowed()
        } catch {
            Log.ui.error("client report load failed: \(error.localizedDescription)")
            errorMessage = "Couldn't load progress."
        }
    }

    /// Second line of a top-exercise row and the overview page.
    static func detail(for item: TopExercise) -> String {
        let sessions = "\(item.summary.sessionCount) \(item.summary.sessionCount == 1 ? "session" : "sessions")"
        if let weight = item.summary.bestWeight {
            return "\(sessions) · PB \(WeightFormatter.string(weight, unit: item.exercise.defaultUnit))"
        }
        if let reps = item.summary.bestTotalReps {
            return "\(sessions) · best \(reps) reps"
        }
        return "\(sessions) · no weight recorded"
    }

    /// Everything the window picker affects.
    func reloadWindow() async {
        do { try await loadWindowed() } catch {
            Log.ui.error("client report window load failed: \(error.localizedDescription)")
            errorMessage = "Couldn't load progress."
        }
    }

    private func loadWindowed() async throws {
        let now = Date.now
        let from = window.start(from: now)
        consistency = try await reporting.consistency(clientId: client.id, from: from, to: now)
        sessionVolumes = try await reporting.sessionVolumes(clientId: client.id, from: from, to: now)
        weeklyVolumes = try await reporting.weeklyVolumes(clientId: client.id, from: from, to: now)
    }
}
