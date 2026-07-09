import SwiftData
import SwiftUI

struct RootView: View {
    let container: ModelContainer
    @AppStorage("hasSeenBackupNotice") private var hasSeenBackupNotice = false

    private var backupNoticeBinding: Binding<Bool> {
        Binding(get: { !hasSeenBackupNotice }, set: { hasSeenBackupNotice = !$0 })
    }

    var body: some View {
        TabView {
            Tab("Schedule", systemImage: "calendar") {
                ScheduleView(viewModel: ScheduleViewModel(
                    sessionRepo: SwiftDataSessionRepository(modelContainer: container),
                    clientRepo: SwiftDataClientRepository(modelContainer: container),
                    workoutRepo: SwiftDataWorkoutRepository(modelContainer: container),
                    exerciseRepo: SwiftDataExerciseRepository(modelContainer: container),
                    notifications: LocalNotificationService()
                ))
            }
            Tab("Clients", systemImage: "person.2") {
                ClientListView(viewModel: ClientListViewModel(
                    repo: SwiftDataClientRepository(modelContainer: container),
                    exerciseRepo: SwiftDataExerciseRepository(modelContainer: container),
                    reporting: SwiftDataReportingQueries(modelContainer: container)
                ))
            }
            Tab("Workouts", systemImage: "list.clipboard") {
                WorkoutListView(viewModel: WorkoutListViewModel(
                    workoutRepo: SwiftDataWorkoutRepository(modelContainer: container),
                    exerciseRepo: SwiftDataExerciseRepository(modelContainer: container)
                ))
            }
            Tab("Exercises", systemImage: "dumbbell") {
                ExerciseListView(viewModel: ExerciseListViewModel(repo: SwiftDataExerciseRepository(modelContainer: container)))
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView(archive: DataArchiveActor(modelContainer: container))
            }
        }
        .alert("Your data lives only on this iPhone", isPresented: backupNoticeBinding) {
            Button("Got it") { hasSeenBackupNotice = true }
        } message: {
            Text("There is no cloud backup in this version. Export your data regularly from Settings — an export file is the only way to recover from a lost or broken phone.")
        }
        .task {
            let container = container
            await Task.detached {
                try? await SeedImporter.seedIfEmpty(repo: SwiftDataExerciseRepository(modelContainer: container))
            }.value
            _ = await LocalNotificationService().requestAuthorization()
        }
    }
}
