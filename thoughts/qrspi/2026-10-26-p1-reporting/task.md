# Task: P1 reporting and progress features

Address the six open P1 backlog rows that all live in the per-client reporting area
(`BACKLOG.md` rows 1–4, 9, 10; GitHub issues #3, #4, #5, #6, #11, #12): session volume
per session and per week, training consistency (completed vs scheduled, with cancelled
and no-show sessions counted), a client-level summary of top exercises, a per-exercise
history list showing dates, weights and reps, a total-reps progression chart alongside
the existing Epley 1RM chart, and PNG image export of the report in addition to PDF.

These are grouped because they share one data path (`ReportingQueries` over completed
`SetRecord`s), one screen (`ClientReportView`) and one exporter (`ReportExporter`), so
they can be designed and shipped as a single change. The PRD §8 "data honesty" rules
apply throughout: progression uses only completed sessions, consistency counts
cancelled and no-show, and sparse data shows "not enough data yet". The remaining P1
rows (series calendar updates, week view, inline exercise creation, archived-client
browsing) are separate areas and are not part of this task.
