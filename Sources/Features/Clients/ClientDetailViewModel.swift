import Foundation
import Observation

@MainActor
@Observable
final class ClientDetailViewModel {
    let repository: any ClientRepository
    let exerciseRepo: any ExerciseRepository
    let sessionRepo: any SessionRepository
    let reporting: any ReportingQueries
    var client: ClientDTO
    /// Scheduled sessions that have not started yet, soonest first.
    var upcomingSessions: [SessionDTO] = []
    /// Everything else (past or resolved), most recent first.
    var recentSessions: [SessionDTO] = []

    static let recentLimit = 10

    init(
        repo: any ClientRepository,
        exerciseRepo: any ExerciseRepository,
        sessionRepo: any SessionRepository,
        reporting: any ReportingQueries,
        client: ClientDTO
    ) {
        self.repository = repo
        self.exerciseRepo = exerciseRepo
        self.sessionRepo = sessionRepo
        self.reporting = reporting
        self.client = client
    }

    func reload() async {
        if let refreshed = try? await repository.allIncludingArchived().first(where: { $0.id == client.id }) {
            client = refreshed
        }
        let all = (try? await sessionRepo.forClient(client.id)) ?? []  // newest first
        let now = Date.now
        let split = Self.splitSessions(all, now: now)
        upcomingSessions = split.upcoming
        recentSessions = split.recent
    }

    /// Pure split so the ordering rules are testable without a store.
    static func splitSessions(_ sessions: [SessionDTO], now: Date) -> (upcoming: [SessionDTO], recent: [SessionDTO]) {
        let upcoming = sessions
            .filter { $0.status == .scheduled && $0.startAt > now }
            .sorted { $0.startAt < $1.startAt }
        let recent = sessions
            .filter { !($0.status == .scheduled && $0.startAt > now) }
            .sorted { $0.startAt > $1.startAt }
            .prefix(recentLimit)
        return (upcoming, Array(recent))
    }

    func toggleArchived() async {
        try? await repository.setArchived(id: client.id, !client.isArchived)
        await reload()
    }
}
