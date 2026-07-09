import SwiftData
import SwiftUI

struct RootView: View {
    let container: ModelContainer

    var body: some View {
        TabView {
            Tab("Clients", systemImage: "person.2") {
                ClientListView(viewModel: ClientListViewModel(repo: SwiftDataClientRepository(modelContainer: container)))
            }
            Tab("Exercises", systemImage: "dumbbell") {
                ExerciseListView(viewModel: ExerciseListViewModel(repo: SwiftDataExerciseRepository(modelContainer: container)))
            }
        }
        .task {
            let container = container
            await Task.detached {
                try? await SeedImporter.seedIfEmpty(repo: SwiftDataExerciseRepository(modelContainer: container))
            }.value
        }
    }
}
