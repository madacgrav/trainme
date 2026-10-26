# Research Questions

## Context

This is a native iOS 26 / Swift 6 / SwiftUI app generated with XcodeGen from
`project.yml`. Source lives under `Sources/` (Models, Models/DTO, Persistence, Services,
Features, Support, Resources), tests under `Tests/`, and the product requirements and
an earlier design/structure/plan set live in `PRD.md` and
`thoughts/qrspi/2026-07-08-trainme-ios-app/`. Research should establish, factually,
what the app currently does across each feature area, how it is configured and
packaged, and how it is tested.

## Questions

1. Taking `PRD.md` §5 (feature requirements with P0/P1/P2 priorities) and
   `thoughts/qrspi/2026-07-08-trainme-ios-app/decisions.md` as the checklist, which
   requirements have a concrete implementation in `Sources/`, which are partial, and
   which have no code at all? For each, cite the file(s) that implement it.

2. What does `thoughts/qrspi/2026-07-08-trainme-ios-app/plan.md` list as phases,
   steps, and verification checkpoints, and which of those steps are reflected in the
   codebase and git history versus absent or marked deferred? Does `structure.md`
   describe any slices that never landed?

3. How is the app packaged and configured: what do `project.yml`, `Sources/Info.plist`,
   and the generated `TrainMe.xcodeproj` declare for bundle identity, signing,
   permissions usage strings, launch screen, asset catalogs, icons, accent color,
   supported orientations and devices, and build settings? What does XcodeGen require
   for a target to pick up an `.xcassets` catalog and an `AppIcon` set, and what
   icon formats/sizes does iOS 26 expect in an asset catalog (including the single
   1024px / Icon Composer `.icon` path)?

4. Trace the end-to-end navigation and screens in `Sources/RootView.swift` and
   `Sources/Features/`: what tabs/routes exist, what does each screen let the user do,
   which actions are reachable from where, and are there views, buttons, or flows that
   are stubbed, unreachable, or lead to no-ops (including onboarding, first-launch,
   empty states, and error presentation)?

5. How do the scheduling, recurrence, notification, and calendar paths work
   (`Sources/Features/Schedule/`, `Sources/Services/NotificationService.swift`,
   `Sources/Services/CalendarService.swift`, `Sources/Persistence/SessionRepository.swift`)?
   Specifically: how recurring sessions are expanded and edited, how the notification
   budget is handled, how EventKit events are created/updated/removed on session
   changes, and what happens on permission denial.

6. How do data safety features work: export/import (`Sources/Services/Archive/`),
   store backup/restore (`Sources/Persistence/StoreBackup.swift`), seed import,
   periodic export prompting, and app lock (`Sources/Services/AppLock.swift`,
   `Sources/Features/Lock/`)? What is the merge-vs-replace behavior on import, what
   triggers a backup, and where does the app communicate data-loss risk to the user?

7. What does the test suite in `Tests/` cover, by file and by subject, and which
   source files or behaviors (repositories, services, view models, UI flows) have no
   corresponding tests? How are tests run (scheme, destination, fixtures), and is the
   frozen `Tests/Fixtures/export-v1.json` fixture exercised?
