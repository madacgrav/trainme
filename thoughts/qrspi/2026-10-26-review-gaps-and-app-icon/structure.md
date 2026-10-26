# Structure Outline

## Approach

Eight vertical slices on a new branch `feature/icon-and-p0-gaps` (cut from
`fix/review-findings`). Slice 1 ships the icon and packaging independently; slices 2–7
each close one P0 gap end-to-end (repository/service → view model → view → test);
slice 8 writes the backlog and opens issues. Every slice leaves the tree green:
`xcodegen generate && xcodebuild -scheme TrainMe -destination 'platform=iOS Simulator,name=iPhone 17' test`
(with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`). Short form below: **`TEST`**.

---

## Phase 1: App icon, accent color, packaging keys

Hand-authored Liquid Glass icon plus the asset catalog and Info.plist basics the app
has never had. Independent of all other phases.

**Files**: `Sources/AppIcon.icon/icon.json`, `Sources/AppIcon.icon/Assets/{background,dumbbell,line}.svg`,
`Sources/Assets.xcassets/Contents.json`, `Sources/Assets.xcassets/AccentColor.colorset/Contents.json`,
`project.yml`, `Sources/Info.plist`, `README.md` (icon note)
**Key changes**:
- `icon.json` — ≤3 groups: background (teal→indigo fill), dumbbell (white, glass), line (amber, glass); `dark` and `mono` appearance specializations. Seeded from a file saved once by Icon Composer.app so the schema is observed, not guessed.
- `project.yml` target settings — `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor` (explicit); `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` (explicit, matches preset).
- `Info.plist` — `CFBundleDisplayName` "TrainMe"; `UISupportedInterfaceOrientations` = portrait only; iPad key left absent (device family unchanged).
- Fallback (only if `actool` rejects `icon.json` twice): `Sources/Assets.xcassets/AppIcon.appiconset/` single 1024 no-alpha PNG rendered from the same SVGs; remove `.icon`.

**Verify**: `xcrun actool Sources/AppIcon.icon --compile /tmp/out --app-icon AppIcon --platform iphonesimulator --minimum-deployment-target 26.0 --output-partial-info-plist /tmp/p.plist` exits 0; **TEST** passes (57); pbxproj Resources phase lists `AppIcon.icon` and `Assets.xcassets`; simulator screenshot of home screen shows the icon in light and dark; `sips -g hasAlpha` on any fallback PNG = no.

---

## Phase 2: ReminderCoordinator — notifications correct from every path

Single owner for trainer alerts; reschedule on foreground and after any session
mutation; stop clobbering non-app notifications. Foundation for phases 6–7.

**Files**: `Sources/Services/ReminderCoordinator.swift` (new), `Sources/Services/NotificationService.swift`,
`Sources/RootView.swift`, `Sources/Features/Schedule/ScheduleViewModel.swift`,
`Sources/Features/Clients/ClientDetailViewModel.swift`, `Sources/Features/Clients/ClientDetailView.swift`,
`Sources/Features/Session/SessionRunViewModel.swift`, `Tests/NotificationSchedulingTests.swift`, `Tests/ReminderCoordinatorTests.swift` (new)
**Key changes**:
- `@MainActor @Observable final class ReminderCoordinator { init(sessionRepo:, clientRepo:, notifications:); func refresh() async }` — fetches `upcoming(after:limit:64)` + client names, calls `notifications.reschedule`.
- `NotificationScheduling.reschedule(upcoming:)` — implementation removes only identifiers matching `sess-*` (pure helper `func sessionAlertIdentifiers(from pending: [String]) -> [String]`), then adds.
- `ScheduleViewModel.init(..., reminders: ReminderCoordinator)` replaces `notifications:`; `load()` calls `reminders.refresh()`.
- `ClientDetailViewModel.init(..., reminders: ReminderCoordinator)`; `reload()` calls `reminders.refresh()`.
- `SessionRunViewModel.onStatusChanged` unchanged; both presenters' closures now reach the coordinator.
- `RootView` — constructs one `ReminderCoordinator`; `.onChange(of: scenePhase)` `.active` → `refresh()` (ignore `.inactive`, mirror `LockGateView.swift:19-30`).

**Verify**: new tests — `sessionAlertIdentifiers` keeps `sess-…` and drops others; coordinator with a fake `NotificationScheduling` records one `reschedule` call per `refresh()`. **TEST** passes. Manual: mark a session cancelled from Client detail, then check `UNUserNotificationCenter` pending via a debug print or re-open Schedule — alerts for that session gone.

---

## Phase 3: Confirmations and failed-save surfacing

Destructive actions ask first; sheets that fail to save say so and stay open.

**Files**: `Sources/Features/Workouts/WorkoutListView.swift`, `Sources/Features/Session/SessionRunView.swift`,
`Sources/Features/Clients/ClientDetailView.swift`, `Sources/Features/Exercises/ExerciseEditView.swift`,
`Sources/Features/Schedule/SessionEditView.swift`, `Sources/Features/Clients/ClientEditViewModel.swift`,
`Sources/Features/Workouts/WorkoutBuilderViewModel.swift`, `Sources/Features/Clients/ClientEditView.swift`,
`Sources/Features/Workouts/WorkoutBuilderView.swift`
**Key changes**:
- `confirmationDialog` on: delete workout, delete set, archive/unarchive client.
- `.alert(role: .destructive)` on: Cancelled, No-show (pattern `SettingsView.swift:79-86`).
- `var errorMessage: String?` on `ClientEditViewModel`, `WorkoutBuilderViewModel`; `ExerciseEditView` and `SessionEditView` gain local `@State errorMessage` and a `Bool`-returning `save()`; Save dismisses only on `true`. Footer `Text(errorMessage)` in each Form.

**Verify**: **TEST** passes (no new unit tests; views only). Manual: swipe-delete a workout → dialog; tap No-show → alert; force a save failure (e.g. temporarily throw in repo) → footer message, sheet stays.

---

## Phase 4: Injuries banner and session notes in the run screen

Trainer sees limitations and notes where they train, and can edit notes afterward.

**Files**: `Sources/Features/Session/SessionRunViewModel.swift`, `Sources/Features/Session/SessionRunView.swift`,
`Sources/Features/Schedule/ScheduleView.swift`, `Sources/Features/Clients/ClientDetailView.swift`
**Key changes**:
- `SessionRunViewModel.init(..., clientInjuries: String? = nil)`; `var notesDraft: String`; `func saveNotes() async` → `sessionRepo.updateNotes(id:_:)` (first UI caller).
- `SessionRunView` — top section: amber `Label(injuries, systemImage: "exclamationmark.triangle")` when non-empty; "Notes" section with `TextField(axis: .vertical)` + `onSubmit`/toolbar Save.
- Presenters pass `client.injuries` (Schedule builds a `clientInjuries: [UUID: String]` map alongside `clientPhones`).

**Verify**: **TEST** passes; add `SessionRepositoryTests.updateNotesPersists`. Manual: client with injuries → banner visible on session; edit notes → persists after pop/push.

---

## Phase 5: Units honored everywhere

One formatter, per-exercise unit of record, global default for new exercises.

**Files**: `Sources/Support/WeightFormatter.swift` (new), `Sources/Features/Settings/SettingsView.swift`,
`Sources/Features/Exercises/ExerciseEditView.swift`, `Sources/Features/Session/SessionRunView.swift`,
`Sources/Features/Workouts/WorkoutBuilderView.swift`, `Sources/Features/Reports/ClientReportView.swift`,
`Sources/Services/ReportExporter.swift`, `Tests/WeightFormatterTests.swift` (new)
**Key changes**:
- `enum WeightFormatter { static func string(_ value: Double, unit: Unit) -> String; static func stepIncrement(for unit: Unit) -> Double /* 5 lb, 2.5 kg */ }`.
- `@AppStorage("defaultWeightUnit") var defaultWeightUnit: Unit = .lb` — Settings "Units" section (segmented lb/kg); `ExerciseEditView` seeds new exercises from it.
- Replace the eight literal `lb` sites (`research.md` Q1) with `WeightFormatter.string(_, unit: exercise.defaultUnit)`; `SetEntryView` stepper uses `stepIncrement`; chart axis label and PDF use the exercise unit (`ReportExporter.renderPDF` gains `unit: Unit`).

**Verify**: `WeightFormatterTests` (lb/kg strings, increments); **TEST** passes; `grep -rn '"lb"\|(lb)\| lb"' Sources/Features Sources/Services` → zero hits; manual: kg exercise shows kg in builder, run, report, PDF.

---

## Phase 6: Edit and delete an existing session (non-series)

Full lifecycle for a single session including calendar and reminders.

**Files**: `Sources/Persistence/SessionRepository.swift`, `Sources/Services/CalendarService.swift`,
`Sources/Features/Schedule/SessionEditView.swift`, `Sources/Features/Session/SessionRunViewModel.swift`,
`Sources/Features/Session/SessionRunView.swift`, `Tests/SessionRepositoryTests.swift`, `Tests/CalendarMappingTests.swift`
**Key changes**:
- `SessionRepository.update(_ dto: SessionDTO) async throws` — updates `clientId/startAt/endAt/notes/updatedAt` only; instances untouched.
- `CalendarSyncing.update(eventIdentifier: String, _ session: SessionDTO, clientName: String) async throws -> String?` — edits in place; returns new id if the event was gone and had to be re-pushed.
- `SessionEditView.init(existing: SessionDTO?, initialDate:, …)` — title "Edit Session"; hides Workouts and Repeat sections when editing; Save → `update` + calendar update + `onSaved`.
- `SessionRunViewModel.delete() async` — `calendar.remove` (if `eventIdentifier`), `sessionRepo.delete(id:)`, `onStatusChanged()`; `canEdit = session.seriesId == nil`.
- `SessionRunView` toolbar menu: Edit (non-series), Delete (alert, destructive); series rows show a footnote "Part of a repeating series — edit individually isn't available yet."

**Verify**: `SessionRepositoryTests.updateChangesTimeNotInstances`, `.deleteRemovesSessionAndSets` (exists) ; fake `CalendarSyncing` records `update`/`remove`. **TEST** passes. Manual: edit time → Schedule list and (if pushed) calendar event move; delete → gone from Schedule, Client detail, and pending alerts.

---

## Phase 7: Export staleness reminder

The P0 "prompt the trainer to export periodically" (PRD §9).

**Files**: `Sources/Support/ExportReminder.swift` (new), `Sources/Persistence/SessionRepository.swift` (count query),
`Sources/Features/Schedule/ScheduleView.swift`, `Sources/Features/Schedule/ScheduleViewModel.swift`,
`Sources/RootView.swift` (Settings tab badge), `Sources/Features/Settings/SettingsView.swift`, `Tests/ExportReminderTests.swift` (new)
**Key changes**:
- `func exportReminderDue(lastExportAt: Date?, now: Date, completedSinceExport: Int, dayThreshold: Int = 14, sessionThreshold: Int = 5) -> Bool` — pure.
- `SessionRepository.completedCount(since: Date?) async throws -> Int`.
- `ScheduleViewModel.exportReminderDue: Bool` computed in `load()`; `ScheduleView` shows a dismissible banner ("Back up your data — last export N days ago") that deep-links by switching to the Settings tab via a shared `@AppStorage("selectedTab")`-free approach: a `Binding<Int>` selection on `RootView.TabView` passed down.
- Settings tab `.badge("!")` while due; cleared on successful export (existing `lastExportAt` write).

**Verify**: `ExportReminderTests` (never exported → due; 13 days/4 sessions → not due; 14 days → due; 5 sessions → due); **TEST** passes. Manual: fresh install → banner after first completed sessions; export → banner and badge clear.

---

## Phase 8: BACKLOG.md, GitHub issues, README link

Durable home for everything deferred by design.

**Files**: `BACKLOG.md` (new), `README.md`, GitHub (labels `priority:P1`, `priority:P2`; one issue per row)
**Key changes**:
- `BACKLOG.md` sections: P1 features, P2 features, Deferred by owner decision, Tech debt, Test gaps — each row: title · PRD/§ ref · evidence (`file:line`) · issue link.
- `gh label create priority:P1 …`, `gh label create priority:P2 …`; `gh issue create --label enhancement,priority:P1 --title … --body-file …` per row; backfill issue URLs into `BACKLOG.md`.
- README "Roadmap" line linking `BACKLOG.md`.

**Verify**: `gh issue list --label priority:P1` and `priority:P2` counts match BACKLOG rows; every BACKLOG row has a working issue link; `git status` clean after commit. Issue creation runs only after the owner approves the BACKLOG text (outward-facing).

---

## Testing Checkpoints

| After | True |
|---|---|
| P1 | Icon visible on simulator (light/dark); accent color amber; **TEST** 57 green; `actool` compiles `.icon` |
| P2 | `ReminderCoordinator` is the only caller of `reschedule`; `sess-*`-only removal tested; foreground refresh wired |
| P3 | Every destructive button confirms; Client/Workout/Exercise/Session sheets stay open on failure with a message |
| P4 | Injuries banner + editable notes on `SessionRunView`; `updateNotes` tested |
| P5 | Zero literal `lb` in Features/Services; kg exercise renders kg end-to-end; Settings has Units |
| P6 | Non-series session editable and deletable; calendar `update`/`remove` exercised through a fake; series shows footnote |
| P7 | `exportReminderDue` tested; banner + Settings badge appear/clear |
| P8 | `BACKLOG.md` committed and linked; issues open with priority labels; PR opened from `feature/icon-and-p0-gaps` |

Phases 1, 3, 4, 5, 7 are independent of each other; 6 depends on 2 (reminders after delete) and
benefits from 3 (alert pattern); 7 depends on 2 only for the shared tab-selection binding if
placed in `RootView`. If context resets mid-way, resume at the first row whose "True" column fails.
