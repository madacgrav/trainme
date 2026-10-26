import Foundation

/// Copies the SwiftData store files aside before a potentially-migrating container
/// open, so a failed migration is recoverable instead of data loss.
enum StoreBackup {
    /// Last schema version (SchemaV1.versionString) the store was opened with.
    static let versionKey = "lastRunSchemaVersion"
    /// Pre-versioned-schema builds recorded the marketing version here.
    static let legacyVersionKey = "lastRunAppVersion"

    private static let storeSuffixes = ["", "-wal", "-shm"]

    /// Call BEFORE makeContainer(). Backs up the store files when the schema
    /// version differs from the last recorded run. Keeps only the most recent
    /// backup. The version is recorded only once the backup succeeded, so a
    /// failed copy is retried on the next launch instead of being silently
    /// skipped forever.
    static func backupIfVersionChanged(
        storeURL: URL,
        currentVersion: String,
        defaults: UserDefaults = .standard
    ) throws {
        var lastVersion = defaults.string(forKey: versionKey)
        let hasLegacyKey = defaults.string(forKey: legacyVersionKey) != nil
        if lastVersion == nil, hasLegacyKey {
            // Upgrading from the pre-versioned-schema build: the store exists but
            // its schema version is unknown. Take one backup, then drop the old key.
            lastVersion = "legacy"
        }
        if let lastVersion, lastVersion != currentVersion {
            let fm = FileManager.default
            let backupsRoot = backupsRoot(for: storeURL)
            try? fm.removeItem(at: backupsRoot)
            let backupDir = backupsRoot.appending(path: "pre-schema-\(currentVersion)", directoryHint: .isDirectory)
            try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)

            for suffix in storeSuffixes {
                let src = URL(filePath: storeURL.path + suffix)
                if fm.fileExists(atPath: src.path) {
                    try fm.copyItem(at: src, to: backupDir.appending(path: src.lastPathComponent))
                }
            }
        }
        if hasLegacyKey {
            defaults.removeObject(forKey: legacyVersionKey)
        }
        defaults.set(currentVersion, forKey: versionKey)
    }

    /// Restores the most recent backup over the current store files.
    static func restoreLatest(storeURL: URL) throws {
        let fm = FileManager.default
        let dirs = try fm.contentsOfDirectory(at: backupsRoot(for: storeURL), includingPropertiesForKeys: nil)
        guard let backupDir = dirs.first(where: { $0.lastPathComponent.hasPrefix("pre-") }) else { return }

        // Remove every live store file first. A -wal or -shm left over from the
        // broken store does not belong to the restored main file, and SQLite
        // treats a mismatched WAL as corruption rather than ignoring it.
        for suffix in storeSuffixes {
            let live = URL(filePath: storeURL.path + suffix)
            if fm.fileExists(atPath: live.path) {
                try fm.removeItem(at: live)
            }
        }
        for file in try fm.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: nil) {
            try fm.copyItem(at: file, to: storeURL.deletingLastPathComponent().appending(path: file.lastPathComponent))
        }
    }

    private static func backupsRoot(for storeURL: URL) -> URL {
        storeURL.deletingLastPathComponent().appending(path: "Backups", directoryHint: .isDirectory)
    }
}
