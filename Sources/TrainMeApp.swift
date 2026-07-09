import SwiftData
import SwiftUI

@MainActor
@Observable
final class AppBootstrap {
    enum State {
        case ready(ModelContainer)
        case failed(String)
    }

    private(set) var state: State
    private static let storeURL = URL.applicationSupportDirectory.appending(path: "default.store")

    init() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        try? StoreBackup.backupIfVersionChanged(storeURL: Self.storeURL, currentVersion: version)
        state = Self.attempt()
    }

    /// Restore the pre-migration backup and retry (see StoreBackup).
    func restoreBackupAndRetry() {
        try? StoreBackup.restoreLatest(storeURL: Self.storeURL)
        state = Self.attempt()
    }

    /// Last resort: delete the store files and start fresh; the trainer can
    /// then re-import an export file from Settings.
    func resetStoreAndRetry() {
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            try? fm.removeItem(at: URL(filePath: Self.storeURL.path + suffix))
        }
        state = Self.attempt()
    }

    private static func attempt() -> State {
        do {
            return .ready(try PersistenceController.makeContainer())
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}

@main
struct TrainMeApp: App {
    @State private var bootstrap = AppBootstrap()

    var body: some Scene {
        WindowGroup {
            switch bootstrap.state {
            case .ready(let container):
                LockGateView {
                    RootView(container: container)
                }
            case .failed(let message):
                RecoveryView(
                    message: message,
                    onRestoreBackup: { bootstrap.restoreBackupAndRetry() },
                    onReset: { bootstrap.resetStoreAndRetry() }
                )
            }
        }
    }
}

struct RecoveryView: View {
    let message: String
    let onRestoreBackup: () -> Void
    let onReset: () -> Void
    @State private var confirmingReset = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("TrainMe couldn't open its data store")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Restore last backup") { onRestoreBackup() }
                .buttonStyle(.borderedProminent)
            Button("Start fresh (then import an export file)", role: .destructive) {
                confirmingReset = true
            }
        }
        .padding(32)
        .alert("Delete the data store?", isPresented: $confirmingReset) {
            Button("Delete and start fresh", role: .destructive) { onReset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only do this if restoring the backup didn't work. You can re-import a JSON export from Settings afterwards.")
        }
    }
}
