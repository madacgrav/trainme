# Research Findings

Date: 2026-07-08. Repo is greenfield (Q1), so Q2–Q8 findings are platform/tooling
facts from Apple docs and verified ecosystem sources (citations inline). API-era:
iOS 17/18/26.

## Q1: Current state of this repository

### Findings
- Tracked files are only `.gitignore`, `LICENSE`, `README.md`; untracked `PRD.md` at
  repo root. No `.xcodeproj`, `.xcworkspace`, `Package.swift`, `project.yml`,
  `Project.swift`, or any `.swift` source anywhere.
- `README.md:1` contains only `# trainme`.
- `.gitignore:1-27` is a Java/Kotlin/Gradle template (`*.class`, `*.jar`, `.kotlin/`,
  BlueJ/J2ME entries) — it does not match an iOS/Swift toolchain and ignores nothing
  Xcode-relevant (no `DerivedData/`, `*.xcuserstate`, `.build/`).
- Host toolchain (updated 2026-07-08, after user installed build tools): **Xcode 26.6
  (build 17F113) installed at `/Applications/Xcode.app`**, license accepted
  (`-checkFirstLaunchStatus` exits 0). iOS 26.5 SDK + iOS 26.5 simulator runtime
  present; available simulators include iPhone 17 / 17 Pro / 17 Pro Max / 17e / Air.
  Caveat: `xcode-select -p` still points to `/Library/Developer/CommandLineTools`
  and switching requires sudo (unavailable non-interactively), so builds must prefix
  commands with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` — verified
  working for `xcodebuild` and `xcrun simctl`. `xcodegen`, `tuist`, and
  `xcodebuildmcp` are not installed.

## Q2: On-device persistence (SwiftData vs Core Data)

### Findings
- SwiftData (iOS 17+) is a macro-driven layer over Core Data's engine — same SQLite
  store; `ModelContainer`≈`NSPersistentContainer`, `ModelContext`≈`NSManagedObjectContext`
  (WWDC23 "Migrate to SwiftData").
- **UUID identity is manual**: no framework primary-key mechanism. Pattern is
  `@Attribute(.unique) var id: UUID`. Internal `PersistentIdentifier` is Sendable but
  has an untestable temporary state pre-save. iOS 18 adds `#Unique` (compound) and
  `#Index` macros. Note: `@Attribute(.unique)` is incompatible with CloudKit sync.
- **Timestamps are manual**: no auto `createdAt`/`updatedAt`; declare
  `var createdAt: Date = .now` and set `updatedAt` explicitly in mutation code.
- **Relationships**: `@Relationship(deleteRule: .cascade|.nullify|.deny|.noAction,
  inverse: \Child.parent)`; to-many as `var items: [Item] = []`; many-to-many via
  arrays both sides. Explicit `inverse:` on exactly one side recommended. Perf gotcha:
  per-element `.append()` on to-many is ~700× slower than `.append(contentsOf:)`.
- **Repository abstraction**: `ModelContext` is a concrete class (not protocol-typed);
  `@Model` objects are context-bound and not Sendable. Documented patterns: (1)
  dual-model — internal `@Model` classes mapped to plain domain structs at the
  repository boundary; (2) protocol-typed service exchanging `PersistentIdentifier`s;
  (3) `@ModelActor` repository with async methods. **`@Query` cannot be used behind a
  protocol boundary** — abstracted fetches use `FetchDescriptor` inside the repo and
  surface via `@Observable` state.
- **Gotchas**: `@ModelActor` can execute on the main thread when called from a
  `@MainActor` context (persists through iOS 26; `Task.detached` forces background).
  Migrations via `VersionedSchema`/`SchemaMigrationPlan` (`.lightweight`/`.custom`
  stages) have documented bugs and Swift-6 Sendable warnings. Testing:
  `ModelConfiguration(isStoredInMemoryOnly: true)` + `container.mainContext`;
  serialize suites sharing a container.
- Sources: developer.apple.com/documentation/swiftdata, fatbobman.com (concurrency,
  relationships), azamsharp.com 2025-03-28 (architecture), swiftorbit.io (decoupling).

## Q3: Local notifications & message composition

### Findings
- `UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.sound,.badge])`;
  no Info.plist key needed for local notifications. Status via `notificationSettings()`.
