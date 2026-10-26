# Structure Outline

## Approach

Lay the theme and preview scaffolding first, then re-skin one tab end to end so every
later phase has a working pattern to copy. Each phase ships a usable app, passes the
existing 109 unit tests, and ends with light/dark/AX3 simulator screenshots.

Test command (all phases): `xcodegen generate && xcodebuild -scheme TrainMe
-destination 'platform=iOS Simulator,name=iPhone 17' test`. Screenshot command:
`xcrun simctl io booted screenshot <name>.png` after toggling appearance with
`xcrun simctl ui booted appearance dark|light` and content size with
`xcrun simctl ui booted content_size extra-extra-extra-large`.

---

## Phase 1: Theme foundation + Schedule tab re-skin

Introduce semantic tokens, preview fixtures, and the status chip, and apply them to the
Schedule tab and tab bar so the new look is visible on launch.

**Files**: `Sources/Support/Theme.swift` (new), `Sources/Assets.xcassets/*.colorset`
(new: BrandPrimary, BrandSecondary, Success, Warning, Danger, PersonalBest, SurfaceRaised;
AccentColor gains a dark appearance), `Sources/Features/Components/StatusChip.swift`
(new), `Sources/Support/PreviewFixtures.swift` (new), `Sources/RootView.swift`,
`Sources/Features/Schedule/ScheduleView.swift`, `README.md`.

**Key changes**:
- `enum Theme { enum Colors { static let brandPrimary, brandSecondary, accent, success,
  warning, danger, personalBest, surfaceRaised: Color } ; enum Fonts { static func
  display(_:) -> Font; static let numeric: Font } ; enum Spacing { xs, sm, md, lg } }`
- `struct StatusChip: View { init(status: SessionStatus) }` — replaces inline
  green/orange/secondary icons at `ScheduleView.swift:119-128`.
- `enum PreviewFixtures { @MainActor static func container() -> ModelContainer;
  static let client, workout, scheduledSession: …DTO }` — in-memory store seeded with
  one client, one workout, one session with two logged sets.
- `RootView`: `Tab("Schedule", systemImage: "calendar.fill")` etc. (filled symbols),
  `.tabBarMinimizeBehavior(.onScrollDown)`.
- `ScheduleView`: export banner uses `Theme.Colors.warning`; `#Preview` added for
  `ScheduleView` and `SessionRow`.
- `README.md`: one line under the Sources layout describing `Theme.swift` and
  `Components/`.

**Verify**: tests pass; `#Preview` canvases render; screenshots of Schedule in light,
dark, AX3 show chips and amber accent only on the Add button.

---

## Phase 2: Shared components sweep (Clients, Workouts, Exercises, Settings, Lock)

Replace the duplicated row, error, icon-button, empty-state, and hero-screen code with
shared views; add loading placeholders, accessibility labels, and prominent toolbar
actions across the four remaining tabs.

**Files**: `Sources/Features/Components/{TitleCaptionRow,ErrorBanner,IconButton,
EmptyState,HeroScreen,ShareReportMenu}.swift` (new), `ClientListView.swift`,
`ClientDetailView.swift`, `ClientEditView.swift`, `WorkoutListView.swift`,
`WorkoutBuilderView.swift`, `ExerciseListView.swift`, `ExerciseEditView.swift`,
`SessionEditView.swift`, `SettingsView.swift`, `LockGateView.swift`, `TrainMeApp.swift`,
`ClientReportView.swift`, `ExerciseReportView.swift`.

**Key changes**:
- `struct TitleCaptionRow: View { init(title: String, caption: String?, trailing:
  (() -> some View)? = nil) }` — replaces the 10 inline sites (research Q2 §d.1).
- `struct ErrorBanner: View { init(message: String?) }` — replaces the 12 `.red` sites.
- `struct IconButton: View { init(_ title: LocalizedStringKey, systemImage: String,
  role: ButtonRole? = nil, action: () -> Void) }` — always sets `accessibilityLabel`.
