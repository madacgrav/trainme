import Foundation
import SwiftData

enum ImportMode: Sendable {
    case merge, replace
}

enum ArchiveError: Error, Equatable {
    case newerThanApp(Int)
    case unreadable
}

protocol DataArchiving: Sendable {
    /// Encodes everything to a versioned JSON file in tmp; caller hands the URL
    /// to .fileExporter / ShareLink.
    func export() async throws -> URL
    func importArchive(url: URL, mode: ImportMode) async throws
    /// Import from already-loaded data (used by tests and the recovery flow).
    func importData(_ data: Data, mode: ImportMode) async throws
}

@ModelActor
actor DataArchiveActor: DataArchiving {
    func export() async throws -> URL {
        let envelope = CurrentArchive(
            exportedAt: .now,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0",
            clients: try modelContext.fetch(FetchDescriptor<Client>()).map(ClientDTO.init),
            exercises: try modelContext.fetch(FetchDescriptor<Exercise>()).map(ExerciseDTO.init),
            workouts: try modelContext.fetch(FetchDescriptor<Workout>()).map(WorkoutDTO.init),
            sessions: try modelContext.fetch(FetchDescriptor<Session>()).map(SessionDTO.init),
            setRecords: try modelContext.fetch(FetchDescriptor<SetRecord>()).map(SetRecordDTO.init)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(envelope)

        let day = Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        let url = FileManager.default.temporaryDirectory.appending(path: "TrainMe Export \(day).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    func importArchive(url: URL, mode: ImportMode) async throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
        guard let data = try? Data(contentsOf: url) else { throw ArchiveError.unreadable }
        try await importData(data, mode: mode)
    }

    func importData(_ data: Data, mode: ImportMode) async throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let probe = try? decoder.decode(VersionProbe.self, from: data) else {
            throw ArchiveError.unreadable
        }
        guard probe.schemaVersion <= ArchiveV1.schemaVersion else {
            throw ArchiveError.newerThanApp(probe.schemaVersion)
        }
        // Version 1 is the only version so far; older versions will decode +
        // migrate through the chain once they exist.
        let envelope = try decoder.decode(CurrentArchive.self, from: data)

        if mode == .replace {
            try deleteAll()
        }
        try upsertAll(envelope)
        try modelContext.save()
    }

    // MARK: - Private

    private func deleteAll() throws {
        try modelContext.delete(model: SetRecord.self)
        try modelContext.delete(model: Session.self)
        try modelContext.delete(model: Workout.self)
        try modelContext.delete(model: Exercise.self)
        try modelContext.delete(model: Client.self)
    }

    /// Upsert-by-id for every entity array. Graph entities (workouts, sessions)
    /// replace their sub-graph wholesale so the archive version wins.
    private func upsertAll(_ envelope: CurrentArchive) throws {
        for dto in envelope.clients {
            let id = dto.id
            if let existing = try first(FetchDescriptor<Client>(predicate: #Predicate { $0.id == id })) {
                dto.apply(to: existing)
            } else {
                modelContext.insert(dto.toModel())
            }
        }
        for dto in envelope.exercises {
            let id = dto.id
            if let existing = try first(FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == id })) {
                existing.name = dto.name
                existing.categoryRaw = dto.category.rawValue
                existing.metricsRaw = dto.metrics.rawValue
                existing.defaultUnitRaw = dto.defaultUnit.rawValue
                existing.isCustom = dto.isCustom
            } else {
                modelContext.insert(dto.toModel())
            }
        }
        for dto in envelope.workouts {
            let id = dto.id
            if let existing = try first(FetchDescriptor<Workout>(predicate: #Predicate { $0.id == id })) {
                modelContext.delete(existing)
            }
            let workout = Workout(id: dto.id, name: dto.name, createdAt: dto.createdAt, updatedAt: dto.updatedAt)
            modelContext.insert(workout)
            workout.entries.append(contentsOf: dto.entries.map { $0.toModel() })
        }
        for dto in envelope.sessions {
            let id = dto.id
            if let existing = try first(FetchDescriptor<Session>(predicate: #Predicate { $0.id == id })) {
                modelContext.delete(existing)
            }
            insertSessionGraph(dto)
        }
        for dto in envelope.setRecords {
            let id = dto.id
            if let existing = try first(FetchDescriptor<SetRecord>(predicate: #Predicate { $0.id == id })) {
                modelContext.delete(existing)
            }
            modelContext.insert(dto.toModel())
        }
    }

    /// Reconstructs a session with its instance graph, PRESERVING archive ids
    /// (unlike scheduling, which mints fresh ids for template copies).
    private func insertSessionGraph(_ dto: SessionDTO) {
        let session = Session(
            id: dto.id,
            clientId: dto.clientId,
            startAt: dto.startAt,
            endAt: dto.endAt,
            status: dto.status,
            notes: dto.notes,
            seriesId: dto.seriesId,
            recurrenceData: dto.recurrence.flatMap { try? JSONEncoder().encode($0) },
            eventIdentifier: dto.eventIdentifier,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
        modelContext.insert(session)
        for instanceDTO in dto.instances {
            let instance = WorkoutInstance(
                id: instanceDTO.id,
                sourceWorkoutId: instanceDTO.sourceWorkoutId,
                name: instanceDTO.name
            )
            session.instances.append(instance)
            instance.plannedEntries.append(contentsOf: instanceDTO.plannedEntries.map { $0.toModel() })
        }
    }

    private func first<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> T? {
        var limited = descriptor
        limited.fetchLimit = 1
        return try modelContext.fetch(limited).first
    }
}
