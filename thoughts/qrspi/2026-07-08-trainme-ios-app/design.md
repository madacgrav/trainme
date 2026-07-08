# Design Discussion

## Current State

Greenfield repo (`research.md` Q1): only `PRD.md`, `README.md` (`# trainme`),
`LICENSE`, and a mismatched Java/Kotlin/Gradle `.gitignore`. No Swift source, no
Xcode project. Toolchain is now ready — Xcode 26.6 + iOS 26.5 SDK/simulators
installed (`research.md` Q1, updated), but `xcode-select` still points at Command
Line Tools, so build commands need a `DEVELOPER_DIR=/Applications/Xcode.app/Contents/
Developer` prefix (or a one-time `sudo xcode-select -s`). `xcodegen` and
`xcodebuildmcp` are not yet installed.

Owner decisions are settled in `decisions.md`: simple template versioning, expanded
client fields, recurring sessions in / double-booking out, system-calendar push in.

## Desired End State

A native iOS app (SwiftUI, iOS 26 min) delivering the PRD's P0/P1 loop: client CRUD →
exercise library + workout templates → schedule (incl. recurring) → run/record a
session → per-client/per-exercise progression charts → reminders (local + compose
sheets) → JSON export/import → biometric app lock. **Verification**: the domain,
repository, and export/import round-trip are covered by Swift Testing against an
in-memory `ModelContainer`; each vertical slice builds and launches on the iOS 26.5
simulator and is demoable. "Correct" = a workout can be built, scheduled, recorded,
and its set records charted; an export re-imports to an identical object graph.

## Patterns to Follow

Greenfield — no codebase patterns exist to match; the following come from platform
research and become the house style:

- **SwiftData behind a repository protocol** (`research.md` Q2): `@Query` cannot live
  behind a protocol boundary, so views never use `@Query`/`@Environment(\.modelContext)`
  directly. Repositories wrap `FetchDescriptor` and expose results to `@Observable`
  view models.
- **Manual identity/timestamps** (`research.md` Q2): every `@Model` carries
  `@Attribute(.unique) var id: UUID` and `createdAt`/`updatedAt: Date`; `updatedAt` is
  stamped centrally in repository mutation methods (no framework auto-update).
- **Notification budgeting** (`research.md` Q3): honor the 64-pending cap — schedule
  only the nearest N session alerts, reschedule on launch/foreground.
- **Sparse-data guard** (`research.md` Q4): charts check `data.count < 2` and render a
  "not enough data yet" placeholder; no framework fallback exists.
- **Security-scoped file access** (`research.md` Q5): wrap imported/exported URLs in
  `startAccessingSecurityScopedResource()` / `defer { stop… }`.
- **Codable DTOs separate from `@Model`** (`research.md` Q5): the export schema is
  plain `Codable` structs (UUID cross-refs, `.iso8601` dates), decoupled from the
  persistence models — this doubles as the v2 sync payload shape.

**Anti-patterns to avoid** (flagged by research): do NOT put `@Query` in views (breaks
the repository boundary, `research.md` Q2); do NOT pass `@Model` instances or
`ModelContext` across actor boundaries — only Sendable DTOs or `PersistentIdentifier`
leave a repository, and don't assume `@ModelActor` runs off-main without
`Task.detached` (`research.md` Q2); do NOT re-lock on scenePhase `.inactive` (Face ID's own UI trips
it — lock on `.background` only, `research.md` Q6); do NOT use `.append()` in a loop on
to-many relationships (~700× slower than `append(contentsOf:)`, `research.md` Q2).

## Design Decisions

1. **Deployment target: iOS 26.5, single runtime.** One simulator to test; unlocks
   latest SwiftData (`#Unique`/`#Index`, inheritance) and chart APIs. Device reach is
   irrelevant for a single-user personal app.
2. **Persistence: SwiftData behind protocol-typed `@ModelActor` repositories (owner
   call).** Each repository is a `@ModelActor` actor conforming to a protocol
   (`ClientRepository`, `WorkoutRepository`, `SessionRepository`, …) with async
   methods. Consequence: `@Model` objects are not Sendable and cannot cross the actor
   boundary (`research.md` Q2), so repositories accept/return **plain Sendable domain
   structs (DTOs)** — the dual-model pattern. The export-schema Codable types serve as
   these domain structs, so the mapping is written once and doubles as the v2 sync
   payload. Known `@ModelActor` main-thread anomaly is mitigated by invoking
   repositories from `Task.detached` where off-main execution matters, and by never
   assuming an isolation thread in repository code.
3. **Project generation: XcodeGen.** Commit `project.yml`; gitignore the generated
   `.xcodeproj`. Replace the Java `.gitignore` with a Swift/Xcode one. Agent-friendly,
   no GUI, no project-file merge conflicts.
