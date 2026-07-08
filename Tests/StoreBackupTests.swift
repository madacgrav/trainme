import Foundation
import Testing
@testable import TrainMe

@Test func backupOnVersionChangeAndRestore() throws {
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appending(path: "store-backup-test-\(UUID().uuidString)")
    try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: dir) }

    let storeURL = dir.appending(path: "default.store")
    try Data("v1-data".utf8).write(to: storeURL)
    let defaults = UserDefaults(suiteName: "StoreBackupTests-\(UUID().uuidString)")!

    // First run records the version without creating a backup.
    try StoreBackup.backupIfVersionChanged(storeURL: storeURL, currentVersion: "1.0", defaults: defaults)
    #expect(!fm.fileExists(atPath: dir.appending(path: "Backups").path))

    // Same version again: still no backup.
    try StoreBackup.backupIfVersionChanged(storeURL: storeURL, currentVersion: "1.0", defaults: defaults)
    #expect(!fm.fileExists(atPath: dir.appending(path: "Backups").path))

    // Version change: backup created.
    try StoreBackup.backupIfVersionChanged(storeURL: storeURL, currentVersion: "1.1", defaults: defaults)
    #expect(fm.fileExists(atPath: dir.appending(path: "Backups/pre-1.1/default.store").path))

    // Corrupt the store, then restore returns the backed-up bytes.
    try Data("corrupt".utf8).write(to: storeURL)
    try StoreBackup.restoreLatest(storeURL: storeURL)
    #expect(try String(contentsOf: storeURL, encoding: .utf8) == "v1-data")
}
