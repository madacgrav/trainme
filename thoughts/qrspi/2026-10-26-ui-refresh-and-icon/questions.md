# Research Questions

## Context

This is a native iOS 26 / Swift 6 / SwiftUI app generated with XcodeGen from `project.yml`.
Views live under `Sources/Features/<Feature>/`, the root tab layout in `Sources/RootView.swift`
and `Sources/TrainMeApp.swift`, assets under `Sources/Assets.xcassets/` and
`Sources/AppIcon.icon/`, and product docs in `PRD.md`, `BACKLOG.md`, and
`thoughts/qrspi/`. Research should establish, factually, how the interface is currently
built, styled, navigated, and tested, and what the surrounding market of similar apps looks like.

## Questions

1. What does the current app icon consist of (`Sources/AppIcon.icon/icon.json` and its
   `Assets/*.svg` layers, plus `Sources/Assets.xcassets/AccentColor.colorset/`), how is it
   wired into the build via `project.yml`, and what did
   `thoughts/qrspi/2026-10-26-review-gaps-and-app-icon/design.md` and `plan.md` decide
   about its concept and format? What does Icon Composer / iOS 26 support for layered,
   tinted, dark, and clear icon variants, and which of those does the current icon define?

2. How are colors, fonts, spacing, and reusable visual elements applied across
   `Sources/Features/` today? Catalog every use of explicit colors (`.orange`, `.tint`,
   `.accentColor`, hex values), fixed font sizes, and semantic text styles, and identify
   which views define their own row, card, stepper, or chart subviews (e.g. `SessionRow`,
   `SetEntryView`, `OptionalStepper`, `ExerciseProgressChart`, `PermissionRow`) and where
   those are reused versus duplicated.

3. Trace the navigation structure end to end: what tabs does `Sources/RootView.swift`
   declare, in what order and with which SF Symbols and labels; which screens are reached
   by push versus sheet from each tab; how many taps does it take to go from app launch to
   recording a set in `SessionRunView`; and which screens have empty states, loading
   states, confirmation dialogs, or error presentation and which do not?

4. How is the in-session recording screen (`Sources/Features/Session/SessionRunView.swift`
   and its view model) laid out and operated: what controls exist for entering weight,
   reps, duration, and distance, how "repeat last set" and steppers work, what tap-target
   sizes and layout the code implies, and how the planned-versus-actual comparison and
   session status changes are shown?

5. What accessibility and appearance support exists: are there any `accessibilityLabel`,
   `accessibilityHint`, `@ScaledMetric`, `dynamicTypeSize`, `preferredColorScheme`, or
   `UIUserInterfaceStyle` usages; how do the charts in `Sources/Features/Reports/` and the
   PDF pages in `Sources/Services/ReportExporter.swift` handle color and text scaling; and
   what does `Sources/Info.plist` declare for launch screen, display name, and orientation?

6. What UI conventions, visual identity, navigation patterns, onboarding flows, and app
   icons do the leading iOS personal-trainer and workout-logging apps use (e.g. Trainerize,
   TrueCoach, Hevy, Strong, Apple Fitness, Nike Training Club)? Specifically: tab
   structure, how set entry is laid out, how color and typography convey a fitness theme,
   how they handle dark mode, and what Apple's Human Interface Guidelines say about iOS 26
   app icons, Liquid Glass, and tab bar design.

7. How is the UI currently verified: what does `Tests/` cover for view models
   (`SessionRunViewModelTests`, `ClientDetailViewModelTests`, `ReportExporterTests`), is
   there any UI, snapshot, or preview-based testing, what does `.github/workflows/ci.yml`
   run, and do any views define `#Preview` blocks that could serve as visual fixtures?