- `struct EmptyState: View { init(_ title: String, systemImage: String, description:
  String? = nil, action: (title: String, run: () -> Void)? = nil) }`.
- `struct HeroScreen: View { init(systemImage: String, title: String, message: String?,
  primary: (String, () -> Void)) }` — lock + recovery; uses `@ScaledMetric` for icon.
- `struct ShareReportMenu: View { init(files: ReportFiles?) }`.
- Each list view: `.overlay { if viewModel.isLoading { ProgressView() } }`; view
  models gain `var isLoading = false` toggled around `load()`.
- Sheet toolbars: `Button("Save") {…}.buttonStyle(.borderedProminent)` via
  `ToolbarItem(placement: .confirmationAction)`; `ExerciseListView` adopts
  `Tab(role: .search)` wiring from `RootView`.
- Font: row titles use `Theme.Fonts.display(.headline)`; fixed 44pt sizes removed.

**Verify**: tests pass; grep shows zero `.foregroundStyle(.red)`, zero
`.font(.system(size:` outside `Theme.swift`; VoiceOver rotor in simulator Accessibility
Inspector lists a label for every button; screenshots of all four tabs light/dark/AX3.

---

## Phase 3: Inline set table in SessionRunView

Replace the `SetEntryView` sheet with an inline per-set table driven by exercise metrics,
with previous-set copy, steppers, keyboard entry, haptic on log, a session progress bar,
and a confirmation on "Mark Completed".

**Files**: `Sources/Features/Components/MetricStepper.swift` (new),
`Sources/Features/Session/SetTableView.swift` (new), `SessionRunView.swift`,
`SessionRunViewModel.swift`, `WorkoutBuilderView.swift` (`EntryTargetEditView` adopts
`MetricStepper`), `Tests/SessionRunViewModelTests.swift`.

**Key changes**:
- `struct MetricStepper: View { init(value: Binding<Double>, step: Double, range:
  ClosedRange<Double>, format: FloatingPointFormatStyle<Double>, label: String) }` —
  44pt+ targets, `.keyboardType(.decimalPad)` text in the middle, `accessibilityValue`.
- `struct SetTableView: View { init(entry: PlannedEntryDTO, exercise: ExerciseDTO?,
  logged: [SetRecordDTO], previous: SetRecordDTO?, onLog: (SetDraft) -> Void,
  onDelete: (SetRecordDTO) -> Void) }` — header row + one `SetRow` per
  `max(targetSets ?? 1, logged.count + 1)`; columns derived from `exercise.metrics`;
  stacked layout when `dynamicTypeSize >= .accessibility1`.
- `struct SetDraft: Equatable { var weight: Double?; var reps: Int?; var duration: Int?;
  var distance: Double? ; init(from: SetRecordDTO) ; init(target: PlannedEntryDTO) }`
- `SessionRunViewModel`: `var previousSets: [UUID: SetRecordDTO]` loaded once in
  `load()`; `var progress: Double { logged / planned }`; `var lastLoggedSetId: UUID?`
  as the `.sensoryFeedback(.success, trigger:)` source; `func record(draft: SetDraft,
  instanceId:, exerciseId:)`.
- `SessionRunView`: `ProgressView(value: viewModel.progress)` under the title; "Mark
  Completed" moves behind `pendingStatus = .completed` alert; `SetEntryView` deleted.
- Tests: `previousSetsLoadedPerExercise`, `progressReflectsLoggedOverPlanned`,
  `recordDraftOmitsMetricsNotInExercise`.

**Verify**: tests pass including three new ones; logging a prefilled set is one tap;
screenshots in light/dark/AX3 show the table and the stacked AX layout.

---

## Phase 4: Self-use client

Let a solo user add themselves as a client without a phone number and reach their own
sessions quickly.

**Files**: `Sources/Persistence/SchemaV2.swift` (new), `SchemaV1.swift` (migration plan
adds V2 + lightweight stage), `Sources/Models/Client.swift`, `ClientRepository.swift`,
`ClientEditViewModel.swift`, `ClientEditView.swift`, `ClientListView.swift`,
`RootView.swift`, `SessionEditView.swift`, `Tests/SchemaTests.swift`,
`Tests/ClientRepositoryTests.swift`.

