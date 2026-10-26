# Task

Address the tech debt rows in `BACKLOG.md` (rows 20–25, GitHub issues #22–#27) and the
related test gaps (rows 26–27, issues #28–#29). These are hardening items the 2026-10-26
review found but did not fix: no versioned SwiftData schema or migration plan, replace-import
with no pre-import backup or rollback, background `try?` paths that swallow failures (seed
import, calendar push), notification `add` without an authorization check or re-prompt path,
an unchecked `defaultCalendarForNewEvents`, and no privacy manifest, entitlements file, or CI
workflow. The goal is to make the app's persistence, import, calendar, and notification paths
fail loudly and recoverably, give the project the packaging and CI scaffolding it is missing,
and cover the fixed paths with tests.
