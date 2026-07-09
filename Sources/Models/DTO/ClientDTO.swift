import Foundation

struct ClientDTO: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var phoneE164: String
    var goal: String?
    var injuries: String?
    var notes: String?
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
}

extension ClientDTO {
    init(_ model: Client) {
        self.init(
            id: model.id,
            name: model.name,
            phoneE164: model.phoneE164,
            goal: model.goal,
            injuries: model.injuries,
            notes: model.notes,
            isArchived: model.isArchived,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    func apply(to model: Client) {
        model.name = name
        model.phoneE164 = phoneE164
        model.goal = goal
        model.injuries = injuries
        model.notes = notes
        model.isArchived = isArchived
        model.updatedAt = .now
    }

    func toModel() -> Client {
        Client(
            id: id,
            name: name,
            phoneE164: phoneE164,
            goal: goal,
            injuries: injuries,
            notes: notes,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