- Scheduling ahead of a dated event: `UNCalendarNotificationTrigger(dateMatching:
  DateComponents(y/m/d/h/m), repeats: false)` or `UNTimeIntervalNotificationTrigger`;
  two separate `UNNotificationRequest`s (distinct identifiers) for 24h/1h alerts.
  `add()` with an existing identifier silently replaces;
  `removePendingNotificationRequests(withIdentifiers:)` cancels.
- **Hard cap: 64 pending requests per app** (Apple forums thread/811171); excess
  silently discarded. Standard mitigation: schedule nearest-N, reschedule on
  launch/foreground.
- Delivery is fully on-device via the system daemon — fires with app killed and no
  network. Foreground display needs delegate `willPresent` returning `[.banner,...]`.
- `MFMessageComposeViewController` (MessageUI): check `canSendText()`; pre-fill
  `recipients` (E.164 strings) and `body`; delegate `didFinishWith` (.sent/.cancelled/
  .failed) must dismiss. **Platform rule: no silent/scheduled SMS — user must tap Send
  in the sheet. No API bypass exists.** Same for `MFMailComposeViewController`
  (`canSendMail()`, set-methods, `addAttachmentData(_:mimeType:fileName:)`).
- No native SwiftUI wrappers as of iOS 18/26 — both are presented via
  `UIViewControllerRepresentable` + Coordinator in a `.sheet`.
- Sources: developer.apple.com/documentation/usernotifications, /messageui.

## Q4: Time-series line charts (Swift Charts)

### Findings
- `import Charts`, iOS 16+. `Chart { LineMark(x: .value("Date", d, unit: .day),
  y: .value("Weight", w)) }`; Date is a native plottable type. `.symbol()` or paired
  `PointMark` for per-datum dots; `.interpolationMethod(.monotone)` etc.
- Multiple series: `foregroundStyle(by: .value(...))` (auto colors + legend) and/or
  `series: .value(...)` when lines share an x-domain.
- Axes: `.chartXAxis { AxisMarks(values: .stride(by: .month)) }`, `AxisValueLabel`
  with custom view; `.chartYScale(domain:)` pins range.
- **Personal-best callouts**: `PointMark` or `RuleMark` + `.annotation(position:
  .top, ...)` with any SwiftUI view; `RuleMark` outside `ForEach` draws once;
  `.lineStyle(StrokeStyle(dash:))` for dashed reference lines.
- **Sparse data: no built-in "insufficient data" state.** 0 points → empty axes;
  1 point → no visible line (PointMark shows a dot). Prevalent pattern: guard
  `data.count < 2` and render a placeholder view instead of the Chart.
- Interactivity: iOS 17 `.chartXSelection(value:)` replaces iOS 16
  `chartOverlay`+`ChartProxy` boilerplate; iOS 18 `.chartGesture` (the old
  overlay+tap pattern stopped working in iOS 18).
- Sources: developer.apple.com/documentation/charts, WWDC22 10137, WWDC23 10037.

## Q5: File export/import & versioned JSON

### Findings
- Export paths: SwiftUI `.fileExporter` (iOS 14+; iOS 17+ overloads take
  `Transferable`, add `onCancellation`) presents the system picker — user chooses
  destination (iCloud Drive/On My iPhone); completion returns `Result<URL, Error>`.
  `ShareLink` (iOS 16+) is the SwiftUI share sheet for `Transferable` items;
  `UIActivityViewController` is the UIKit equivalent.
- `FileDocument` protocol: `readableContentTypes`, `init(configuration:)`,
  `fileWrapper(configuration:)`. `Transferable` representations:
  `CodableRepresentation`, `DataRepresentation`, `FileRepresentation`,
  `ProxyRepresentation`. Known iOS 17 bug: `FileRepresentation` via ShareLink →
  "Save to Files" fails; workaround is FileRepresentation + ProxyRepresentation both.
- Import: `.fileImporter(allowedContentTypes:)` returns security-scoped URLs —
  `startAccessingSecurityScopedResource()` / `defer { stop... }` required; access
  doesn't persist across launches (bookmarks needed for that).
