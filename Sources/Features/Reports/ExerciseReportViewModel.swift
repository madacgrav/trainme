import Foundation
import Observation

@MainActor
@Observable
final class ExerciseReportViewModel {
    private let reporting: any ReportingQueries
    let client: ClientDTO
    let exercise: ExerciseDTO

    var points: [ProgressPoint] = []
    var personalBest: SetRecordDTO?
    var history: [SessionHistoryEntry] = []
    var errorMessage: String?

    init(reporting: any ReportingQueries, client: ClientDTO, exercise: ExerciseDTO) {
        self.reporting = reporting
        self.client = client
        self.exercise = exercise
    }

    var unit: Unit { exercise.defaultUnit }

    /// Any chart has something to draw, so the page is worth exporting.
    var hasEnoughData: Bool { points.count >= ProgressPoint.minimumPoints }

    func load() async {
        errorMessage = nil
        do {
            points = try await reporting.progression(clientId: client.id, exerciseId: exercise.id)
            personalBest = try await reporting.personalBest(clientId: client.id, exerciseId: exercise.id)
            history = try await reporting.historyBySession(clientId: client.id, exerciseId: exercise.id)
        } catch {
            Log.ui.error("exercise report load failed: \(error.localizedDescription)")
            errorMessage = "Couldn't load progress for this exercise."
        }
    }

    /// "185 lb × 5, 185 lb × 5, 190 lb × 3" — one entry per set, in set order.
    func summary(of sets: [SetRecordDTO]) -> String {
        sets.map { set in
            switch (set.weight, set.reps, set.duration) {
            case let (weight?, reps?, _): "\(WeightFormatter.string(weight, unit: unit)) × \(reps)"
            case let (weight?, nil, _): WeightFormatter.string(weight, unit: unit)
            case let (nil, reps?, _): "\(reps) reps"
            case let (nil, nil, duration?): "\(duration)s"
            default: "—"
            }
        }
        .joined(separator: ", ")
    }
}
