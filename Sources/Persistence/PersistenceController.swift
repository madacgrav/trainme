import Foundation
import SwiftData

enum PersistenceController {
    /// Extended each phase as new @Model types are added.
    static let schemaTypes: [any PersistentModel.Type] = [Client.self]

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        if !inMemory {
            // Application Support may not exist on first launch; the store lives there.
            try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        }
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: Schema(schemaTypes), configurations: config)
    }
}
