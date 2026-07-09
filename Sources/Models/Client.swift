import Foundation
import SwiftData

@Model
final class Client {
    @Attribute(.unique) var id: UUID
    var name: String
    // Defaults on all post-v0 properties keep SwiftData lightweight migration happy.
    var phoneE164: String = ""
    var goal: String?
    var injuries: String?
    var notes: String?
    var isArchived: Bool = false
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        phoneE164: String = "",
        goal: String? = nil,
        injuries: String? = nil,
        notes: String? = nil,
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.phoneE164 = phoneE164
        self.goal = goal
        self.injuries = injuries
        self.notes = notes
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
