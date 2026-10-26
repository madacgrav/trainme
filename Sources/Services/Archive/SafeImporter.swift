import Foundation

/// Outcome of a guarded replace-import that did not succeed cleanly.
enum ImportOutcome: Error {
    /// The import threw; the pre-import snapshot was re-imported successfully.
    case failedAndRestored(underlying: any Error)
    /// The import threw AND restoring the snapshot threw. Data may be partial;
    /// the snapshot file is left in place for manual recovery.
    case failedAndRestoreFailed(underlying: any Error, restore: any Error)
}

/// Wraps a replace-import in snapshot → import → (on failure) restore. The
/// snapshot is a normal archive, so restore reuses the tested import path.
struct SafeImporter: Sendable {
    let archive: any DataArchiving
    let snapshotURL: URL

    static let defaultSnapshotURL = URL.applicationSupportDirectory.appending(path: "pre-import.json")

    init(archive: any DataArchiving, snapshotURL: URL = SafeImporter.defaultSnapshotURL) {
        self.archive = archive
        self.snapshotURL = snapshotURL
    }

    func importReplacing(url: URL) async throws {
        try await writeSnapshot()
        do {
            try await archive.importArchive(url: url, mode: .replace)
        } catch {
            Log.archive.error("Replace-import failed, restoring snapshot: \(error.localizedDescription)")
            do {
                let snapshot = try Data(contentsOf: snapshotURL)
                try await archive.importData(snapshot, mode: .replace)
            } catch let restoreError {
                Log.archive.fault("Snapshot restore failed: \(restoreError.localizedDescription)")
                throw ImportOutcome.failedAndRestoreFailed(underlying: error, restore: restoreError)
            }
            Self.removeSnapshot(at: snapshotURL)
            throw ImportOutcome.failedAndRestored(underlying: error)
        }
        Self.removeSnapshot(at: snapshotURL)
    }

    /// Call at launch too, in case the app died mid-import.
    static func removeSnapshot(at url: URL = defaultSnapshotURL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }
        do {
            try fm.removeItem(at: url)
        } catch {
            Log.archive.error("Could not remove import snapshot: \(error.localizedDescription)")
        }
    }

    // The snapshot holds client PII; it gets the same file protection as exports.
    private func writeSnapshot() async throws {
        let data = try await archive.exportData()
        try FileManager.default.createDirectory(
            at: snapshotURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: snapshotURL, options: [.atomic, .completeFileProtection])
    }
}