- JSON: `UUID` is natively Codable (uppercase hyphenated string). Dates via
  `dateEncodingStrategy = .iso8601` (no fractional seconds unless `.custom`).
  Versioning pattern: top-level `schemaVersion: Int`, decode it first, branch decoder
  by version; optionals/`decodeIfPresent` absorb missing keys; unknown top-level keys
  are ignored by synthesized Decodable. `VersionedCodable` (SPM) formalizes chained
  version migration.
- Relational export pattern: top-level object with named entity arrays, each record
  carrying `id: UUID`, cross-references as UUID fields. Import semantics are
  app-defined: wipe-and-restore vs merge-by-id (upsert; "newer wins" on a modified
  timestamp); SwiftData `@Attribute(.unique)` can automate upsert-by-id.
- CSV: no Foundation API; manual RFC-4180 escaping or `CodableCSV` (SPM); write
  String to URL, export via the same pickers.
- Sources: developer.apple.com/documentation/swiftui (fileExporter/fileImporter),
  WWDC22 10062 (Transferable), useyourloaf.com (security-scoped files).

## Q6: Biometric lock & Data Protection

### Findings
- `LAContext` (LocalAuthentication): `canEvaluatePolicy` pre-check, then async
  `evaluatePolicy(_:localizedReason:)`. **`.deviceOwnerAuthentication` = biometrics
  with automatic device-passcode fallback** (covers `.biometryLockout`);
  `.deviceOwnerAuthenticationWithBiometrics` = biometrics only, no fallback.
  `biometryType` → `.faceID`/`.touchID`/`.opticID`. Fresh `LAContext` per attempt
  (reused succeeded contexts skip the prompt); `invalidate()` for logout.
- `NSFaceIDUsageDescription` Info.plist key is **mandatory** for Face ID (absence →
  `.biometryNotAvailable`); Touch ID needs no key. Key `LAError` cases: `.userCancel`,
  `.biometryNotEnrolled`, `.biometryLockout`, `.passcodeNotSet`.
- Launch-gate pattern: root view holds `isUnlocked` state; observe
  `@Environment(\.scenePhase)`; lock on `.background` (not `.inactive` — Face ID's
  own UI briefly makes the app `.inactive`); re-auth on `.active`. Blur/placeholder
  content when not active to protect the app-switcher snapshot.
- Data Protection: hardware UID + passcode derive per-file keys automatically.
  Classes: `.complete`, `.completeUnlessOpen`,
  `.completeUntilFirstUserAuthentication` (**sandbox default since iOS 7**), `.none`.
  With no device passcode set, encryption effectively degrades to `.none`.
- SwiftData/Core Data add **no encryption of their own** — the SQLite files carry the
  sandbox's protection class; `NSPersistentStoreFileProtectionKey` can raise it, but
  SQLite WAL side-files can be recreated at default class (documented complication
  with `.complete`). SwiftData's `@Attribute(.encrypt)` affects CloudKit transport
  only, not local storage. Secrets belong in Keychain, not the store.
- Sources: developer.apple.com/documentation/localauthentication, Apple Platform
  Security guide (Data Protection classes), hackingwithswift.com (SwiftData
  encryption).

## Q7: EventKit (system calendar)

### Findings
- iOS 17+ access model: `requestFullAccessToEvents()` or
  `requestWriteOnlyAccessToEvents()` (old `requestAccess(to:)` deprecated). Statuses:
  `.fullAccess`/`.writeOnly`/`.denied`/`.restricted`/`.notDetermined`. Info.plist:
  `NSCalendarsFullAccessUsageDescription` (and the write-only variant); pre-iOS 17 key
  needed only if supporting iOS 16.
- **Write-only access cannot enumerate calendars** — events land on
  `defaultCalendarForNewEvents`. Choosing a specific calendar (e.g. a Google one)
  requires full access. `EKCalendarChooser` (EventKitUI) provides the picker UI.
  Alternative: `EKEventEditViewController` runs out-of-process on iOS 17+ and needs
  **no** calendar permission at all.
- **Google calendars work via EventKit**: a Google account added in iOS Settings
  surfaces as an `EKSource` of type `.calDAV` (title = gmail address); its writable
  calendars have `allowsContentModifications == true`; `eventStore.save(event,
  span:)` writes sync to Google servers through iOS's CalDAV layer — no Google API
  or OAuth in the app.
