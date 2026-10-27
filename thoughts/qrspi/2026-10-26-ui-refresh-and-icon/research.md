# Research Findings

Paths are relative to the repo root; `S/` = `Sources/`, `F/` = `Sources/Features/`.
Market findings (Q6) are from web sources fetched 2026-10-26 and cite URLs.

## Q1: Current app icon, accent color, build wiring, and prior decisions

### Findings
- Icon is a hand-authored Icon Composer package: `S/AppIcon.icon/icon.json` plus three
  1024×1024 SVG layers under `S/AppIcon.icon/Assets/`. There is no `AppIcon.appiconset`.
- `icon.json:2` sets `"fill": "system-light"`. Two groups (`:3-83`):
  - Group 1 (glass, `:4-51`): layers "dumbbell" (`dumbbell.svg`, scale 0.78, translation
    [0, 20], `:7-23`) and "rising line" (`line.svg`, scale 0.82, translation [0, −60],
    `:24-40`); both `glass: true`; shadow `layer-color` opacity 0.5 (`:42-45`);
    `specular: true` (`:46`); translucency enabled 0.2 (`:47-50`).
  - Group 2 (background, `:52-82`): `background.svg`, `glass: false`, shadow opacity 0,
    no specular, no translucency.
- Platforms `:84-89`: `"circles": ["watchOS"]`, `"squares": "shared"`.
- **No appearance variants are defined.** No dark, tinted, clear, or mono specialization
  keys; each layer's `image-name-specializations` has one unqualified entry. Any
  dark/mono rendering is system-generated.
- SVG layers (all `viewBox="0 0 1024 1024"`):
  - `background.svg:3-8`: full-bleed rect, linear gradient top-left→bottom-right,
    `#0F766E` (teal) → `#3730A3` (indigo).
  - `dumbbell.svg:1-7`: `fill="#FFFFFF"`; five rounded rects symmetric about (512,512);
    bar 400×48, inner plates 96×240, outer plates 56×160; extent x 128–896, y 392–632.
  - `line.svg:2-4`: polyline 176,700 → 392,560 → 560,616 → 848,328, stroke `#F59E0B`
    width 56, round caps; terminal circle r=44 at (848,328).
- `S/Assets.xcassets/AccentColor.colorset/Contents.json:5-13`: single `universal` sRGB
  entry r 0.961 g 0.620 b 0.043 (amber `#F59E0B`), no `appearances` array, so no dark
  or high-contrast variant. The catalog holds nothing else.
- Build wiring: `project.yml:14` `sources: [Sources]` picks up both packages;
  `:22` `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`; `:23`
  `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor`; `:4` iOS 26.0 target.
  `S/Info.plist` has no icon keys; `CFBundleDisplayName` "TrainMe" (`:21-22`); portrait
  only (`:23-26`); `UILaunchScreen` empty dict (`:31-32`).
- Prior decisions, `thoughts/qrspi/2026-10-26-review-gaps-and-app-icon/design.md`:
  `:3-4` format = Icon Composer `.icon`, concept = dumbbell + rising line; `:41-45` end
  state "renders in default, dark, and mono appearances"; `:104-106` palette "deep
  teal→indigo gradient background, white dumbbell, warm amber rising stroke. Mono/tinted
  appearance uses the dumbbell+line silhouette only"; `:107-109` AccentColor "amber from
  the icon"; `:152` alternate icons explicitly out of scope; `:157-161` risks: undocumented
  `icon.json` schema, fallback behavior varies by Xcode 26.x.
- `plan.md:30-32` says `icon.json` was "copied from a shipped Icon Composer file";
  `:34-78` planned JSON had background group first with `shadow: null`, but the committed
  file has the glass group first and background shadow `layer-color` opacity 0.
  `:165-171` fallback appiconset was never needed. `:173-182` verification boxes ticked;
  `:1083` "Simulator: icon (light/dark), accent" final checklist item unticked.
- `README.md:64` is the only README mention. `BACKLOG.md` has no icon row.
- Commit `2a8caf0` "Phase 1: App icon, accent color, packaging keys" added these files.

## Q2: How colors, fonts, spacing, and reusable elements are applied

