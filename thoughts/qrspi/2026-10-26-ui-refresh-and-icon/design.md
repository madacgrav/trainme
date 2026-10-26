# Design Discussion

Owner answers (2026-10-26): audience = trainer first, self-use OK; theme = energetic
dark-first with light support; icon = refine dumbbell concept and add explicit variants;
set entry = inline set table; verification = `#Preview` fixtures + simulator screenshots.

Paths: `S/` = `Sources/`, `F/` = `Sources/Features/`. Line refs are from `research.md`.

## Current State

TrainMe is a feature-complete, local-only trainer app whose visual layer is entirely
system-default and un-themed.

- **No identity layer.** No theme, token, `Color+`, `Font+`, `ViewModifier`, or
  `ButtonStyle` file exists; every color and font is inline (research Q2). The only
  brand colors are the icon SVGs (`#0F766E`→`#3730A3`, `#F59E0B`, white) and the amber
  `AccentColor` with no dark variant (`S/Assets.xcassets/AccentColor.colorset/Contents.json:5-13`).
- **Orange means three things**: warnings (`F/Session/SessionRunView.swift:25`,
  `F/Schedule/ScheduleView.swift:16,34`), no-show status (`ScheduleView.swift:127`), and
  personal bests (`F/Reports/ClientReportView.swift:148,152`).
- **Duplicated shapes.** Title + caption row ×10, red error `Section` ×12, icon-only
  plain buttons ×4, share menu ×2, Cancel/Save toolbar ×5, two different stepper
  implementations (`SessionRunView.swift:277-311` vs `F/Workouts/WorkoutBuilderView.swift:184-210`).
- **Navigation.** Five tabs with outline symbols (`S/RootView.swift:28-62`): Schedule,
  Clients, Workouts, Exercises, Settings. No search tab role, no
  `tabBarMinimizeBehavior`, no iOS 26 toolbar APIs. Three taps from launch to logging a
  set on today's session; no `ProgressView` anywhere (Q3).
- **Set entry** is a `.medium` sheet (`SessionRunView.swift:257-354`) with default-size
  `.bordered` ± buttons, keyboard entry only for distance, no previous-set hint, no
  completion checkmark, no haptics. Logged sets render as `.caption` text lines with no
  comparison to target (`:199-213`). "Mark Completed" has no confirmation (`:62-64`).
- **Accessibility**: zero accessibility modifiers, `@ScaledMetric`, color-scheme code,
  or `.sensoryFeedback` (Q5). Fixed 44pt icons at `S/TrainMeApp.swift:93`,
  `F/Lock/LockGateView.swift:36`.
- **Icon**: `S/AppIcon.icon/icon.json` defines one appearance (`fill: system-light`, no
  specializations); the rising line is a 56px stroke, which the HIG flags as "thin
  lines" to avoid (Q1, Q6). The prior design targeted explicit default/dark/mono
  (`thoughts/qrspi/2026-10-26-review-gaps-and-app-icon/design.md:41-45`).
- **Verification**: no `#Preview`, no UI/snapshot tests; CI is unit tests only (Q7).

## Desired End State

A themed, workout-feeling app that still does exactly what it does today.

1. **One theme file** (`S/Support/Theme.swift` + `Assets.xcassets` colorsets) defines
   semantic roles: `brandPrimary` (teal), `brandSecondary` (indigo), `accent` (amber,
   actions only), `success`, `warning`, `danger`, `personalBest`, plus surface levels.
   Every colorset has light and dark values. Dark is the showcase appearance; light is
   fully supported.
2. **Shared components** in `S/Features/Components/`: `TitleCaptionRow`, `ErrorBanner`,
   `StatusChip`, `MetricStepper`, `IconButton`, `EmptyState` wrapper, `ShareReportMenu`,
   `HeroScreen` (lock/recovery). Each existing duplicate site uses the shared view.
3. **Navigation**: same five tabs; filled SF Symbols; Exercises tab becomes
   `Tab(role: .search)` behavior preserved via `.searchable`; `tabBarMinimizeBehavior(.onScrollDown)`
   on list-heavy tabs; `.prominent` Save/Log toolbar buttons; `ProgressView` or redacted
   placeholders while `.task` loads.
4. **Inline set table** in `SessionRunView`: each exercise shows a header row
   (Set / Previous / Weight / Reps or metric-driven columns) and one row per planned set
   with numeric `TextField`s, large `MetricStepper`s, a tap-to-copy "previous" cell, and a
   trailing check that records the set with `.sensoryFeedback(.success)`. Logged rows
   turn `success`-tinted; a session progress bar sits under the title. Completed-state
   confirmation added.
5. **Self-use path**: Clients list empty state and first-run notice offer "Add yourself
   as a client" which pre-fills name from device owner and skips phone validation when
   `isSelf` is set. No data-model change beyond an optional flag.
6. **Icon**: same concept, bolder geometry (stroke ≥ 96px, larger end cap), explicit
   `dark` and `mono` image specializations in `icon.json`, background gradient aligned to
   `brandPrimary`→`brandSecondary`; AccentColor gains a dark appearance entry.
7. **Accessibility**: every icon-only button has `accessibilityLabel`; set-table cells
   have `accessibilityValue`; `@ScaledMetric` replaces fixed 44pt; all text uses
   Dynamic Type styles; charts get `accessibilityLabel` summaries.
8. **Verification**: every screen has a `#Preview` backed by `PreviewFixtures` (in-memory
   `ModelContainer` with one client, one workout, one session with sets). Implementation
   phases end with simulator screenshots in light, dark, and AX3 text size.

