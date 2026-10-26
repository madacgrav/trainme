import SwiftData

/// Current schema: the live model classes in Sources/Models. Adds `Client.isSelf`
/// (defaulted) over SchemaV1, which keeps a frozen copy of the 1.0 classes.
enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [Client.self, Exercise.self, Workout.self, WorkoutEntry.self,
         Session.self, WorkoutInstance.self, PlannedEntry.self, SetRecord.self]
    }
    /// Stable string for StoreBackup's defaults key ("2.0.0").
    static var versionString: String {
        let v = versionIdentifier
        return "\(v.major).\(v.minor).\(v.patch)"
    }
}
