import Foundation

struct ClientDTO: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
}

extension ClientDTO {
    init(_ model: Client) {
        self.init(id: model.id, name: model.name, createdAt: model.createdAt, updatedAt: model.updatedAt)
    }

    func apply(to model: Client) {
        model.name = name
        model.updatedAt = .now
    }
}
