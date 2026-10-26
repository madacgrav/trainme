import Foundation
import Observation

@MainActor
@Observable
final class ClientReportViewModel {
    let reporting: any ReportingQueries
    private let exerciseRepo: any ExerciseRepository
    let client: ClientDTO

    var exercisesWithData: [ExerciseDTO] = []
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
            let ids = Set(try await reporting.exercisesWithData(clientId: client.id))
            let all = try await exerciseRepo.all()
            exercisesWithData = all.filter { ids.contains($0.id) }
            try await loadWindowed()
        } catch {
            Log.ui.error("client report load failed: \(error.localizedDescription)")
            errorMessage = "Couldn't load progress."
        }
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