Correctness check: all 57+ existing unit tests pass; `xcodegen generate` and the CI
command succeed; every screen renders in both color schemes at AX3 without clipping;
the icon compiles with `actool` and shows distinct default/dark/tinted/clear on the
simulator home screen.

## Patterns to Follow

- **View/ViewModel split** with `@MainActor @Observable` view models and repository
  protocols (`SessionRunViewModel.swift`, `F/Clients/ClientDetailViewModel.swift`).
  New UI must not call SwiftData directly.
- **Error surfacing** stays `errorMessage` on the view model, rendered by the new
  `ErrorBanner` (replacing `SessionRunView.swift:17-21` and the other 11 sites).
- **Destructive confirmation** pattern of `SessionRunView.swift:146-157` (alert with
  explicit "Keep") extends to "Mark Completed".
- **Empty states** keep `ContentUnavailableView` as `List.overlay`
  (`ScheduleView.swift:57-61`, `ClientListView.swift:30-37`); the `EmptyState` wrapper
  only standardizes copy and symbol.
- **Metric gating** stays driven by `exercise.metrics` (`SessionRunView.swift:269`,
  `S/Models/Exercise.swift:13-21`); the set table derives its columns from it.
- **Previous-set lookup** reuses `SessionRepository.lastSet`
  (`S/Persistence/SessionRepository.swift:273-286`), fetched once per exercise on load
  instead of per tap.
- **Report pages** (`S/Services/ReportExporter.swift:68-136`) keep `.background(.white)`
  and explicit `.environment(\.colorScheme, .light)` so PDFs never inherit dark theme.
- **Do NOT follow**: inline `.orange` for unrelated meanings; hand-rolled ± `HStack`s;
  fixed `.font(.system(size:))`; `.foregroundStyle(.primary)` hacks on Button rows
  (`ExerciseListView.swift:17` etc.) — use `.buttonStyle(.plain)` on a `TitleCaptionRow`.
- **Do NOT** apply Liquid Glass or `.glassEffect` to content rows (HIG: glass is for the
  navigation layer only).

## Design Decisions

1. **Theme as semantic tokens, not a design-system package**: `Theme.swift` with static
   `Color`/`Font` accessors over asset colorsets — matches the single-module layout and
   keeps XcodeGen untouched; no SPM dependency.
2. **Dark-first palette**: surfaces near-black with teal-tinted elevation; amber reserved
   for the one primary action per screen (HIG: tint only primary actions); teal for
   charts and brand; indigo for secondary data series; green for completed, red for
   danger, amber-on-dark for warnings replaces today's orange overload; `personalBest`
   gets its own gold token.
3. **Inline set table over sheet**: closest to market expectation (Hevy/Strong), cuts the
   3-tap log to 1 tap for prefilled sets, and keeps one-handed use. `SetEntryView` is
   removed; `EntryTargetEditView` in the builder adopts the same `MetricStepper`.
4. **Keep five tabs, same order**: PRD's core loop starts at Schedule; research found no
   evidence a reorder helps a trainer. Search gets a dedicated role on Exercises only.
5. **Self-use via a flagged client, not a new mode**: keeps every repository, report, and
   export path unchanged; the only schema touch is an optional `isSelf: Bool` on
   `Client` with a lightweight migration in `SchemaV1` successor.
6. **Icon refinement in place**: edit the three SVGs and `icon.json` as text (README:64
   convention); add `dark` and `mono` specializations; keep `actool` + simulator as the
   gate, appiconset fallback stays available.
7. **Previews over snapshot tests**: no new dependency or CI image baseline; screenshots
   are captured per phase and attached to the PR. Snapshot tests remain a backlog item.
8. **Haptics**: `.sensoryFeedback(.success, trigger:)` on set logged and session
   completed only; no haptics on steppers.

## What We're NOT Doing

- No new features: no rest timer, Live Activity, RPE entry, supersets, social feed,
  paywall, or multi-user accounts.
- No tab reorder, no Home/Today dashboard tab.
- No change to the export schema, repositories, notifications, calendar, or lock flow.
- No custom fonts; SF Pro with `.rounded` design where the theme calls for it.
- No alternate icons, no watchOS icon work.
- No snapshot-testing library or UI-test target this round.
- No iPad-specific layout work.
- No rewrite of `ReportExporter` PDF layout beyond color-scheme pinning.

## Open Risks

- **`icon.json` specialization keys are undocumented**: mitigation is to export a
  reference from Icon Composer.app with dark/mono layers and copy its key names before
  hand-editing; fall back to system-generated variants if `actool` rejects them.
- **Inline numeric `TextField`s inside `List` rows** can fight scroll and focus on iOS
  26; mitigation is `@FocusState` per cell and `.scrollDismissesKeyboard(.interactively)`.
  If unstable, `MetricStepper` alone must still allow full entry.
- **Dark-first legibility of charts**: Swift Charts default series colors are tuned for
  light; `chartForegroundStyleScale` must be set explicitly from theme tokens.
- **`Client.isSelf` migration**: adding a defaulted optional to a `@Model` is lightweight
  but needs a `SchemaV2` and migration-plan entry; `SchemaTests` and
  `ArchiveRoundTripTests` guard the export format, which must not change.
- **Dynamic Type at AX sizes in the set table**: four columns may not fit; the table
  must wrap to a stacked layout above `.accessibility1`.
- **Tab bar minimize + graphical `DatePicker`** on Schedule may feel jumpy; apply
  minimize only to Clients/Workouts/Exercises if so.
