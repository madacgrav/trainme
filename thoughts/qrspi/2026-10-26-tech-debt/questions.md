# Research Questions

## Context
Focus on the SwiftData persistence layer (`Sources/Persistence/`, `Sources/Models/`,
`Sources/TrainMeApp.swift`), the archive import/export and store backup code
(`Sources/Services/Archive/`, `Sources/Persistence/StoreBackup.swift`), the EventKit and
notification services (`Sources/Services/CalendarService.swift`,
`Sources/Services/NotificationService.swift`, `Sources/Services/ReminderCoordinator.swift`)
and their callers in `Sources/Features/`, the project packaging (`project.yml`,
`Sources/Info.plist`, `.github/`), and the test target (`Tests/`).

## Questions

1. How is the SwiftData `ModelContainer` constructed and opened at launch, what does
   `AppBootstrap` do when opening fails (backup restore, store reset), and how do the
   `@Model` types, `StoreBackup.versionKey`, and the archive's schema version relate to
   one another? Trace the launch path from `TrainMeApp` through `PersistenceController`.

2. How does `DataArchiveActor.importData` perform a replace-mode import versus a merge-mode
   import: what is deleted, in what order, inside which model context, and what happens to
   the store if a step throws partway through? How does the existing `StoreBackup`
   mechanism (when it runs, what it copies, how `restoreLatest` works) interact with imports?

3. Where in `Sources/` are errors thrown by background or asynchronous work swallowed with
   `try?` or otherwise not surfaced to the user, and what patterns already exist for
   surfacing failures (alerts, banners, `RecoveryView`, error state on view models)?
   Focus on `RootView.task`, `SessionEditView.save`/`saveEdit`, `SessionRunViewModel`, and
   `SettingsView`.

4. How does `LocalNotificationService` request authorization and schedule notifications
   (`requestAuthorization`, `reschedule`, `center.add`), how does `ReminderCoordinator` call
   it, and what does the code do today when authorization is denied, not yet determined, or
   when `add` fails? Where is the authorization status read, if anywhere?

5. How does `EventKitCalendarService` obtain calendar access and pick a calendar for new
   events (`requestAccess`, `defaultCalendarForNewEvents`), what do `push`, `update`, and
   `remove` do, and how do their callers in `SessionEditView` and `SessionRunViewModel`
   handle the returned identifiers and errors? How does `CalendarSyncing` get faked in tests?

6. What does the project's build and packaging configuration contain: `project.yml` targets,
   settings, signing, and schemes; `Sources/Info.plist` keys; any entitlements, capabilities,
   or privacy manifest; and what the `.github/` directory holds? How is the Xcode project
   generated and built from the command line (XcodeGen, `xcodebuild` destinations, test
   invocation)?

7. How is the test target organized: which test files exist, which production types they
   cover, what test doubles exist (`FakeCalendar`, `FakeNotifications`), how in-memory
   SwiftData containers are created, and which services, view models, and save paths have
   no test coverage at all?
