# Design Discussion

Owner answers (2026-10-26): scope = icon + P0 gap fixes; icon format = Icon Composer
`.icon`; concept = dumbbell + rising line; gap list = GitHub issues **and** `BACKLOG.md`.

## Current State

TrainMe v1 is feature-complete against PRD §5 P0 except one item, but has a thin
packaging layer and several places where the plan's wiring landed differently
(`research.md` Q1–Q2).

- **Packaging:** no `.xcassets`, icon, accent color, `CFBundleDisplayName`, orientation
  keys, entitlements, privacy manifest, or CI. The generated pbxproj already carries
  `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` from XcodeGen's iOS preset
  (`research.md` Q3). Toolchain: XcodeGen 2.46.0 (built-in `.icon` support since
  2.45.1), Xcode 26 with Icon Composer.app and `actool`.
- **P0 gap:** periodic export prompt (PRD §9) is only a "Last export" label;
  `lastExportAt` has no other reader (`SettingsView.swift:8,18-20,57`).
- **P0 partials:** injuries never shown in `S/Features/Session` or `S/Features/Schedule`
  (grep → none); weight labels hardcoded "lb" at `SessionRunView.swift:132,139,166`,
  `WorkoutBuilderView.swift:92,156`, `ClientReportView.swift:27,129`,
  `ReportExporter.swift:81` despite `Unit.kg` and a per-exercise picker
  (`Exercise.swift:9`, `ExerciseEditView.swift:66-71`); `SessionEditView` is create-only
  (`:114`) and `SessionRepository.delete/updateNotes` have no UI caller; session notes
  are not displayed in `SessionRunView`.
- **Safety/UX:** destructive actions (delete workout `WorkoutListView.swift:23-26`,
  delete set `SessionRunView.swift:108-110`, archive `ClientDetailView.swift:57-62`,
  status change `SessionRunView.swift:28-40`) have no confirmation; errors are
  uniformly `try?`-swallowed; Exercise/Session sheets dismiss even on failed save
  (`ExerciseEditView.swift:80-86`, `SessionEditView.swift:121-127`).
- **Notifications:** rescheduled only inside `ScheduleViewModel.load()` (`:42`); no
  scenePhase hook; client-detail status changes call `reload()` which does not
  reschedule (`ClientDetailView.swift:83`); `reschedule` calls
  `removeAllPendingNotificationRequests()` (`NotificationService.swift:63-84`).
- **Tests:** 57, repositories and pure functions only; nothing for AppLock, EventKit
  writes, notification delivery, ReportExporter, view models, or UI (`research.md` Q7).
- **Docs:** plan.md manual checkpoints all unticked; structure.md never updated.

## Desired End State

1. The app ships with a Liquid Glass icon (`Sources/AppIcon.icon`) that renders in
   default, dark, and mono appearances; `xcodegen generate` + `xcodebuild` succeed;
   the icon is visible on the simulator home screen. An `Assets.xcassets` exists with
   an `AccentColor` matching the icon palette, and `Info.plist` gains a display name
   and portrait-only iPhone orientations.
2. Every P0 gap/partial above is closed with a focused change and a test where the
   logic is testable off-UI:
   - Export staleness prompt (banner + one-time alert after N days / M completed
     sessions since last export).
   - Injuries/limitations banner at the top of `SessionRunView` when non-empty.
   - A single unit-formatting helper; all weight strings use the exercise's
     `defaultUnit`; new exercises default from a global unit setting.
   - Edit and delete an existing session (non-series) from `SessionRunView`, with
     calendar event update/removal and notification reschedule.
   - Session notes displayed (and editable) in `SessionRunView`.
   - Confirmation dialogs on delete workout, delete set, archive client, and
     cancelled/no-show status.
   - Notification reschedule on `scenePhase == .active` and after every status change
     regardless of presenting screen; `reschedule` removes only `sess-*` identifiers.
   - Failed saves surface an inline error and do not dismiss the sheet.
3. `BACKLOG.md` at the repo root lists every remaining gap (P1/P2 and deferred items)
   with PRD section refs; the same items exist as GitHub issues labeled `enhancement`
   plus a new `priority:P1`/`priority:P2` label pair; README links the backlog.
4. Verification: all existing tests pass; new tests for export-staleness rule, unit
   formatting, session update/delete repository methods, and `sess-*`-only removal
   selection; a simulator launch shows the icon and the injuries banner.

## Patterns to Follow

- **Repository-protocol + DTO boundary** (`SessionRepository.swift:14-19,101-104`):
  new mutations (`update(_:)`, `delete(id:)` already exists) go on the protocol and
  the `@ModelActor`, returning/accepting DTOs only.
- **Pure, testable decision functions beside their service**: `selectAlerts`
  (`NotificationService.swift:15-49`), `expandRecurrence`
  (`SessionRepository.swift:50-97`). The export-staleness rule and unit formatter
  should be free functions tested the same way.
- **Two-step destructive confirmation** already used for Replace import
  (`SettingsView.swift:70-86`): `confirmationDialog` for the choice, `.alert` with a
  destructive role for the irreversible step. Reuse for session delete; a single
  `.confirmationDialog` suffices for the lighter cases.
- **`ContentUnavailableView` for empty states** (`ClientListView.swift:29-36`) and
  Form-section status text for feedback (`SettingsView.swift:43-47`).
- **`onStatusChanged` callback injection** (`SessionRunViewModel.swift:26`,
  `ScheduleView.swift:22`) — extend to an `onSessionMutated` that both presenters wire
  to a shared reschedule.
- **Sheet save semantics to copy:** Client/Workout sheets stay open on failure
  (`ClientEditView.swift:43-48`). **Do not copy** Exercise/Session's dismiss-regardless.
