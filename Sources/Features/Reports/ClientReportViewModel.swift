import Foundation
import Observation

@MainActor
@Observable
final class ClientReportViewModel {
    private let reporting: any ReportingQueries
    private let exerciseRepo: any ExerciseRepository
    let client: ClientDTO

    var exercisesWithData: [ExerciseDTO] = []
    var selectedExerciseId: UUID?
    var points: [ProgressPoint] = []
    var personalBest: SetRecordDTO?

    init(reporting: any ReportingQueries, exerciseRepo: any ExerciseRepository, client: ClientDTO) {
        self.reporting = reporting
        self.exerciseRepo = exerciseRepo
        self.client = client
    }

    var hasEnoughData: Bool { points.count >= 2 }

    func load() async {
        let ids = Set((try? await reporting.exercisesWithData(clientId: client.id)) ?? [])
        let all = (try? await exerciseRepo.all()) ?? []
        exercisesWithData = all.filter { ids.contains($0.id) }
        if selectedExerciseId == nil {
            selectedExerciseId = exercisesWithData.first?.id
        }
        await loadChart()
    }

    func loadChart() async {
        guard let exerciseId = selectedExerciseId else {
            points = []
            personalBest = nil
            return
        }
        points = (try? await reporting.progression(clientId: client.id, exerciseId: exerciseId)) ?? []
        personalBest = try? await reporting.personalBest(clientId: client.id, exerciseId: exerciseId)
    }
}