**Key changes**:
- `Client.isSelf: Bool = false`; `SchemaV2.versionIdentifier = (2,0,0)`;
  `TrainMeMigrationPlan.stages = [.lightweight(fromVersion: SchemaV1.self, toVersion:
  SchemaV2.self)]`.
- `ClientRepository.selfClient() async throws -> ClientDTO?` and `createSelf(name:)`.
  `ClientDTO` unchanged (flag not exported; see risk).
- `ClientEditViewModel.canSave`: phone validation skipped when `isSelf`.
- `ClientListView` empty state gains action "Add yourself"; `RootView` first-run alert
  gains a second button "Add yourself as a client".
- `SessionEditView`: client picker defaults to the self client when it is the only
  client.
- Tests: `migratesV1StoreToV2`, `selfClientSkipsPhoneValidation`,
  `exportOmitsIsSelfAndRoundTrips`.

**Verify**: tests pass; a V1 store from `Tests/Fixtures` opens under V2; export JSON
diff against `export-v1.json` shows no new keys.

---

## Phase 5: Icon refinement with explicit variants

Bolden the mark, align the palette with Phase 1 tokens, and add dark and mono layers.

**Files**: `Sources/AppIcon.icon/icon.json`, `Sources/AppIcon.icon/Assets/{background,
dumbbell,line}.svg`, new `Assets/{background-dark,line-mono,dumbbell-mono}.svg`,
`Sources/Assets.xcassets/AccentColor.colorset/Contents.json`.

**Key changes**:
- `line.svg`: stroke-width 56 → 104, end-cap radius 44 → 72; `dumbbell.svg` plates
  widened 10%.
- `icon.json`: each layer's `image-name-specializations` gains `{appearance: "dark",
  value: …}` and `{appearance: "mono", value: …}` entries copied from an Icon Composer
  export; background fill uses the token gradient.
- AccentColor: second entry `appearances: [{appearance: luminosity, value: dark}]`.

**Verify**: `xcrun actool` compile succeeds; home-screen screenshots in default, dark,
tinted, clear; if specialization keys are rejected twice, keep single appearance and
record it in BACKLOG.

---

## Phase 6: Reports theming and final accessibility sweep

Theme the charts, pin PDF pages to light, add chart accessibility, and run the
whole-app AX3 pass.

**Files**: `ClientReportView.swift`, `ExerciseReportView.swift`, `ReportExporter.swift`,
`BACKLOG.md`.

**Key changes**:
- `ExerciseProgressChart`/`VolumeChart`: `.chartForegroundStyleScale([ "lb":
  Theme.Colors.brandPrimary, "kg": Theme.Colors.brandSecondary ])`, PB point uses
  `personalBest`, `.accessibilityLabel(summary)` built from the series.
- `ExerciseReportPage`/`ClientOverviewPage`: `.environment(\.colorScheme, .light)`.
- `BACKLOG.md`: Done rows for this effort; new row "Snapshot tests for themed screens".

**Verify**: tests pass; `ReportExporterTests` PNG renders light on a dark simulator;
AX3 screenshots of every screen show no clipped text.

---

## Testing Checkpoints

| After | True statements |
|---|---|
| Phase 1 | `Theme.swift` exists; Schedule tab and tab bar themed; previews compile; 109 tests green |
| Phase 2 | No inline `.red`, no fixed font sizes, every tab uses shared components; loading indicators present |
| Phase 3 | `SetEntryView` gone; set table logs in one tap; 112 tests green |
| Phase 4 | SchemaV2 live; self client works without phone; export format unchanged; 115 tests green |
| Phase 5 | Icon shows explicit dark/mono variants on the simulator home screen |
| Phase 6 | Charts use tokens; PDFs always light; AX3 pass complete; BACKLOG updated |

Phases 4 and 5 are independent of 2 and 3 and may be reordered if a phase blocks.
