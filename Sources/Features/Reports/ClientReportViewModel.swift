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
        } catch {
            Log.ui.error("client report load failed: \(error.localizedDescription)")
            errorMessage = "Couldn't load progress."
        }
    }
}