### Findings
- No theme, token, `Color+`, `Font+`, custom `ViewModifier`, `ButtonStyle`, or
  `LabelStyle` file exists. No `Color(...)`, `UIColor`, hex, `.listRowBackground`,
  `.listStyle`, `GroupBox`, `.cornerRadius`, `.clipShape`, `RoundedRectangle`,
  `.fontDesign`, `.rounded`, or `.monospaced` in any Swift file. Every color and font is
  inline at its use site.
- **Color uses** (all semantic/hierarchical):
  - `.red` ×12, all error text: `F/Session/SessionRunView.swift:19`,
    `F/Reports/ClientReportView.swift:12,15`, `F/Reports/ExerciseReportView.swift:12,15`,
    `F/Exercises/ExerciseEditView.swift:75`, `F/Schedule/SessionEditView.swift:129`,
    `F/Clients/ClientEditView.swift:23,35`, `F/Clients/ClientDetailView.swift:12`,
    `F/Workouts/WorkoutListView.swift:14`, `F/Workouts/WorkoutBuilderView.swift:48`.
  - `.orange` ×8: `S/TrainMeApp.swift:94` (recovery icon), `SessionRunView.swift:25`
    (injuries), `F/Schedule/ScheduleView.swift:16,34,127` (banner icon, banner bg at 0.12
    opacity, no-show badge), `ClientReportView.swift:43,148,152` (unresolved caption, PB
    point, PB label).
  - `.green` ×1: `ScheduleView.swift:123` completed badge.
  - `.accentColor`/`.gray`: `SessionEditView.swift:118` weekday toggles.
  - `.tint`: `SessionRunView.swift:197` "Log set" button.
  - `.secondary` ×~30 across captions and empty text; `.tertiary` ×4
    (`ReportExporter.swift:94,129`, `ScheduleView.swift:109`, `WorkoutBuilderView.swift:204`);
    `.primary` ×5 to override Button tint on row titles (`ExerciseListView.swift:17`,
    `WorkoutListView.swift:23`, `WorkoutBuilderView.swift:35,128`, `SessionEditView.swift:94`).
  - Backgrounds: `.white` on PDF pages (`S/Services/ReportExporter.swift:99,134`, the only
    fixed non-semantic color); `.regularMaterial` on lock screen
    (`F/Lock/LockGateView.swift:46`); `.quaternary` capsule on "Custom" tag
    (`ExerciseListView.swift:28`).
  - Charts: `LineMark` has no explicit color (`ClientReportView.swift:136`); `BarMark` uses
    `.foregroundStyle(by:)` with default series colors (`:192`).
- **Fonts**: fixed size only at `TrainMeApp.swift:93` and `LockGateView.swift:36`
  (`.system(size: 44)` icons). Semantic styles by count: `.caption` 18,
  `.caption.bold()` 5 (all ReportExporter), `.caption2` 3, `.caption2.bold()` 1,
  `.footnote` 2, `.subheadline` 3, `.subheadline.bold()` 1, `.callout` 1, `.headline` 4,
  `.title2` 3 (one is the "Log set" icon `SessionRunView.swift:195`), `.title.bold()` 2.
  `.largeTitle`, `.title3`, `.body` unused. `.fontWeight(.semibold)` at
  `ClientReportView.swift:34`, `ExerciseReportView.swift:20`. Row titles carry no `.font`.
- **Spacing/frames**: explicit stack spacing at `ReportExporter.swift:76,113` (12),
  `SessionRunView.swift:182` (6), `ClientReportView.swift:66` and
  `ExerciseReportView.swift:41` (2), `ScheduleView.swift:12,14,17` (0/12/2),
  `TrainMeApp.swift:91` (20), `LockGateView.swift:34` (16). Padding: `.padding(32)` on
  PDF pages and recovery; `ScheduleView.swift:32-33,39`; `ExerciseListView.swift:26-27`;
  chart `.padding(.vertical, 4)`. Frames: `SessionRunView.swift:281,290,299,310`
  (minWidth 56/44/52, width 80); `WorkoutBuilderView.swift:168` (width 90); chart
  heights 220 default (`ClientReportView.swift:118,165`), 150/180 on PDF pages.
