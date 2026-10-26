# Research Findings

Paths are relative to the repo root. `S/` = `Sources/`, `T/` = `Tests/`. Facts only;
every finding was either verified directly or reported by a research agent with a
`file:line` citation. Git history: ten phase commits b3a6d84…98a1e3d merged as PR #1
(293f8c1), then 30fe87b (README), ac5a23f (simulator lock), 8c9de58 (CODEOWNERS),
a0a1c9c (review fixes, 57 tests), db09e7e (signing). Working tree is clean on
`fix/review-findings`.

## Q1: PRD §5 / decisions.md requirements — implemented, partial, absent

### Implemented (with evidence)
- **Clients CRUD, archive, search, detail lists, report link** — `S/Features/Clients/ClientListView.swift:9-50`, `ClientDetailView.swift:9-71`, `ClientEditView.swift:16-48`, `S/Persistence/ClientRepository.swift:15-60`. Archive toggles `isArchived` (`S/Models/Client.swift:13`); `all()`/`search()` exclude archived (`ClientRepository.swift:18,34`). Expanded fields goal/injuries/notes stored, edited, exported (`Client.swift:10-12`, `ClientEditView.swift:26-33`). Phone normalized E.164, US default (`S/Support/PhoneNumber.swift:5-25`).
- **Exercise library** — search + category filter (`S/Features/Exercises/ExerciseListView.swift:38-49`), `MetricSet` option set (`S/Models/Exercise.swift:4-21`), custom flag + badge (`ExerciseEditView.swift:104-105`), seed of 34 entries loaded when store empty (`S/Resources/seed_exercises.json`, `S/Persistence/SeedImporter.swift:14-41`, `S/RootView.swift:49-53`). Autocomplete picker in builder re-queries per keystroke (`S/Features/Workouts/WorkoutBuilderView.swift:106-143`).
- **Workout builder** — create/edit/delete/duplicate (`WorkoutBuilderView.swift:22-65`, `WorkoutListView.swift:23-29`, `S/Persistence/WorkoutRepository.swift:25-64`). `.onMove` wired (`WorkoutBuilderView.swift:42`, VM `move` at `WorkoutBuilderViewModel.swift:48-62`).
- **Scheduling** — client, start, duration 15–240, multi-workout, notes, weekly repeat with weekday toggles and 1–26 week horizon, calendar toggle (`S/Features/Schedule/SessionEditView.swift:50-112,138-187`). Template copied into frozen `WorkoutInstance` (`S/Persistence/SessionRepository.swift:266-304`), matching decisions #1.
- **Recurring sessions** (decisions #3 YES) — materialized rows sharing `seriesId` (`SessionRepository.swift:106-143`); pure `expandRecurrence` supports daily/weekly/interval/endDate/occurrenceCount (`:50-97`) but UI only emits weekly, interval 1, nil end (`SessionEditView.swift:157-163`).
- **EventKit push** (decisions #4 YES) — `S/Services/CalendarService.swift:42-68`, `Info.plist:21-22`; opt-in per session; cancel removes event for non-series sessions only (`S/Features/Session/SessionRunViewModel.swift:81-94`).
- **Run/record** — per-entry "Log set", ± buttons (weight ±5, reps ±1, duration ±15), distance text field, inputs driven by `metrics`, "Repeat last set" across sessions, delete set, status buttons completed/cancelled/no-show (`S/Features/Session/SessionRunView.swift:14-40,96-110,147-242`; `SessionRepository.swift:249-262`).
- **History** — client detail Upcoming / Recent(≤10) (`ClientDetailView.swift:21-36`, `ClientDetailViewModel.swift:17,45-54`); opening a past session shows its sets.
- **Reminders** — 24h/1h local notifications, nearest-32-sessions budget (`S/Services/NotificationService.swift:15-49,57-85`); text-reminder compose sheet (`SessionRunView.swift:44-61`, `S/Services/MessagingService.swift:5-64`).
- **Reporting P0** — top-set weight chart, Epley 1RM chart, PB callout, exercise picker limited to exercises with data, "Not enough data yet" at <2 points, completed-only filter (`S/Features/Reports/ClientReportView.swift:16-46,93-134`; `S/Persistence/ReportingQueries.swift:23-91`).
- **PDF report + ShareLink** — `S/Services/ReportExporter.swift:5-45,64-96`; `ClientReportView.swift:52-57`.
- **JSON export/import, schemaVersion, merge/replace, confirmations** — see Q6.
- **Onboarding data-loss notice** — one-time alert (`S/RootView.swift:44-48`) + Settings footer (`S/Features/Settings/SettingsView.swift:39-41`).
- **Biometric lock, passcode fallback** — `S/Services/AppLock.swift:22-44`, `S/Features/Lock/LockGateView.swift:5-31`. No network code anywhere (grep `URLSession|http`).
- **Store-failure recovery** (not in PRD) — `S/TrainMeApp.swift:4-100`.

### Partial
- **Injuries surfaced at session time** (§4.4) — shown only on `ClientDetailView.swift:14-16`; grep `injuries` in `S/Features/Session`, `S/Features/Schedule` → none.
- **lb/kg** (§4.5) — `Unit` enum has kg and per-exercise default-unit picker (`Exercise.swift:9`, `ExerciseEditView.swift:66-71`), but weight labels are hardcoded "lb" at `SessionRunView.swift:132,139,166`, `WorkoutBuilderView.swift:92,156`, `ClientReportView.swift:27,129`, `ReportExporter.swift:81`. Only distance uses `defaultUnit` (`SessionRunView.swift:193`). No global/per-client unit, no conversion.
- **Per-exercise history list** (§5.6) — `ReportingQueries.history()` exists (`:29,40-45`) but only feeds charts; no list UI of individual sets/dates.
- **Free-text creates library item** (§4.3) — new exercises only via Exercises tab; `ExercisePickerView` has no inline create.
- **Reorder exercises** (P1) — `.onMove` wired but no `EditButton`/`editMode` anywhere in `S/` (grep → none); `WorkoutRepository.reorder` has no caller.
- **Session notes** — captured at scheduling only (`SessionEditView.swift:105-107`); `SessionRunView` does not display notes; `updateNotes` has no UI caller.
- **RPE** — field exists (`S/Models/SetRecord.swift:14`) but always `nil` (`SessionRunViewModel.swift:63`); no input.
- **Calendar view** — day list under a graphical month picker (`ScheduleView.swift:10-32`); no week view.
- **schemaVersion handling** — rejects newer; older-version migration chain absent (comment `S/Services/Archive/DataArchive.swift:77-78`).
- **Export to Gmail** (decisions #4) — PDF goes via `ShareLink`; JSON export uses `.fileExporter` (Files picker) not the share sheet (`SettingsView.swift:50-55`).
- **At-rest encryption** — explicit `.completeFileProtection` only on export/report files (`DataArchive.swift:46`, `ReportExporter.swift:43`); store uses default `ModelConfiguration` (`S/Persistence/PersistenceController.swift:16`).
- **Fast entry / large tap targets** — bordered buttons + medium detent; nothing beyond `.font(.title2)` (`SessionRunView.swift:98,125`).
- **Sets metric** — accepted in `ExerciseEditView` but `SetEntryView` has no sets control (one record = one set).

### Absent
- Session volume, training consistency, client-level summary (§8 P1) — grep `volume|consisten` → none.
- Total-reps chart (§8 P0 "or") — only 1RM variant exists.
- PNG/image report — PDF only.
- CSV export — grep `csv` → none.
- **Periodic export prompt** (§9 P0) — `lastExportAt` written at `SettingsView.swift:57`, read only for the "Last export" label (`:18-20`); nothing nudges.
- Double-booking — absent, per decisions #3 NO.
- Edit/delete existing session; delete client; delete exercise — repository methods exist (`SessionRepository.delete/updateNotes`, `ClientRepository.delete`) with no UI caller; `SessionEditView` is create-only (title hardcoded "New Session", `:114`).
- Browse archived clients — `allIncludingArchived` used only by `ClientDetailViewModel.swift:34` and `ScheduleViewModel.swift:38`; no list shows archived clients, so unarchive is reachable only from an already-open detail screen.

## Q2: plan.md / structure.md vs. codebase and git

- **All ten phases have a commit** and every plan "Automated" checkbox is `[x]` with its test file present (plan.md:178-593). Test counts 4→49 across phases, 57 after a0a1c9c; `grep -c @Test Tests/` = 57.
- **All ten "Manual" checkboxes remain `[ ]`** (plan.md:183,224,270,310,360,398,437,472,510,595). No test touches `AppLock`, `MessageComposeView`, `ReportExporter`, `EventKitCalendarService`.
- **structure.md was never edited after b3a6d84**; plan.md edits were checkbox flips only.
- **Deviations from plan (landed differently):**
  - `VersionedSchema` "from first release" (plan.md:611) — absent; grep `VersionedSchema|SchemaMigrationPlan` in `S/`,`T/` → none.
  - Notification reschedule "on launch/foreground and after any session mutation" (plan.md:455) — only from `ScheduleViewModel.load()` (`:42`); no scenePhase hook; status changes from client detail call `ClientDetailViewModel.reload()` which does not reschedule (`ClientDetailView.swift:83`). a0a1c9c's commit body claims status changes "re-plan trainer alerts"; true from Schedule only.
  - Calendar push/remove in `SessionRepository.schedule/setStatus` (plan.md:490, structure.md:181-182) — instead in `SessionEditView.swift:165-185` and `SessionRunViewModel.swift:83-89`.
  - "Periodic export reminder" (plan.md:556-559) — label + footer only.
  - Recovery "import an export file" (plan.md:576-579) — `RecoveryView` has restore/reset only; text points to Settings (`TrainMeApp.swift:97`). `importData` doc says "used by tests and the recovery flow" but recovery does not call it (`DataArchive.swift:19`).
  - "Day/week" calendar (structure.md:103) — day only.
  - Report-rendering unit test (structure.md:230) — does not exist.
  - Files consolidated vs. structure.md: `WorkoutEntry` in `Workout.swift`; `AppRecurrence`/`WorkoutInstance`/`PlannedEntry` in `Session.swift`; `SetEntryView` in `SessionRunView.swift`; `ExerciseProgressChart` in `ClientReportView.swift`; `MessageComposeView` in `MessagingService.swift`; `CalendarView`→`ScheduleView`; no `SessionEditViewModel`, `ExerciseEditViewModel`, `SettingsViewModel`.
  - `search(prefix:)` does substring match (`S/Persistence/ExerciseRepository.swift:20-30`).
  - Bundle id `com.trainme.app`→`com.madacgrav.trainme`, team added (db09e7e).
- **Explicitly deferred in docs:** double-booking (plan.md:349); nothing marked TODO/v1.x in docs or code (grep → none).

## Q3: packaging and configuration

### What the repo declares
- `project.yml`: name TrainMe, iOS 26.0, Swift 6.0, strict concurrency complete; app target `sources: [Sources]`, team `ZD9JLCY7TF`, automatic signing, bundle `com.madacgrav.trainme`, `GENERATE_INFOPLIST_FILE: NO`, `INFOPLIST_FILE: Sources/Info.plist`; test target `sources: [Tests]`; one scheme (`project.yml:1-37`).
- `S/Info.plist` (28 lines): CFBundle keys via build vars, `CFBundleShortVersionString` 1.0, `CFBundleVersion` 1 (hardcoded), `NSCalendarsFullAccessUsageDescription`, `NSFaceIDUsageDescription`, `UILaunchScreen` = empty dict. **Absent:** `CFBundleDisplayName`, `UISupportedInterfaceOrientations` (both idioms), `UIRequiresFullScreen`, `UIBackgroundModes`, `CFBundleIcons`, any notification usage key (none required for local notifications).
- **No `.xcassets`, no `AppIcon.appiconset`, no `AccentColor`, no `.entitlements`, no `.xcconfig`, no `.xcprivacy`, no storyboard, no image files** in the repo (glob).
- Generated `TrainMe.xcodeproj` (gitignored, `.gitignore:11`) carries XcodeGen preset defaults not in project.yml: `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` (pbxproj:599,755), `CODE_SIGN_IDENTITY = "iPhone Developer"`, `TARGETED_DEVICE_FAMILY = "1,2"` (iPhone+iPad). `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` and `…INCLUDE_ALL_APPICON_ASSETS` not set anywhere. No `SUPPORTS_MACCATALYST`/`SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD`.
- App Resources phase contains exactly `seed_exercises.json`; test Resources phase contains exactly `export-v1.json` (pbxproj:472-487).
- `.github/` holds only `CODEOWNERS`; no workflows.

### XcodeGen behavior (from source/docs)
- `FileType.defaultFileTypes` maps `"xcassets"` → `buildPhase: .resources`, so any `*.xcassets` under `sources: [Sources]` is auto-added to Copy Bundle Resources (XcodeGen `Sources/ProjectSpec/FileType.swift`; `SourceGenerator.getDefaultBuildPhase`).
- `SettingPresets/Product_Platform/application_iOS.yml` sets `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` for iOS application targets (explains the pbxproj value). No accent-color preset.
- `.icon` (Icon Composer) bundles: built-in support added in XcodeGen 2.45.1 (CHANGELOG, PR #1600; `"icon": FileType(buildPhase: .resources)`). Earlier versions split the package into files (issue #1556; workaround `options.fileTypes: {icon: {file: true}}`). **Installed locally: XcodeGen 2.46.0.**

### iOS 26 / Xcode 26 icon expectations (Apple docs + secondary)
- **Asset-catalog path:** single 1024×1024 PNG in an `AppIcon` set, "Single Size"; optional Dark (transparent background) and Tinted (grayscale) appearance slots; system auto-generates other sizes and treatments (Apple "Configuring your app icon using an asset catalog"). `Contents.json` shape per secondary sources: `images[]` entries with `"idiom":"universal"`, `"platform":"ios"`, `"size":"1024x1024"`, optional `"appearances":[{"appearance":"luminosity","value":"dark"|"tinted"}]`, plus `info {author, version:1}`. Apple does not publish the schema for `platform`/`appearances`.
- **Icon Composer path:** a `.icon` package (`icon.json` + `Assets/*.svg|png`), dropped beside (not inside) the catalog; `ASSETCATALOG_COMPILER_APPICON_NAME` = its basename; "replaces any existing icon asset catalog"; Xcode generates older-OS images from it; Apple recommends keeping the catalog icon if an existing icon must appear on older releases. Layers: SVG/PNG, max four groups; appearances default/dark/mono; canvas 1024×1024; do not pre-mask. `icon.json` schema is undocumented by Apple. **Installed locally: `Icon Composer.app` in Xcode bundle; `xcrun actool` present** (can compile a `.icon`, per forum reports; no official CLI generator).
- **Alpha/corners:** HIG says provide square, unmasked, full-bleed opaque artwork; system applies rounded corners. App Store Connect validation rejects a large icon with an alpha channel (forum reports; not in current Apple docs). Check with `sips -g hasAlpha`. Color space sRGB or Display P3.
- **Marketing icon:** the same 1024 slot serves the App Store in the catalog path; the `.icon` covers the App Store in the Composer path.

## Q4: navigation and screens

- **Entry:** `TrainMeApp.swift:46-66` switches `AppBootstrap.state`: `.ready` → `LockGateView { RootView }`; `.failed` → `RecoveryView` (outside the lock). No `.environment`/`.modelContainer`; repositories constructed inline per tab (`RootView.swift:15-41`).
- **Tabs** (`RootView.swift:13-43`, iOS 18 `Tab` API): Schedule (`calendar`), Clients (`person.2`), Workouts (`list.clipboard`), Exercises (`dumbbell`), Settings (`gearshape`). Each tab owns a `NavigationStack`. No `NavigationPath`, deep links, or URL handling.
- **Pushes:** Schedule row → `SessionRunView`; Clients row → `ClientDetailView` → {`ClientReportView`, `SessionRunView`}. **Sheets:** `ClientEditView`, `ExerciseEditView`, `WorkoutBuilderView` (nested `ExercisePickerView`, `EntryTargetEditView`), `SessionEditView`, `SetEntryView`, `MessageComposeView`. Every View struct in `S/Features` is presented from somewhere (grep per name); no orphans.
- **Empty states:** `ContentUnavailableView` on Clients (`ClientListView.swift:29-36`, "No clients yet"/"No matches"), Exercises (`:33-37`, same text for empty and no-match), Workouts (`:33-37`), Schedule day (`:28-32`), Report (`ClientReportView.swift:9-15`), chart (`:99-105`); plain text in client detail (`:22-24,30-32`) and session edit (`:63-65`). **None** for builder's empty Exercises section, `ExercisePickerView` results, or a `SessionRunView` with no instances. Overlays bind to arrays that start `[]`, so they can flash before first load.
- **First launch:** no onboarding flow. One-time backup alert gated by `hasSeenBackupNotice` (`RootView.swift:6-10,44-48`), shown after unlock. Seed import runs in `RootView.task` each appearance, guarded by exercise count (`:49-53`, `SeedImporter.swift:15`). Notification auth requested immediately after, result discarded (`:54`). Calendar auth requested lazily at save (`SessionEditView.swift:165,182`). Lock gate re-creates `content()` on each unlock, so `.task` re-runs.
- **Error presentation:** only `RecoveryView` (store failure), Settings `statusMessage` text (`SettingsView.swift:43-47,56-59,90-101`), and inline phone validation (`ClientEditView.swift:20-24`). All other failures are `try?` with no UI: full list in `S/Features/*ViewModel.swift` and views (e.g. `SessionRunViewModel.swift:38-90`, `SessionEditView.swift:132-184`, `ClientReportView.swift:84`, `SettingsView.swift:29`). Save-failure behavior differs: Client/Workout sheets stay open silently; Exercise/Session sheets dismiss and call `onSaved` regardless (`ExerciseEditView.swift:80-86`, `SessionEditView.swift:121-127`).
- **No TODO/FIXME/print/placeholder text** in `S/` (grep). Empty closures only in cancel buttons.
- **Observed quirks (as-is):** `ClientDetailView.swift:86` passes a formatted date as `SessionRow`'s `clientName`; `SessionRunView.targetText` shows sets×reps only when both present (differs from builder's `targetSummary`); `SetEntryView` "Log" never disabled (0/0 set loggable, `:219-233`); "Repeat last set" with no prior set is a silent no-op (`:202-211`); status buttons vanish after leaving `.scheduled`, no revert path (`:28-40`); destructive actions (delete workout, delete set, archive, status change) have no confirmation; after archive the detail view does not pop; Clients list not reloaded after detail edits until its own `.task`/`onChange`; Settings has no lock, units, notifications, calendar, or about/version controls (`SettingsView.swift:24-49`); "Text reminder" hidden when `canSendText` false (simulator).

## Q5: scheduling, recurrence, notifications, calendar

- **Model** (`S/Models/Session.swift`): `SessionStatus` scheduled/completed/cancelled/noShow (`:4-6`); `Session` has `clientId: UUID` (no relationship), `startAt/endAt`, `statusRaw`, `notes`, cascade `instances`, `seriesId?`, `recurrenceData: Data?` (JSON `AppRecurrence`), `eventIdentifier?` (`:22-65`). `AppRecurrence` frequency daily/weekly, interval, weekdays 1=Sun…7, endDate?, occurrenceCount? (`:10-20`). DTO decode of recurrence is `try?` → nil on failure (`SessionDTO.swift:83`).
- **Create only:** `SessionEditView` is the sole creation path and the sole presenter is Schedule's Add button (`ScheduleView.swift:36-47`). Workouts attach as `Set<UUID>` → `Array` (unordered, `SessionEditView.swift:151`). Save dismisses even if `try?` schedule fails (`:121-127,164,181`).
- **Series:** `scheduleSeries` materializes one row per occurrence with fresh UUIDs, shared `seriesId`, copied notes, own frozen instances; exclusive horizon `startAt + N weeks − 1s` (`SessionRepository.swift:106-143`). No parent row. **No series-level edit/cancel**; cancelling one occurrence changes only that row and skips calendar removal when `seriesId != nil` (`SessionRunViewModel.swift:81-94`), leaving the shared recurring EKEvent in place. `setEventIdentifierForSeries` writes the same id to every row (`:191-200`). Daily/interval/endDate/occurrenceCount are reachable only from tests.
- **Schedule view:** graphical month `DatePicker` + single-day list (`ScheduleView.swift:10-32`); `load()` fetches `[dayStart, dayEnd)` all statuses, loads all clients incl. archived, then `rescheduleNotifications()` (`ScheduleViewModel.swift:32-51`). Triggers: `.task`, date change, `onSaved`, `onStatusChanged` from Schedule.
- **Notifications** (`S/Services/NotificationService.swift`): auth requested once in `RootView.task` (`:54`), options alert/sound/badge, result discarded; no status check before `add`; denial → `add` errors swallowed (`:78`). `selectAlerts` keeps nearest `cap/2 = 32` future scheduled sessions × {24h, 1h}, drops past fire dates (`:15-49`); ids `sess-<uuid>-24h|1h`; content "Session tomorrow"/"Session in 1 hour", body "<client> at <time>". `reschedule` calls `removeAllPendingNotificationRequests()` (all, not just `sess-`) then re-adds with non-repeating `UNCalendarNotificationTrigger` (`:63-84`). Only caller: `ScheduleViewModel.load()`. No scenePhase/foreground/launch hook; no reschedule from client-detail status changes.
- **Calendar** (`S/Services/CalendarService.swift`): `requestFullAccessToEvents` with `try?` → false (`:45-47`); `push` returns nil unless `.fullAccess`, always creates a new `EKEvent` titled "Training: <client>" in `defaultCalendarForNewEvents` (nil not checked), `span: .futureEvents` (`:49-62`); no update-in-place; `remove` silent if event not found, no auth check (`:64-67`). `makeEKRecurrenceRule` maps daily/weekly, interval≥1, weekdays, occurrenceCount then endDate (`:6-32`). No Settings toggle; opt-in per session. Denial → push silently skipped, session saved without `eventIdentifier`. No calendar action on completed/noShow/delete/client archive.
- **Messaging** (`S/Services/MessagingService.swift`): `canSendText` main-actor (`:7-9`); template "Hi <first>, reminder: our session <tomorrow|date> at <time> — see you then!" (`:11-18`); `MFMessageComposeViewController` wrapper ignores result (`:23-64`).
- **Status transitions:** only via `SessionRepository.setStatus` (`:177-182`) from `SessionRunViewModel.setStatus`; UI exposes them only while `.scheduled`.
- **No UI callers:** `SessionRepository.delete`, `updateNotes`, `get` (outside VM refresh), `ClientRepository.delete`. `insertSession` silently skips unknown workout ids (`:284`).

## Q6: data safety

- **Export** (`S/Services/Archive/DataArchive.swift:24-48`): `ArchiveV1.Envelope` with `schemaVersion` 1, `exportedAt`, `appVersion` (from bundle, default "0"), arrays clients/exercises/workouts/sessions/setRecords; ISO-8601 dates, pretty + sorted keys; default UUID encoding. File `TrainMe Export <yyyy-MM-dd>.json` in `tmp/Exports/` (folder wiped first) with `.completeFileProtection`. Presented via `.fileExporter` with `UTType.json` (`SettingsView.swift:50-55`); on success sets `lastExportAt` + "Export saved."; `.failure` ignored; export throw → nothing shown (`:29-30`). No CSV.
- **Import** (`DataArchive.swift:58-86`): `.fileImporter([.json])` → mode dialog → (Replace only) second alert "Replace everything?… This cannot be undone." (`SettingsView.swift:64-86`); Merge has one dialog. Security-scoped access wrapped; read via `try?` → `.unreadable`. `VersionProbe` decoded first; `> 1` → `newerThanApp`; `≤ 1` (including 0/negative) decoded as v1; no migration chain. **Replace:** `deleteAll()` SetRecord→Session→Workout→Exercise→Client then upsert. **Merge:** upsert by id — clients field-update (`updatedAt = .now`, `ClientDTO.swift:30-38`), exercises field-update (timestamps untouched), workouts/sessions/setRecords delete-and-recreate preserving archive ids (`:100-172`). Local rows absent from archive survive in merge. One `save()` at end; no explicit rollback. **No pre-import backup.** Errors collapse to two messages (`SettingsView.swift:90-101`).
- **StoreBackup** (`S/Persistence/StoreBackup.swift`): triggered only from `AppBootstrap.init` via `try?` (`TrainMeApp.swift:16-17`) when `lastRunAppVersion` exists and differs; first install records version only. One backup retained at `<AppSupport>/Backups/pre-<version>/` (store, -wal, -shm); previous backups removed before copy (`:23`). Version recorded only after success. `restoreLatest` deletes live store+wal+shm then copies back (`:38-55`); reachable only from `RecoveryView` ("Restore last backup", "Start fresh" with confirm alert) when the container fails to open (`TrainMeApp.swift:52-100`). No manual backup, no Settings restore.
- **PersistenceController** (`:6-18`): 8 model types, `ModelConfiguration(isStoredInMemoryOnly:)`, no CloudKit/App Group, no `VersionedSchema`/`SchemaMigrationPlan`; container failure → `.failed(localizedDescription)`.
- **Seed** (`SeedImporter.swift:14-41`): runs when exercise count == 0; silent if resource missing; new UUIDs, `isCustom: false`; can re-run after Replace-import or store reset.
- **Export prompting:** none beyond the "Last export: Never/<date>" label; `lastExportAt` has no other reader (grep).
- **Data-loss messaging:** one-time alert (`RootView.swift:44-48`), Settings footer (`SettingsView.swift:40`), replace alert, `RecoveryView` copy. No onboarding flow.
- **AppLock** (`S/Services/AppLock.swift:22-48`): device policy `.deviceOwnerAuthentication` (passcode fallback); simulator `.deviceOwnerAuthenticationWithBiometrics` (ac5a23f); fresh `LAContext` each attempt; `canEvaluatePolicy` false → `isUnlocked = true` silently; evaluate failure/cancel → stays locked, no message; re-entrancy guard. Gate locks on `.background`, re-auths on `.active`, ignores `.inactive` (`LockGateView.swift:19-30`); no grace period; no Settings toggle; `RecoveryView` is outside the gate.
- **ReportExporter**: PDF only via `ImageRenderer` 612×792, `tmp/Reports/`, sanitized filename, `.complete` protection, swept on view disappear (`ReportExporter.swift:6-60`, `ClientReportView.swift:68-72`). PDF contains top-set chart + PB, not the 1RM chart (`ReportExporter.swift:64-96`).
- **UserDefaults keys:** `hasSeenBackupNotice`, `lastExportAt`, `lastRunAppVersion`.

## Q7: test suite

- **14 files, 57 top-level `@Test` funcs, no `@Suite`, no shared helpers**; each file defines private `makeRepo/makeEnv` on `PersistenceController.makeContainer(inMemory: true)`. All `@testable import TrainMe`.
- **Per file:** `ArchiveRoundTripTests` (5: replace round-trip, merge upsert, newer-version reject, unreadable reject, **golden v1 fixture import via `Bundle(for: BundleToken.self)` `:148-154`**); `CalendarMappingTests` (4, `makeEKRecurrenceRule` only); `ClientDetailViewModelTests` (2, static `splitSessions` only); `ClientRepositoryTests` (5); `ExerciseRepositoryTests` (2); `NotificationSchedulingTests` (5, `selectAlerts` + `reminderBody`); `PhoneNumberTests` (4); `RecordingTests` (3); `ReportingTests` (5 incl. `epley1RM`); `SchedulingTests` (6, `expandRecurrence`); `SeedImporterTests` (2); `SessionRepositoryTests` (7); `StoreBackupTests` (3, real temp dirs, fake store bytes, per-test `UserDefaults` suite); `WorkoutRepositoryTests` (4).
- **Fixture** `T/Fixtures/export-v1.json`: schemaVersion 1, 2 clients, 3 exercises (metrics as bitmask ints), 1 workout/2 entries, 1 completed session, 2 sets; reaches the test bundle through XcodeGen's `sources: [Tests]` → test Resources phase.
- **No tests for:** `AppLock`; `EventKitCalendarService.push/remove/requestAccess`; `LocalNotificationService.requestAuthorization/reschedule`; `MessageComposeView`/`canSendText`; `ReportExporter`; `ArchiveV1` types directly; `SessionRepository.setEventIdentifier/…ForSeries/updateNotes`; `ReportingQueries.history`; `ExerciseRepository.createAll/update` (direct); `PersistenceController` on-disk branch; any `@Model` migration; every view model except the one static function; every SwiftUI view; `AppBootstrap`/`RecoveryView`; `Info.plist`. Replace-import into a non-empty store and `importArchive(url:)` failure paths untested.
- **How run:** scheme `TrainMe` tests `TrainMeTests` (`project.yml:31-37`); README: `xcodegen generate` then `xcodebuild -scheme TrainMe -destination 'platform=iOS Simulator,name=iPhone 17' test` with `DEVELOPER_DIR` workaround (`README.md:23-36`). No UI-test target, no test plan, no CI workflow.

## Cross-Cutting Observations

- **Error policy is uniformly `try?`-and-continue** across view models, services, and bootstrap; the only user-facing error surfaces are the recovery screen, Settings status text, and phone validation. Sheets disagree on whether a failed save dismisses.
- **Notification state is owned by the Schedule tab.** Every mutation path that bypasses `ScheduleViewModel.load()` (client-detail status change, imports, app foreground) leaves pending alerts stale.
- **Series are flat rows.** Nothing in the UI operates on a series after creation, and the single shared EKEvent is never updated or removed.
- **Unit handling is cosmetic.** `Unit.kg` exists in the model and picker, but every weight string is literal "lb".
- **Repository surface exceeds UI surface:** delete session/client, update notes, reorder, daily/interval recurrence, `history()` all exist without callers.
- **Packaging is minimal:** no asset catalog, icon, accent color, display name, orientation keys, entitlements, privacy manifest, or CI. The generated project already expects an `AppIcon` set by name; the installed toolchain (XcodeGen 2.46.0, Xcode 26 with Icon Composer and actool) supports both the single-1024 catalog path and the `.icon` package path.
- **Docs drift:** structure.md file layout and several plan.md wiring statements (calendar in repository, reschedule on foreground, periodic export prompt, VersionedSchema, recovery import) describe behavior that landed differently or not at all; plan.md manual checkpoints were never ticked.

## Open Areas

- Apple does not publish the `Contents.json` `platform`/`appearances` schema or the `.icon` `icon.json` schema; findings rely on secondary sources and real-world files.
- Whether `.icon` fallback to a catalog icon on older iOS behaves consistently varies by Xcode 26.x per forum reports; irrelevant at iOS 26 min target but noted.
- The App Store "no alpha" rule for the 1024 icon comes from validation reports, not current Apple docs.
- Actual on-device behavior (Face ID flows, EventKit writes, notification delivery, PDF appearance, tap-target sizing) was not exercised; all findings are static.
- `defaultCalendarForNewEvents == nil` handling and `removeAllPendingNotificationRequests` side effects on non-app notifications were not tested at runtime.
