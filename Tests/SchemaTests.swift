import SwiftData
import Testing
@testable import TrainMe

@Test func schemaV1ListsAllModels() {
    #expect(SchemaV1.models.count == 8)
    #expect(SchemaV1.versionString == "1.0.0")
    #expect(TrainMeMigrationPlan.schemas.count == 1)
    #expect(TrainMeMigrationPlan.stages.isEmpty)
}

@Test func containerOpensThroughMigrationPlan() throws {
    let container = try PersistenceController.makeContainer(inMemory: true)
    #expect(container.schema.entities.count == 8)
}
