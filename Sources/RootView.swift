import SwiftData
import SwiftUI

struct RootView: View {
    let container: ModelContainer
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasSeenBackupNotice") private var hasSeenBackupNotice = false
    @AppStorage("lastExportAt") private var lastExportAt: Double = 0
    @State private var selectedTab = 0
    @State private var exportDue = false
    @State private var reminders: ReminderCoordinator

    init(container: ModelContainer) {
        self.container = container
        _reminders = State(initialValue: ReminderCoordinator(
            sessionRepo: SwiftDataSessionRepository(modelContainer: container),
            clientRepo: SwiftDataClientRepository(modelContainer: container),
            notifications: LocalNotificationService()
        ))
    }

    private var backupNoticeBinding: Binding<Bool> {
        Binding(get: { !hasSeenBackupNotice }, set: { hasSeenBackupNotice = !$0 })
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Schedule", systemImage: "calendar", value: 0) {
                ScheduleView(
                    viewModel: ScheduleViewModel(
                        sessionRepo: SwiftDataSessionRepository(modelContainer: container),
                        clientRepo: SwiftDataClientRepository(modelContainer: container),
                        workoutRepo: SwiftDataWorkoutRepository(modelContainer: container),
                        exerciseRepo: SwiftDataExerciseRepository(modelContainer: container),
                        reminders: reminders
                    ),
                    openSettings: { selectedTab = 4 }
                )
            }
            Tab("Clients", systemImage: "person.2", value: 1) {
                ClientListView(viewModel: ClientListViewModel(
                    repo: SwiftDataClientRepository(modelContainer: container),
                    exerciseRepo: SwiftDataExerciseRepository(modelContainer: container),
                    sessionRepo: SwiftDataSessionRepository(modelContainer: container),
                    reporting: SwiftDataReportingQueries(modelContainer: container),
                    reminders: reminders
                ))
            }
            Tab("Workouts", systemImage: "list.clipboard", value: 2) {
                WorkoutListView(viewModel: WorkoutListViewModel(
                    workoutRepo: SwiftDataWorkoutRepository(modelContainer: container),
                    exerciseRepo: SwiftDataExerciseRepository(modelContainer: container)
                ))
            }
            Tab("Exercises", systemImage: "dumbbell", value: 3) {
                ExerciseListView(viewModel: ExerciseListViewModel(repo: SwiftDataExerciseRepository(modelContainer: container)))
            }
            Tab("Settings", systemImage: "gearshape", value: 4) {
                SettingsView(archive: DataArchiveActor(modelContainer: container), reminders: reminders)
            }
            .badge(exportDue ? Text("!") : nil)
        }
        .alert("Your data lives only on this iPhone", isPresented: backupNoticeBinding) {
            Button("Got it") { hasSeenBackupNotice = true }
        } message: {
            Text("There is no cloud backup in this version. Export your data regularly from Settings — an export file is the only way to recover from a lost or broken phone.")
        }
        .onChange(of: scenePhase) { _, phase in
            // `.inactive` fires during Face ID; only a real foreground matters.
            if phase == .active {
                Task {
                    await reminders.refresh()
                    exportDue = await reminders.exportReminderIsDue()
                }
            }
        }
        .onChange(of: lastExportAt) {
            // A successful export clears the badge immediately.
            Task { exportDue = await reminders.exportReminderIsDue() }
        }
        .task {
            let container = container
            await Task.detached {
                try? await SeedImporter.seedIfEmpty(repo: SwiftDataExerciseRepository(modelContainer: container))
            }.value
            await reminders.requestAuthorization()
            exportDue = await reminders.exportReminderIsDue()
        }
    }
}
