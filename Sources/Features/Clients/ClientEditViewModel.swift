import Foundation
import Observation

@MainActor
@Observable
final class ClientEditViewModel {
    private let repo: any ClientRepository
    private let existing: ClientDTO?
    /// Self-use profile: no phone number required and none shown.
    let isSelf: Bool

    var name: String
    var phoneRaw: String
    var goal: String
    var injuries: String
    var notes: String
    var errorMessage: String?

    init(repo: any ClientRepository, existing: ClientDTO?, isSelf: Bool = false) {
        self.repo = repo
        self.existing = existing
        self.isSelf = existing?.isSelf ?? isSelf
        self.name = existing?.name ?? ""
        self.phoneRaw = existing?.phoneE164 ?? ""
        self.goal = existing?.goal ?? ""
        self.injuries = existing?.injuries ?? ""
        self.notes = existing?.notes ?? ""
    }

    var isEditing: Bool { existing != nil }

    var phoneValid: Bool { normalizeE164(phoneRaw) != nil }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (isSelf || phoneValid)
    }

    func save() async -> Bool {
        errorMessage = nil
        let phone = isSelf ? (normalizeE164(phoneRaw) ?? "") : normalizeE164(phoneRaw)
        guard let phone else { return false }
        let dto = ClientDTO(
            id: existing?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            phoneE164: phone,
            goal: goal.isEmpty ? nil : goal,
            injuries: injuries.isEmpty ? nil : injuries,
            notes: notes.isEmpty ? nil : notes,
            isArchived: existing?.isArchived ?? false,
            createdAt: existing?.createdAt ?? .now,
            updatedAt: .now,
            isSelf: isSelf
        )
        do {
            try await repo.upsert(dto)
            return true
        } catch {
            errorMessage = "Couldn't save the client. Please try again."
            return false
        }
    }
}
