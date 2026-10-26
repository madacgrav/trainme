import SwiftData

/// First versioned schema. Mirrors the models exactly as shipped in 1.0; the
/// model classes live in Sources/Models and are referenced, not nested, so no
/// call site changes. A future change adds SchemaV2 + one MigrationStage.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [Client.self, Exercise.self, Workout.self, WorkoutEntry.self,
         Session.self, WorkoutInstance.self, PlannedEntry.self, SetRecord.self]
    }
    /// Stable string for StoreBackup's defaults key ("1.0.0").
    static var versionString: String {
        let v = versionIdentifier
        return "\(v.major).\(v.minor).\(v.patch)"
    }
}

enum TrainMeMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