- One-way push: store `event.eventIdentifier` after save; retrieve with
  `event(withIdentifier:)` to update/remove. Caveat: identifiers can be reassigned by
  a full CalDAV resync; `calendarItemExternalIdentifier` is more stable.
- Recurrence: `EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, daysOfTheWeek:
  [EKRecurrenceDayOfWeek(.tuesday), .init(.thursday)], ..., end: nil)` models "every
  Tue/Thu"; `EKRecurrenceEnd(occurrenceCount:)`/`(end:)` or nil for indefinite.
  Save/update with `span: .thisEvent` vs `.futureEvents`.
- Sources: developer.apple.com/documentation/eventkit, WWDC23 10052.

## Q8: Agent-driven iOS build tooling

### Findings
- **XcodeBuildMCP** — github.com/getsentry/XcodeBuildMCP (Sentry acquired Feb 2026;
  cameroncooke URL redirects there). v2.6.2, MIT, 82 tools: build/test/run on sim +
  device, simulator management, UI automation (tap/type/screenshot/accessibility
  snapshot), LLDB debugging, project discovery. Install: `brew tap getsentry/
  xcodebuildmcp && brew install xcodebuildmcp` or `npx -y xcodebuildmcp@latest`.
  Requires macOS 14.5+, **full Xcode 16.x+**.
- Simulator-only MCP alternatives: joshuayoes/ios-simulator-mcp (v1.6.0, UI
  interaction, needs Xcode+IDB), mobile-next/mobile-mcp (cross-platform iOS/Android),
  InditexTech/mcp-server-simulator-ios-idb. All overlap with XcodeBuildMCP's UI tools.
- Plain CLI: `xcodebuild build|test -scheme X -destination 'platform=iOS
  Simulator,name=iPhone 16'`; `xcrun simctl list|boot|install|launch|io screenshot|
  spawn log stream`. **Both require full Xcode.app** — Command Line Tools alone has
  no iOS SDK, no simctl, no simulator runtimes. Runtimes are a separate download:
  `xcodebuild -downloadPlatform iOS`.
- Project generation without the Xcode GUI: **XcodeGen** (v2.45.4; `project.yml` →
  `.xcodeproj`; `brew install xcodegen`; commit spec, gitignore the generated
  project) or **Tuist** (v4.18x; type-safe `Project.swift`; adds `tuist generate/
  build/test/run`, build caching). **SwiftPM alone cannot build/run an iOS app
  bundle** (libraries only) — an `.xcodeproj` is required for the app target.
- Typical agent pipeline: XcodeGen/Tuist generate → `xcodebuild` compile/test →
  `simctl` install/launch/screenshot — or XcodeBuildMCP wrapping all of it.
- Sources: repos linked above; Apple TN2339; xcodebuildmcp.com/docs/tools.

## Cross-Cutting Observations

- **Minimum-OS gravity**: SwiftData (17), `.chartXSelection` (17), EventKit's new
  access model (17), `Transferable`-based fileExporter overloads (17) all align on
  an iOS 17+ floor; Swift Charts alone would allow 16.
- **Everything local-only works offline by design**: local notifications, SwiftData,
  file export, EventKit writes (CalDAV sync happens later at OS level) — none
  require a backend.
- **User-mediated boundaries**: SMS/email send, share-sheet destination, file-picker
  destination, and calendar permission are all OS-enforced user actions; none can be
  automated.
- **Manual bookkeeping recurs**: UUIDs, timestamps, notification-identifier
  management (64-cap), and `eventIdentifier` storage are all app-maintained
  conventions, not framework features.
- **Environment**: Xcode 26.6 + iOS 26.5 SDK/simulators are installed and verified
  (Q1); the only friction is that `xcode-select` still targets Command Line Tools,
  so all build commands need the `DEVELOPER_DIR` env-var prefix (or a one-time
  `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` by the user).

## Open Areas

- Exact behavior of SwiftData lightweight migration for the specific schema shapes
  this project will use — community reports are contradictory; needs empirical
  verification once models exist.
- Whether `@ModelActor` main-thread anomalies matter here in practice — depends on
  final concurrency design; untestable until code exists.
- `NSPersistentStoreFileProtectionKey` interaction with SwiftData's
  `ModelConfiguration` — documented for Core Data; SwiftData plumbing is thinly
  documented and should be verified empirically.