- **Lock on `.background` only** (`LockGateView.swift:19-30`) — the new scenePhase
  observer for notifications must likewise ignore `.inactive`.
- **Anti-patterns to avoid:** `removeAllPendingNotificationRequests()` (clobbers
  non-app requests); hardcoded unit strings; `try?` on user-initiated saves without
  surfacing; adding `@Query`/`modelContext` to views (none exist today).

## Design Decisions

1. **Icon format: `Sources/AppIcon.icon` package, hand-authored.** `icon.json` plus
   `Assets/*.svg` layers (background gradient, dumbbell, rising line), committed as
   plain files so it diffs and regenerates. XcodeGen 2.46 adds it to Resources
   automatically; the preset `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` already
   matches. Validation gate: `xcrun actool` compile + full build + simulator
   screenshot. If `icon.json` fails to compile after two iterations, fall back to a
   single-1024 `AppIcon.appiconset` (no-alpha PNG rendered from the same SVGs) and
   record the reason in BACKLOG.
2. **Icon concept: dumbbell + rising line.** Palette: deep teal→indigo gradient
   background, white dumbbell, warm amber rising stroke. Mono/tinted appearance uses
   the dumbbell+line silhouette only. Square, unmasked, full-bleed layers per HIG.
3. **Asset catalog added alongside the `.icon`** for `AccentColor` (amber from the
   icon) and future images; `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME:
   AccentColor` set explicitly in `project.yml`.
4. **Info.plist additions:** `CFBundleDisplayName` "TrainMe", iPhone orientations
   portrait only, iPad left as-is (device family 1,2 stays; no iPad layout work).
5. **Export staleness rule:** pure `exportReminderDue(lastExportAt:now:completedSince:)`
   → due when ≥14 days or ≥5 completed sessions since last export. Surfaced as a
   non-blocking banner at the top of Schedule and a badge on Settings; tapping opens
   Settings. No modal nag beyond the existing first-run alert.
6. **Units:** add `@AppStorage("defaultWeightUnit")` (lb default) read by
   `ExerciseEditView` for new exercises; add `WeightFormatter.string(_:unit:)` used by
   every weight label; stepper increment 5 lb / 2.5 kg. No conversion of stored
   values — the exercise's `defaultUnit` is the unit of record.
7. **Session edit/delete (non-series only):** reuse `SessionEditView` with an
   `existing: SessionDTO?` parameter (same pattern as `ClientEditView`); editing
   changes time/duration/notes/client; workouts are not re-attached (instances are
   frozen). Delete removes the session, its set records, and its calendar event, then
   reschedules notifications. Series rows show "Part of a repeating series — edit
   individually is not available yet" and offer delete-this-occurrence only.
8. **Notification ownership moves to a tiny `ReminderCoordinator`** (`@MainActor`,
   owns one `LocalNotificationService` and the session repo) injected into
   `ScheduleViewModel`, `ClientDetailViewModel`, and `SessionRunViewModel`; called on
   scenePhase `.active` from `RootView` and after every session mutation.
   `reschedule` removes by collected `sess-*` identifiers.
9. **Confirmations:** single `confirmationDialog` for delete workout, delete set,
   archive; `.alert` destructive for cancelled/no-show and session delete.
10. **Failed-save surfacing:** view models expose `errorMessage: String?`; sheets show
    it in a Form footer and stay open. Background/bootstrap `try?` paths stay as-is.
11. **Gap list:** `BACKLOG.md` grouped P1 / P2 / Deferred-by-decision / Tech-debt, each
    row linking its PRD section and GitHub issue. Issues created via `gh issue create`
    with `enhancement` + new `priority:P1|P2` labels; one issue per backlog row.
12. **Branching:** all work on the current `fix/review-findings` branch continues in a
    new branch `feature/icon-and-p0-gaps` cut from it; one PR.

## What We're NOT Doing

- P1 reporting (session volume, consistency, client summary), total-reps chart,
  PNG report, CSV export → BACKLOG.
- Series-level edit/cancel and shared EKEvent update; daily/interval recurrence UI;
  week calendar view → BACKLOG.
- Per-exercise history list; inline exercise creation from the picker; RPE input;
  delete client / delete exercise; browse-archived-clients screen → BACKLOG.
- `VersionedSchema`/migration plan, pre-import backup, import rollback → BACKLOG
  (tech-debt).
- UI/snapshot tests, CI workflow, privacy manifest, entitlements → BACKLOG.
- iPad layout, Mac Catalyst, alternate icons, Settings toggles for lock/calendar.
- Converting stored weights between units.

## Open Risks

- **`icon.json` schema is undocumented.** Mitigation: start from a file exported by
  Icon Composer.app (open it once, save, inspect), keep layers ≤4 groups, validate
  with `actool`, keep the appiconset fallback path cheap.
- **Fallback-icon behavior varies across Xcode 26.x** per forum reports; irrelevant at
  iOS 26 min target but a build warning is possible.
- **Unit label sweep** touches eight call sites across four files; a missed site shows
  "lb" for a kg exercise. Mitigation: grep gate for the literal `lb` in `S/Features`
  and `S/Services` at the end of the phase.
- **Session edit + calendar:** `push` always creates a new event
  (`CalendarService.swift:49-62`); edit needs an `update(eventIdentifier:)` path and
  must handle a deleted/moved event gracefully (nil → re-push).
- **ReminderCoordinator wiring** changes three view-model initializers; tests
  constructing them directly (only `ClientDetailViewModelTests` static calls today)
  are unaffected, but RootView construction must stay the single composition point.
- **GitHub issue creation is an outward-facing action**; it will be done once, at the
  end, after the owner confirms the BACKLOG text.
