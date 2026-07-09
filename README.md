# TrainMe

A local-only iOS app for an independent personal trainer: manage clients, build
reusable workouts, schedule and record training sessions, and track each client's
progress over time. See [PRD.md](PRD.md) for the full product requirements.

## Building

The Xcode project file is **generated, not committed**. The project is defined by
[`project.yml`](project.yml); [XcodeGen](https://github.com/yonaskolb/XcodeGen)
turns it into `TrainMe.xcodeproj`.

After a fresh clone — or whenever files are added/removed outside Xcode — run:

```bash
brew install xcodegen   # first time only
xcodegen generate
open TrainMe.xcodeproj
```

Then select the **TrainMe** scheme, pick an iPhone simulator, and ⌘R.

### Command-line build & test

```bash
xcodegen generate
xcodebuild -scheme TrainMe -destination 'platform=iOS Simulator,name=iPhone 17' test
```

If `xcodebuild` complains that it "requires Xcode" even though Xcode is installed,
either prefix commands with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
or run once:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## Requirements

- Xcode 26+ with the iOS 26 simulator runtime
- Deployment target: iOS 26

## Project layout

- `Sources/Models/` — SwiftData `@Model` types and their Codable DTOs
- `Sources/Persistence/` — `@ModelActor` repositories, seed import, store backup
- `Sources/Services/` — notifications, messaging, EventKit calendar, PDF reports, export/import archive, app lock
- `Sources/Features/` — SwiftUI views + view models per feature (Schedule, Clients, Workouts, Exercises, Session, Reports, Settings)
- `Tests/` — Swift Testing suite (runs against in-memory containers); `Tests/Fixtures/export-v1.json` is the frozen export-format compatibility fixture — never regenerate it
- `thoughts/qrspi/` — design/research/plan artifacts from the initial build