- **Subview declarations and reuse**:

  | View | Declared | Used |
  |---|---|---|
  | `SessionRow` | `ScheduleView.swift:94` | `ScheduleView.swift:54`, `ClientDetailView.swift:111` |
  | `PlannedEntryRow` (private) | `SessionRunView.swift:171` | `:49` |
  | `SetEntryView` | `SessionRunView.swift:257` | `:216` |
  | `ExercisePickerView` | `WorkoutBuilderView.swift:112` | `:70` |
  | `EntryTargetEditView` | `WorkoutBuilderView.swift:151` | `:78` |
  | `OptionalStepper` | `WorkoutBuilderView.swift:184` | `:160,161,170` |
  | `ExerciseProgressChart` | `ClientReportView.swift:113` | `ExerciseReportView.swift:25,29,33`; `ReportExporter.swift:85,88,91` |
  | `VolumeChart` | `ClientReportView.swift:163` | `:48`; `ReportExporter.swift:122` |
  | `PermissionRow` | `SettingsView.swift:202` | `:87,92` |
  | `RecoveryView` | `TrainMeApp.swift:84` | `:74` |
  | `LockGateView<Content>` | `LockGateView.swift:5` | `TrainMeApp.swift:70` |
  | `MessageComposeView` | `S/Services/MessagingService.swift:23` | `SessionRunView.swift:136` |
  | `ExerciseReportPage` / `ClientOverviewPage` | `ReportExporter.swift:68,104` | report views + `Tests/ReportExporterTests.swift:12,27` |

- **Duplicated look-alike code** (written inline, not shared):
  1. Title + `.caption .secondary` subtitle row at 10 sites: `ClientListView.swift:20-27`,
     `WorkoutListView.swift:21-27`, `ExerciseListView.swift:15-21`,
     `WorkoutBuilderView.swift:33-39,127-132`, `ClientReportView.swift:66-69`,
     `ExerciseReportView.swift:41-45`, `SessionRunView.swift:184-190`,
     `ScheduleView.swift:17-22,100-110`.
  2. `Section { Text(error).foregroundStyle(.red) }` at the 12 `.red` sites above.
  3. Hand-written `HStack { label; Spacer; Button(−); Text.frame(minWidth:); Button(+) }`
     ×4 in `SetEntryView` (`SessionRunView.swift:277-311`) versus a SwiftUI `Stepper` in
     `OptionalStepper` (`WorkoutBuilderView.swift:184-210`).
  4. Trailing decimal `TextField` rows: `SessionRunView.swift:303-311`,
     `WorkoutBuilderView.swift:162-169`.
  5. `.labelStyle(.iconOnly).buttonStyle(.plain)` icon buttons: `ScheduleView.swift:27-30`,
     `SessionRunView.swift:193-197,205-211`, `WorkoutBuilderView.swift:201-204`.
  6. Identical "Share report" menu: `ClientReportView.swift:77-86`,
     `ExerciseReportView.swift:51-60`.
  7. Centered icon/headline/prominent-button screens: `RecoveryView`
     (`TrainMeApp.swift:91-107`), lock screen (`LockGateView.swift:34-46`).
  8. `ellipsis.circle` Menu: `SessionRunView.swift:90-97`, `ClientDetailView.swift:61-71`.
  9. Cancel/Save toolbar pair in 5 sheets (`SetEntryView` uses "Log").
  10. PDF page header/footer blocks: `ReportExporter.swift:76-79,94-99` vs `:113-116,129-134`.
- **Containers**: default-style `List` ×9 (no `.listStyle`); `Form` ×7; `Section("…")`
  string headers mostly, closure form with footers at `SettingsView.swift:52-101`,
  `SessionEditView.swift:131-135`; `LabeledContent` ×8; `Picker` `.segmented` ×3, `.menu`
  ×1; `.datePickerStyle(.graphical)` at `ScheduleView.swift:38`;
  `.navigationBarTitleDisplayMode(.inline)` on all sheets and both report screens, system
  default on tab roots, `SessionRunView`, `ClientDetailView`, `SettingsView`.
  `.buttonStyle(.borderedProminent)` ×3, `.bordered` ×7, `.plain` ×4.

## Q3: Navigation structure, taps to key actions, and per-screen states

### Findings
- Launch: `S/TrainMeApp.swift:62-82` `WindowGroup` switches on `AppBootstrap.state`;
  `.ready` → `LockGateView { RootView }` (`:69-72`); `.failed` → `RecoveryView` (`:73-78`).
  `AppBootstrap.init` (`:15-24`) clears import snapshot, runs version-change backup, opens
  the SwiftData container (`S/Persistence/PersistenceController.swift:8-23`).
