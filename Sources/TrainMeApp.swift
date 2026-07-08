import SwiftData
import SwiftUI

@main
struct TrainMeApp: App {
    let container: ModelContainer

    init() {
        let storeURL = URL.applicationSupportDirectory.appending(path: "default.store")
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        try? StoreBackup.backupIfVersionChanged(storeURL: storeURL, currentVersion: version)
        do {
            container = try PersistenceController.makeContainer()
        } catch {
            // P8 adds a user-facing recovery flow (restore backup / import export).
            try? StoreBackup.restoreLatest(storeURL: storeURL)
            container = try! PersistenceController.makeContainer()
        }
    }

    var body: some Scene {
        WindowGroup {
            ClientListView(viewModel: ClientListViewModel(repo: SwiftDataClientRepository(modelContainer: container)))
        }
    }
}
