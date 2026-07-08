import Foundation

/// Copies the SwiftData store files aside before a potentially-migrating container
/// open, so a failed migration is recoverable instead of data loss.
enum StoreBackup {
    static let versionKey = "lastRunAppVersion"

    private static let storeSuffixes = ["", "-wal", "-shm"]

    /// Call BEFORE makeContainer(). Backs up the store files when the app version
    /// differs from the last recorded run. Keeps only the most recent backup.
    static func backupIfVersionChanged(
        storeURL: URL,
        currentVersion: String,
        defaults: UserDefaults = .standard
    ) throws {
        let lastVersion = defaults.string(forKey: versionKey)
        defer { defaults.set(currentVersion, forKey: versionKey) }
        guard let lastVersion, lastVersion != currentVersion else { return }

        let fm = FileManager.default
        let backupsRoot = backupsRoot(for: storeURL)
        try? fm.removeItem(at: backupsRoot)
        let backupDir = backupsRoot.appending(path: "pre-\(currentVersion)", directoryHint: .isDirectory)
        try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)

        for suffix in storeSuffixes {
            let src = URL(filePath: storeURL.path + suffix)
            if fm.fileExists(atPath: src.path) {
                try fm.copyItem(at: src, to: backupDir.appending(path: src.lastPathComponent))
            }
        }
    }

    /// Restores the most recent backup over the current store files.
    static func restoreLatest(storeURL: URL) throws {
        let fm = FileManager.default
        let dirs = try fm.contentsOfDirectory(at: backupsRoot(for: storeURL), includingPropertiesForKeys: nil)
        guard let backupDir = dirs.first(where: { $0.hasDirectoryPath || $0.lastPathComponent.hasPrefix("pre-") }) else { return }

        for file in try fm.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: nil) {
            let dest = storeURL.deletingLastPathComponent().appending(path: file.lastPathComponent)
            if fm.fileExists(atPath: dest.path) {
                try fm.removeItem(at: dest)
            }
            try fm.copyItem(at: file, to: dest)
        }
    }

    private static func backupsRoot(for storeURL: URL) -> URL {
        storeURL.deletingLastPathComponent().appending(path: "Backups", directoryHint: .isDirectory)
    }
}