- `LockGateView.swift:11-17` shows content only when `lock.isUnlocked`; lock screen is
  `lock.fill` icon + "TrainMe is locked" + "Unlock" button (`:33-47`). If no passcode is
  set, `AppLock.swift:36-39` unlocks immediately.
- **Tabs** (`S/RootView.swift:28-62`, iOS 18 `Tab(...)` API, `@State selectedTab = 0`):

  | # | Label | Symbol | Root |
  |---|---|---|---|
  | 0 | Schedule | `calendar` | `ScheduleView` |
  | 1 | Clients | `person.2` | `ClientListView` |
  | 2 | Workouts | `list.clipboard` | `WorkoutListView` |
  | 3 | Exercises | `dumbbell` | `ExerciseListView` |
  | 4 | Settings | `gearshape` | `SettingsView` (`.badge("!")` when export due, `:62`) |

  Symbols are outline variants; no `.search` tab role; no `tabBarMinimizeBehavior`.
  Wrapped modifiers: first-run alert "Your data lives only on this iPhone" (`:64-68`,
  `@AppStorage("hasSeenBackupNotice")`); seed-failure alert (`:82-86`); `.task` seeds
  exercises and requests notification/calendar auth (`:87-101`).
- No `.fullScreenCover` or `.navigationDestination` anywhere. Each tab root owns a
  `NavigationStack`; every sheet owns its own. Pushes use `NavigationLink { dest }`.
- **Schedule tab** (`F/Schedule/ScheduleView.swift`): export banner `:13-35`, graphical
  `DatePicker` `:37-39`, session `List` `:41-56`; row pushes `SessionRunView` (`:42-55`);
  toolbar "Add" `:65` → `SessionEditView` sheet `:67-77`; "Calendar" alert `:78-85`.
  From `SessionRunView`: Menu "Edit session" → `SessionEditView` sheet (`:100-111`);
  "Text reminder" → `MessageComposeView` sheet (`:134-145`, only if client has phone and
  `MessagingService.canSendText`); "Log set" → `SetEntryView` `.medium` sheet (`:215-223`).
- **Clients tab** (`F/Clients/ClientListView.swift`): row pushes `ClientDetailView`
  (`:10-28`); "Add" → `ClientEditView` sheet (`:43-47`); `.searchable` `:38`.
  `ClientDetailView`: session rows push `SessionRunView` (`:98-113`); "View progress"
  pushes `ClientReportView` (`:44-50`); Menu Edit → sheet (`:90-94`), Archive →
  confirmationDialog (`:73-89`). `ClientReportView` rows push `ExerciseReportView`
  (`:62-65`); share Menu with two `ShareLink`s (`:77-86`). `ExerciseReportView` is a leaf.
- **Workouts tab** (`F/Workouts/WorkoutListView.swift`): rows are Buttons opening
  `WorkoutBuilderView` via `.sheet(item:)` (`:18-28,57-65`); "Add" `:46-56`; swipe
  Delete/Duplicate `:29-33`; delete confirmationDialog `:66-78`. Builder: "Add exercise"
  → `ExercisePickerView` sheet (`:69-73`); entry tap → `EntryTargetEditView` `.medium`
  sheet (`:74-83`).
- **Exercises tab** (`F/Exercises/ExerciseListView.swift`): rows are Buttons → 
  `ExerciseEditView` sheet (`:59-63`); "Add" `:51-58`; category `Picker` `.topBarLeading`
  (`:40-49`); `.searchable` `:38`. No pushes.
- **Settings tab** (`F/Settings/SettingsView.swift`): `.fileExporter` `:117-134`,
  `.fileImporter` `:135-144`, import-mode confirmationDialog `:145-153`, "Replace
  everything?" alert `:154-161`; `PermissionRow` "Open Settings" link `:202-216`. No
  toolbar, no pushes.
- **Minimum taps from cold launch** (lock off, notice dismissed, typing not counted):
  - Open today's session and log one set: **3** (row `ScheduleView:42` → "Log set"
    `SessionRunView:193` → "Log" `:332`; sheet prefills planned targets `:347-351`).
  - New client: **5** (tab → Add → name → phone → Save; Save gated by
    `ClientEditViewModel.swift:31-33`).
  - New workout with one exercise: **6** (tab → Add → name → Add exercise → pick → Save;
    defaults 3×10 from `WorkoutBuilderViewModel.swift:37-50`).
  - Schedule a session: **4** (Add → client picker → choose → Save; default 9:00/60 min
    `SessionEditView.swift:14,55`).