4. **Calendar: EventKit one-way push to the default calendar, full access.** Store
   each session's `eventIdentifier` to update/remove on edit or cancellation; full
   access is required to read events back (`research.md` Q7). Recurring sessions use
   `EKRecurrenceRule` mirrored from the app's own recurrence model. No calendar
   picker, no Google-specific integration. Gmail is only a share-sheet target for
   reports/exports.
5. **App structure: single app target, layered folders.** `Models/` (`@Model`),
   `Persistence/` (`ModelContainer` setup + repositories), `Services/` (notifications,
   messaging compose, calendar, export/import, biometrics — each behind a small
   protocol per the PRD's "isolate messaging behind a service"), `Features/` (SwiftUI
   views + `@Observable` view models per feature), `Resources/` (seed library JSON).
6. **Template → instance copy at scheduling** (`decisions.md` 1): scheduling copies the
   workout template into a `WorkoutInstance` holding planned params; recording writes
   `SetRecord`s onto it. Editing a template never touches existing sessions.
7. **Canonical exercises** (PRD §4.3): every `SetRecord` references an exercise by
   `id`, never free text. Ship a **small** seed library (~25–35 common movements) as a
   bundled JSON resource imported on first launch (owner call: keep it small — the
   trainer uses custom exercise names, so custom creation is the primary path).
   Autocomplete resolves to existing items; free text only creates a new library item.
8. **Export schema: versioned JSON.** Top-level `schemaVersion: Int`, `exportedAt`,
   arrays `clients`/`exercises`/`workouts`/`sessions`/`setRecords` cross-referenced by
   UUID; import validates `schemaVersion`, offers merge (upsert-by-id) vs replace, and
   confirms before overwriting (PRD §9). `.fileExporter`/`.fileImporter` drive it.
9. **Reminders: trainer local notifications + tap-to-send compose sheets.**
   `UNCalendarNotificationTrigger` for 24h/1h alerts (nearest-N budget); client texts
   via `MFMessageComposeViewController` wrapped in `UIViewControllerRepresentable`
   (`research.md` Q3). No automated send — impossible on iOS.
10. **Security: biometric launch gate + default Data Protection.**
    `LAContext.evaluatePolicy(.deviceOwnerAuthentication)` (passcode fallback built in)
    gated on `scenePhase`, lock on `.background`; `NSFaceIDUsageDescription` set. Rely
    on the sandbox's default `.completeUntilFirstUserAuthentication` at rest; secrets
    (none expected in v1) would go to Keychain, not the store (`research.md` Q6).

## What We're NOT Doing

Billing/invoicing/package tracking; any client-facing app or login; multi-trainer/team;
cloud account, backend, or CloudKit sync; nutrition, body-measurement, or photo
tracking; Android; automated/scheduled SMS or email; double-booking detection; a
calendar-account picker or direct Google Calendar API; iOS system-calendar two-way
sync (push is one-way only). v1 backup = manual export only.

## Open Risks

- **SwiftData migration fragility** (`research.md` Q2): documented lightweight-migration
  bugs. Mitigation: `VersionedSchema` from first release, pre-migration store-file
  backup on app-version change, and rebuild-from-export as the recovery path; export
  archive uses frozen per-version types + golden-fixture tests (see plan.md
  "Versioning policy").
- **`@Attribute(.unique)` blocks CloudKit sync** (`research.md` Q2): acceptable — the
  v2 sync path is a custom server keyed on the export schema, not CloudKit.
- **`eventIdentifier` instability** (`research.md` Q7): a full CalDAV resync can
  reassign IDs, orphaning app-managed events. Low impact for local/default calendar;
  note `calendarItemExternalIdentifier` as a fallback.
- **`@ModelActor` main-thread anomaly** (`research.md` Q2): repositories may execute
  on the main thread when awaited from `@MainActor` view models. Functionally correct
  but can hide the concurrency benefit; use `Task.detached` for heavy work
  (export/import, seed load) and verify with tests.
- **DTO mapping overhead**: dual-model means every entity has an `@Model` + a Codable
  struct + mapping both ways; mechanical but must stay in sync — keep mapping in one
  file per entity.
- **64-notification cap vs recurring sessions** (`research.md` Q3): many recurring
  sessions could exceed the budget; nearest-N + reschedule-on-launch is the guard.
- **Toolchain wrinkle**: `xcode-select` still on CLT — every build needs the
  `DEVELOPER_DIR` prefix until the user runs the one-time `sudo xcode-select -s`.
- **Single-runtime testing**: iOS 26-only means no cross-version simulator coverage;
  acceptable given the single-user, latest-device assumption.
