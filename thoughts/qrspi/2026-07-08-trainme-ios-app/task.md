# Task: Build TrainMe (v1)

Build **TrainMe**, a native iOS (Swift/SwiftUI) app for a single independent personal
trainer to manage clients, author reusable workouts, schedule and record training
sessions, and track each client's progress over time. All data is stored **locally on
the device** with no backend and no client-facing app.

The architecture must stay "personal now, sellable later": data access behind a
repository/persistence protocol, every entity with a stable UUID plus
`createdAt`/`updatedAt`, and a versioned JSON export schema — so a cloud-sync backend
and multi-trainer support can be added in v2 without a rewrite.

Full scope, entities, feature priorities (P0/P1/P2), and platform constraints are
defined in `PRD.md` at the repository root. The PRD's open decisions (§12) have been
resolved by the owner — see `decisions.md` in this directory: simple template
versioning (sessions keep their copy), expanded client fields adopted, recurring
sessions in scope, double-booking detection out, iOS system calendar sync (EventKit)
in scope plus Gmail as a share/export target. This is a greenfield repository — no
source code exists yet.