- **States**: `ProgressView` appears nowhere; no loading indicators. Empty states via
  `ContentUnavailableView` as `List.overlay` in `ScheduleView:59` ("No sessions this
  day"), `ClientListView:32-35`, `WorkoutListView:41`, `ExerciseListView:35`; inline in
  `ClientReportView:18-22,127-131,186-188`; plain secondary `Text` in
  `ClientDetailView:29,37`, `ClientReportView:39,52`, `ExerciseReportView:38`,
  `SessionEditView:83`. `SessionRunView`, `SetEntryView`, `ClientEditView`,
  `WorkoutBuilderView` (exercises section), `ExercisePickerView`, `EntryTargetEditView`,
  `ExerciseEditView`, `SettingsView` have none.
- Destructive confirmations: delete session alert (`SessionRunView:120`), no-show/cancel
  alert (`:146-157`, "This can't be changed back from the app."), delete set dialog
  (`:224`), archive dialog (`ClientDetailView:73`), delete workout dialog
  (`WorkoutListView:66`), import replace dialog + alert (`SettingsView:145,154`), recovery
  reset alert (`TrainMeApp:109-114`). "Mark Completed" (`SessionRunView:62`) and
  "Duplicate" workout have none.
- Error presentation: inline red `Section` text in Session, Reports, Client edit/detail,
  Workout list/builder, Exercise edit, Session edit; secondary-color `statusMessage` in
  Settings (`:103-107`); alerts only for calendar and seed failures. Load errors use
  `try?` or `Log.ui.debug` (`ScheduleViewModel.swift:45,47,59`,
  `ClientListViewModel.swift:30`, `ExerciseListViewModel.swift:22`,
  `WorkoutBuilderView.swift:32,143,145`, `SessionRunViewModel.swift:57,62,202,211`).
- Toolbar: tab roots use a placement-less `Button("Add", systemImage: "plus")`
  (`ScheduleView:64-66`, `ClientListView:40-42`, `WorkoutListView:45-47`);
  `ExerciseListView:40-53` uses explicit leading/trailing; `SessionRunView:84-98` uses
  `ToolbarItemGroup(.topBarTrailing)`; sheets use `.cancellationAction`/`.confirmationAction`.

## Q4: In-session recording screen layout and controls

### Findings
- `F/Session/SessionRunView.swift:15-159` is one `List` with sections in order: error
  (`:17-21`), injuries (`:22-30`, orange `Label` `.callout`, shown when client has
  injuries), info (`:32-35`, `LabeledContent` Time and Status, plain text, no color/icon),
  notes (`:37-44`, vertical `TextField` `.lineLimit(2...6)`, "Save notes" button appears
  only when draft differs), one `Section(instance.name)` per workout instance with a
  `PlannedEntryRow` per planned entry (`:46-58`), status buttons when `.scheduled`
  (`:60-72`), series note when `!canEdit` (`:74-80`). Title is the client name (`:82`).
- `PlannedEntryRow` (`:171-255`): `VStack(spacing: 6)`; exercise name (default font) with
  "Target: …" `.caption .secondary` below; trailing "Log set" `plus.circle.fill` icon-only
  button `.font(.title2)` `.buttonStyle(.plain)` `.foregroundStyle(.tint)` with no explicit
  frame (`:193-197`); completed sets listed as `.caption .secondary` lines "Set N: …" each
  with a `.caption` `minus.circle` delete button (`:199-213`). No checkmark, progress
  indicator, or side-by-side comparison against target.
- `targetText` (`:237-245`) joins "sets×reps", "@ weight", "durations"; target distance is
  not displayed. `setSummary` (`:247-254`) shows weight, "×reps", "Ns", "distance unit".
- `SetEntryView` (`:257-354`): `Form` in `NavigationStack`, `.medium` detent, inline title
  (exercise name or "Log Set"). Rows gated by `exercise?.metrics ?? [.weight, .reps]`
  (`:269`; `MetricSet` OptionSet in `S/Models/Exercise.swift:13-21`):
  - Weight `:276-284`: "−step"/"+step" `.bordered` buttons, value `Text.frame(minWidth: 56)`;
    step 2.5 kg / 5 lb (`S/Support/WeightFormatter.swift:28-30`); clamps at 0.
  - Reps `:285-293`: ±1, `minWidth: 44`.
  - Duration `:294-302`: ±15 s, `minWidth: 52`.
  - Distance `:303-312`: the only `TextField` (`.decimalPad`, trailing, `width: 80`).
  - No `Stepper`, `Picker`, keyboard entry for weight/reps/duration, or explicit tap-target
    frames; all ± buttons are default-size `.bordered`.
- Initial values seeded from planned targets `.onAppear` (`:347-351`); distance not seeded.
- "Repeat last set" (`:314-323`) → `viewModel.lastSet` (`SessionRunViewModel.swift:158-165`)
  → `SessionRepository.lastSet` (`S/Persistence/SessionRepository.swift:273-286`), most
  recent `SetRecord` for that exercise across all the client's sessions. It fills the form;
  user still taps "Log". Always shown regardless of metrics.
- "Log" (`:327-346`) → `viewModel.record` (`:115-142`): setIndex = max+1, `rpe: nil`;
  failure sets "Couldn't log that set."
- Unit label: `exercise?.defaultUnit ?? .lb` → `WeightFormatter.label` (`:12-17`); no
  conversion. Distance label uses raw `Unit.rawValue` (lb/kg/mi/km/min/sec).
- Status: "Mark Completed" fires directly (`:62-64`); Cancelled/No-show set
  `pendingStatus` → alert (`:146-157`). `setStatus` (`SessionRunViewModel.swift:167-190`)
  removes the calendar event on cancel. Display updates only the "Status" text; the
  button section disappears.
- Haptics, `.sensoryFeedback`, Live Activity, rest timer: none in `Sources/`.

## Q5: Accessibility and appearance support

### Findings
- Grep across `Sources/` for `accessibilityLabel`, `accessibilityHint`,
  `accessibilityValue`, `accessibilityIdentifier`, `@ScaledMetric`, `dynamicTypeSize`,
  `preferredColorScheme`, `colorScheme`, `UIUserInterfaceStyle`, `minimumScaleFactor`,
  `.sensoryFeedback`, haptic generators, and the word "accessibility": **zero hits**.
- `lineLimit` only at `SessionRunView.swift:39` and `ClientEditView.swift:32`.
- Icon-only buttons rely on their `Button("Title", systemImage:)` string for VoiceOver.
- No forced color scheme; `Info.plist` has no `UIUserInterfaceStyle`. AccentColor has no
  dark variant (Q1). Fixed `.white` background on PDF pages is the only non-adaptive color.
- Charts (`F/Reports/ClientReportView.swift`): `ExerciseProgressChart` `:113-161` uses
  `LineMark` `.monotone` + `.symbol(.circle)` with default tint (`:136-142`), orange PB
  `PointMark` with "PB" `.caption2.bold()` annotation (`:143-154`), `.chartYAxisLabel`
  (`:156`), no x-axis label, no custom axis marks or legend, no accessibility modifiers.
  `VolumeChart` `:163-199` `BarMark` colored `by: .value("Unit")`, default legend,
  `.chartYAxisLabel("weight × reps")` (`:194`). Heights 220 default.
- PDF (`S/Services/ReportExporter.swift`): `ImageRenderer` (`:16`) at `scale = 3`
  (`:18`), page 612×792 (`:11`), single page via `CGContext` PDF (`:30-40`); PNG via
  `uiImage.pngData()` (`:43-46`); files in `tmp/Reports` with complete file protection
  (`:47-52`). Pages use semantic text styles, `.padding(32)`, `.background(.white)`
  (`:99,134`); no `colorScheme` set; `ClientOverviewPage` lists `prefix(8)` exercises.
- `S/Info.plist` (complete): development region en, display name "TrainMe" (`:21-22`),
  portrait only (`:23-26`), no `~ipad` key, `NSCalendarsFullAccessUsageDescription`,
  `NSFaceIDUsageDescription`, `UILaunchScreen` empty (`:31-32`), version 1.0 (1). No
  `UIUserInterfaceStyle`, `UIDeviceFamily`, `UIRequiresFullScreen`.
- `project.yml`: iOS 26.0, Swift 6.0 strict concurrency (`:3-9`); `TARGETED_DEVICE_FAMILY`
  not set (XcodeGen iOS preset default); no other UI build settings.

## Q6: Market conventions and Apple HIG for iOS 26

### Findings
Text-retrievable sources only; the agent could not inspect screenshots or icon images.

**Apple HIG / WWDC25**
- App icons (developer.apple.com/design/human-interface-guidelines/app-icons, updated
  2025-06-09 and 2026-06-08): icons "include a background layer and one or more
  foreground layers"; the system adds specular, refraction, translucency, blur. Provide
  unmasked vector layers with full-bleed opaque backgrounds. Six variants: default, dark,
  clear light/dark, tinted light/dark; "the system automatically generates variants you
  don't provide." Icon Composer annotates default/dark/mono. WWDC25 session 220: favor
  flat frontal views, avoid thin lines and sharp edges, prefer System Light/Dark gradients
  over pure white/black, colored backgrounds for light icons.
- Liquid Glass (HIG Materials; WWDC25 session 219): glass is for the navigation layer
  (tab bars, toolbars) floating above content; "Don't use Liquid Glass in the content
  layer"; "avoid glass on glass"; put brand color in the content layer; tint only primary
  actions.
- Tab bars (HIG, updated 2025-07-28/12-16; WWDC25 session 323): floats above content;
  single-word labels; filled SF Symbols; five or fewer tabs; `.tabBarMinimizeBehavior(.onScrollDown)`;
  `Tab(role: .search)` replaces the bar with a search field; `.tabViewBottomAccessory`;
  prefer monochrome tab bars over colorful content.
- Toolbars (HIG; session 323): items auto-group on glass; max three groups; `.prominent`
  for one primary action on the trailing side; monochrome icons; `ToolbarSpacer`,
  `sharedBackgroundVisibility`, `scrollEdgeEffectStyle`.
- Typography (HIG): SF Pro default 17 pt, min 11 pt; text-style sizes Large Title 34,
  Title 1 28, Title 2 22, Title 3 20, Headline 17, Body 17, Callout 16, Subhead 15,
  Footnote 13, Caption 12/11; rounded and condensed widths available; Dynamic Type body
  ranges 14–53 pt; avoid Ultralight/Thin/Light weights.

**Competitor apps** (App Store listings fetched 2026-10-26; ranks are same-day snapshots)
- Hevy (id1458862350; Health & Fitness #27 free, 4.9/~100K): tabs Home (social feed),
  Workout, Profile (hevyapp.com/compare/strong, help.hevyapp.com). Set table has a
  PREVIOUS column; tapping copies prior values (hevyapp.com/features/track-exercises);
  weight/reps/RPE in one row; set types Warmup/Normal/Drop/Failure/Superset; per-exercise
  rest timers; checkmark animation on completion; 3.1.11 "Redesigned the Set Row UI";
  3.1.x adopted "liquid glass components". Dark Mode listed. Onboarding: 10 steps then
  paywall (screensdesign.com/showcase/hevy-workout-tracker-gym-log).
- Strong (id464254577; #192, 4.9/~109K): tabs Start Workout, Profile, History, Exercises
  (+Analytics per repreturn.com/strong-app-review). "Spreadsheet-style" logging, previous
  values auto-shown, auto rest timer, plate calculator, Live Activity/Dynamic Island for
  rest timer (6.5.0). Account optional, no tutorial. Custom themes are Pro.
- Trainerize (id516851502; #172, 4.9/69K): invite-only client app; bottom tab bar; 2021
  redesign dropped menu labels and added Goals+Habits and Meal Plan tabs
  (trainerize.com/blog). Current tab order not found.
- TrueCoach (id1439127794; 4.9/~36K): account required; unified coach/client app
  switches role in Settings tab (help.truecoach.co). Tabs not found.
- Everfit (id1438926364; 4.7/2.7K): four tabs Today, Coaching, Inbox, You
  (help.everfit.io/en/articles/5555389).
- Apple Fitness (id1208224953): iOS 26 has Summary, Fitness+, Workout, Search tabs
  (afb.org/blog/entry/ios-26-mainstream-features); rings are the core visual.
- Nike Training Club (id301521403; #114, Editors' Choice): Workouts and Activity tabs
  (2020 source); six onboarding steps with no paywall (screensdesign.com).
- Fitbod (id1041517543; #28, 4.8/~288K, Editors' Choice): 14-step onboarding with
  equipment and injury selection, paywall before first workout; "clean but dense".
- JEFIT (id449810000; 4.7/4.3K): set table above a large rest timer with Skip/±15 s.
- Audience split: trainer-led invite-only (Trainerize, TrueCoach, Everfit); self-coached
  lifters (Hevy, Strong, JEFIT); auto-programmed (Fitbod); general fitness (NTC, Apple
  Fitness). Top Free Health & Fitness chart today: Strava, Flo, LADDER, Planet Fitness,
  Yuka (apps.apple.com/us/iphone/charts/6013).
- **Not found for any app**: brand hex colors, typography, photo vs illustration, icon
  artwork, keyboard type, swipe-to-complete; dark-mode status except Hevy.

## Q7: How the UI is verified today

### Findings
- `project.yml` declares two targets, `TrainMe` and `TrainMeTests` (`bundle.unit-test`);
  no UI-test target, no `packages:`, no `Package.resolved`, no `.xctestplan`,
  no `XCUIApplication`, `ViewInspector`, or snapshot library anywhere outside `thoughts/`.
- View-model tests (Swift Testing):
  - `Tests/SessionRunViewModelTests.swift`: `deleteRemovesCalendarEventAndSession` `:54`,
    `failedDeleteReturnsFalseAndSetsError` `:193`, `failedSetStatusKeepsEventIdentifier`
    `:205`, `failedRecordLeavesSetsUnchanged` `:218`.
  - `Tests/ClientDetailViewModelTests.swift`: `splitsUpcomingFromRecent` `:14`,
    `recentIsCapped` `:30`.
  - `Tests/ReportExporterTests.swift`: `renderWritesPdfAndPng` `:11`,
    `renderSweepsPreviousReportsAndSanitizesNames` `:26` (the only tests that render a
    SwiftUI view, via `ImageRenderer`).
  - `Tests/ExportReminderTests.swift`: four threshold tests `:8-21`.
- `.github/workflows/ci.yml`: on push to `main` and `pull_request`; `macos-26`, 45-min
  timeout; select Xcode 26, `brew install xcodegen`, `xcodegen generate`, list simulators,
  then `xcodebuild -scheme TrainMe -destination 'platform=iOS Simulator,name=iPhone 17'
  CODE_SIGNING_ALLOWED=NO … test`. No lint, no xcresult upload, no screenshot step.
- `#Preview` / `PreviewProvider` in `Sources/`: **zero hits**. No preview fixtures exist.

## Cross-Cutting Observations
- All styling is system-semantic and inline; there is no single file that defines the
  app's visual identity. The only brand-specific colors in the repo are the three icon
  SVGs and the amber AccentColor, and the accent reaches the UI only through default
  tint on `plus.circle.fill`, weekday toggles, `.borderedProminent` buttons, and the
  default `LineMark` color.
- Orange is used for three unrelated meanings: warnings (injuries, export banner),
  no-show status, and personal-best highlights.
- The same row/section shapes are re-typed in ~10 places each, and the `SetEntryView`
  steppers diverge from the `OptionalStepper` used in the workout builder.
- Every list uses the default style, every sheet uses inline titles, and the tab symbols
  are the outline variants. No iOS 26 tab/toolbar APIs (`tabBarMinimizeBehavior`,
  `Tab(role: .search)`, `ToolbarSpacer`, `.prominent`) appear in the code.
- Nothing in the codebase exercises the view layer visually: no previews, no UI tests,
  no snapshot tests, and CI runs unit tests only.
- The icon package defines a single appearance and relies on the system for dark, tinted,
  and clear variants, while the prior design doc targeted explicit default/dark/mono.

## Open Areas
- Competitor icon artwork, brand palettes, typography, and most dark-mode behavior could
  not be established from text sources; a screenshot review would be needed.
- Whether the committed `icon.json` group order change from the plan was deliberate is
  not recorded anywhere in the repo.
- Actual rendered tap-target sizes of the `.bordered` ± buttons and the icon-only "Log
  set" button were not measured; the code sets no explicit frames.
- Whether XcodeGen's iOS preset yields device family 1,2 (iPhone + iPad) for this target
  was inferred from a prior build artifact, not from an explicit setting.
