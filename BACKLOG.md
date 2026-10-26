# TrainMe Backlog

Everything the 2026-10-26 review found that is **not** fixed in the same change.
Priorities follow the PRD (P1 strongly desired, P2 nice-to-have). Each row links the
PRD section, the evidence from the review, and its GitHub issue.

Source: `thoughts/qrspi/2026-10-26-review-gaps-and-app-icon/research.md`. P0 items from
that review (export reminder, injuries at session time, units, session edit/delete,
confirmations, failed-save surfacing, notification correctness) shipped in the same PR.

Tech debt and test gaps from that review (rows 20–27) were addressed in
[#32](https://github.com/madacgrav/trainme/pull/32); see the [Done](#done) table and
`thoughts/qrspi/2026-10-26-tech-debt/` for the design and plan.

## P1 — features

| # | Item | Why / PRD ref | Evidence | Issue |
|---|------|---------------|----------|-------|
| 1 | Session volume per session / week | PRD §8 P1 | No volume computation in `Sources/` | [#3](https://github.com/madacgrav/trainme/issues/3) |
| 2 | Training consistency (completed vs scheduled; cancelled/no-show counted) | PRD §8 P1 | No consistency computation in `Sources/` | [#4](https://github.com/madacgrav/trainme/issues/4) |
| 3 | Client-level summary of top exercises | PRD §8 P1 | No summary view | [#5](https://github.com/madacgrav/trainme/issues/5) |
| 4 | Per-exercise history list (dates, weights, reps) | PRD §5.6 | `ReportingQueries.history` feeds charts only; no list UI | [#6](https://github.com/madacgrav/trainme/issues/6) |
| 5 | Series edit/cancel and shared calendar event update/removal | decisions #3/#4 | `SessionRunViewModel.setStatus` and `delete` skip calendar work for series | [#7](https://github.com/madacgrav/trainme/issues/7) |
| 6 | Week view on Schedule | PRD §5.4 | `ScheduleView` is a month picker plus one-day list | [#8](https://github.com/madacgrav/trainme/issues/8) |
| 7 | Inline "create exercise" from the workout picker | PRD §4.3 | `ExercisePickerView` has no create action | [#9](https://github.com/madacgrav/trainme/issues/9) |
| 8 | Browse and unarchive archived clients | PRD §5.1 | No list uses `allIncludingArchived`; unarchive only from an open detail screen | [#10](https://github.com/madacgrav/trainme/issues/10) |
| 9 | Report as PNG image | PRD §5.9 "PDF/image" | `ReportExporter` is PDF-only | [#11](https://github.com/madacgrav/trainme/issues/11) |
| 10 | Total-reps progression chart | PRD §8 P0 alternative | Only the Epley 1RM chart exists | [#12](https://github.com/madacgrav/trainme/issues/12) |

## P2 — features

| # | Item | Why / PRD ref | Evidence | Issue |
|---|------|---------------|----------|-------|
| 11 | CSV export of session history | PRD §9 | No CSV code | [#13](https://github.com/madacgrav/trainme/issues/13) |
| 12 | Daily / every-N-weeks recurrence in the UI | PRD §5.4 | `AppRecurrence` supports it; `SessionEditView` is weekly, interval 1 | [#14](https://github.com/madacgrav/trainme/issues/14) |
| 13 | RPE input when logging a set | PRD §4.1 | `SetRecord.rpe` is always nil | [#15](https://github.com/madacgrav/trainme/issues/15) |
| 14 | Delete client / delete exercise | PRD §5.1 / §5.2 | Repository methods exist with no UI caller | [#16](https://github.com/madacgrav/trainme/issues/16) |
| 15 | Settings toggles: app lock on/off, calendar default, notification lead times | PRD §5.7 / §5.11 | Settings has Units and Backup only | [#17](https://github.com/madacgrav/trainme/issues/17) |
| 16 | Reorder workout entries via edit mode | PRD §5.3 P1 | `.onMove` is wired but no `EditButton` exists | [#18](https://github.com/madacgrav/trainme/issues/18) |
| 17 | Session notes on Schedule and client-detail rows | PRD §5.5 | Notes visible only inside the run screen | [#19](https://github.com/madacgrav/trainme/issues/19) |

## Deferred by owner decision

| # | Item | Decision | Issue |
|---|------|----------|-------|
| 18 | Double-booking detection / warning | decisions.md #3: out of scope | [#20](https://github.com/madacgrav/trainme/issues/20) |
| 19 | Direct Google Calendar API integration | decisions.md #4: default calendar + share sheet only | [#21](https://github.com/madacgrav/trainme/issues/21) |

## Done

Addressed in [#32](https://github.com/madacgrav/trainme/pull/32) (one commit per phase).

| # | Item | Resolution | Issue |
|---|------|------------|-------|
| 20 | `VersionedSchema` + `SchemaMigrationPlan` | `SchemaV1` + `TrainMeMigrationPlan`; `StoreBackup` keyed on schema version with a one-time legacy backup | [#22](https://github.com/madacgrav/trainme/issues/22) |
| 21 | Pre-import automatic backup and import rollback on partial failure | `SafeImporter` snapshots before replace-import, `importData` rolls back on throw, snapshot restored on failure; distinct Settings messages | [#23](https://github.com/madacgrav/trainme/issues/23) |
| 22 | Surface remaining background `try?` paths | `os.Logger` per subsystem; seed-import alert; `SessionRunViewModel` error state; calendar warnings after save; export/import picker failures reported | [#24](https://github.com/madacgrav/trainme/issues/24) |
| 23 | Check notification authorization before `add`; re-prompt path when denied | `reschedule` gates on `canScheduleAlerts`; Settings → Permissions shows status with Open Settings link | [#25](https://github.com/madacgrav/trainme/issues/25) |
| 24 | Handle `defaultCalendarForNewEvents == nil` | Falls back to first writable calendar, else `CalendarError.noWritableCalendar` surfaced as a warning | [#26](https://github.com/madacgrav/trainme/issues/26) |
| 25 | Privacy manifest, entitlements file, CI workflow | `Sources/PrivacyInfo.xcprivacy`, `Sources/TrainMe.entitlements`, `.github/workflows/ci.yml` | [#27](https://github.com/madacgrav/trainme/issues/27) |
| 26 | AppLock, EventKit write path, notification delivery, ReportExporter, view models, UI tests | Partial: `SessionRunViewModel` failure paths, notification gate, calendar outcome resolution, coordinator status tested via fakes. Still open: AppLock, ReportExporter, real EventKit/UNUserNotificationCenter, UI tests | [#28](https://github.com/madacgrav/trainme/issues/28) |
| 27 | Replace-import into a non-empty store; `importArchive(url:)` failure paths | `Tests/SafeImporterTests.swift` covers both plus mid-import failure restore and malformed body | [#29](https://github.com/madacgrav/trainme/issues/29) |

Still worth a look (found while doing the above, not fixed): `ClientReportView` swallows a
failed PDF render; a failed `upcoming` fetch in `ReminderCoordinator.refresh` clears all
pending alerts instead of leaving them.
