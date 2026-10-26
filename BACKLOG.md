# TrainMe Backlog

Everything the 2026-10-26 review found that is **not** fixed in the same change.
Priorities follow the PRD (P1 strongly desired, P2 nice-to-have). Each row links the
PRD section, the evidence from the review, and its GitHub issue.

Source: `thoughts/qrspi/2026-10-26-review-gaps-and-app-icon/research.md`. P0 items from
that review (export reminder, injuries at session time, units, session edit/delete,
confirmations, failed-save surfacing, notification correctness) shipped in the same PR.

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

## Tech debt

| # | Item | Why | Evidence | Issue |
|---|------|-----|----------|-------|
| 20 | `VersionedSchema` + `SchemaMigrationPlan` | Original plan said "from first release" | `PersistenceController` builds a plain `Schema` | [#22](https://github.com/madacgrav/trainme/issues/22) |
| 21 | Pre-import automatic backup and import rollback on partial failure | Replace-import deletes before upsert in one context | `DataArchive.importData` | [#23](https://github.com/madacgrav/trainme/issues/23) |
| 22 | Surface remaining background `try?` paths | Seed import and calendar push fail silently | `RootView.task`, `SessionEditView.save` | [#24](https://github.com/madacgrav/trainme/issues/24) |
| 23 | Check notification authorization before `add`; re-prompt path when denied | `add` errors are swallowed | `LocalNotificationService.reschedule` | [#25](https://github.com/madacgrav/trainme/issues/25) |
| 24 | Handle `defaultCalendarForNewEvents == nil` | Assignment is unchecked | `EventKitCalendarService.push` | [#26](https://github.com/madacgrav/trainme/issues/26) |
| 25 | Privacy manifest, entitlements file, CI workflow | None exist | `.github/` has only CODEOWNERS | [#27](https://github.com/madacgrav/trainme/issues/27) |

## Test gaps

| # | Item | Evidence | Issue |
|---|------|----------|-------|
| 26 | AppLock, EventKit write path, notification delivery, ReportExporter, view models, UI tests | No tests reference these types | [#28](https://github.com/madacgrav/trainme/issues/28) |
| 27 | Replace-import into a non-empty store; `importArchive(url:)` failure paths | `ArchiveRoundTripTests` imports into a fresh store only | [#29](https://github.com/madacgrav/trainme/issues/29) |
