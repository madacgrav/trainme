import Foundation
import Observation

@MainActor
@Observable
final class ClientEditViewModel {
    private let repo: any ClientRepository
    private let existing: ClientDTO?

    var name: String
    var phoneRaw: String
    var goal: String
    var injuries: String
    var notes: String

    init(repo: any ClientRepository, existing: ClientDTO?) {
        self.repo = repo
        self.existing = existing
        self.name = existing?.name ?? ""
        self.phoneRaw = existing?.phoneE164 ?? ""
        self.goal = existing?.goal ?? ""
        self.injuries = existing?.injuries ?? ""
        self.notes = existing?.notes ?? ""
    }

    var isEditing: Bool { existing != nil }

    var phoneValid: Bool { normalizeE164(phoneRaw) != nil }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && phoneValid
    }

    func save() async -> Bool {
        guard let phone = normalizeE164(phoneRaw) else { return false }
        let dto = ClientDTO(
            id: existing?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            phoneE164: phone,
            goal: goal.isEmpty ? nil : goal,
            injuries: injuries.isEmpty ? nil : injuries,
            notes: notes.isEmpty ? nil : notes,
            isArchived: existing?.isArchived ?? false,
            createdAt: existing?.createdAt ?? .now,
            updatedAt: .now
        )
        do {
            try await repo.upsert(dto)
            return true
        } catch {
            return false
        }
    }
}
