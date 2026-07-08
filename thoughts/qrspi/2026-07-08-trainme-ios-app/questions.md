# Research Questions

## Context

This is a native iOS / Swift / SwiftUI project targeting an on-device, no-backend
application. Research should focus on two areas: (1) the current state of this
repository — what build tooling, project configuration, and source scaffolding already
exist; and (2) the iOS/SwiftUI platform capabilities relevant to on-device data
persistence, scheduled local notifications, user-initiated message composition,
time-series charting, file-based export/import, system calendar integration, and
biometric authentication. Report
facts about what exists and how these mechanisms work — not recommendations.

## Questions

1. What is the current state of this repository — what build tooling, Xcode/Swift
   Package configuration, dependencies, directory layout, and source scaffolding (if
   any) already exist, and what does `.gitignore` reveal about the intended toolchain?

2. What on-device persistence options does current iOS/SwiftUI provide (SwiftData vs.
   Core Data), and how do they support entities with stable UUID identity,
   `createdAt`/`updatedAt` timestamps, relationships/cascade rules, and being placed
   behind a repository/protocol abstraction layer rather than accessed directly from
   the UI?

3. How do iOS local notifications (`UNUserNotificationCenter`) work for scheduling
   alerts ahead of a future dated event, and how does message composition
   (`MFMessageComposeViewController`) work for presenting a pre-filled, user-confirmed
   send — including permission/authorization flows and platform limitations on
   automated sending?

4. What are the standard iOS/SwiftUI approaches to rendering line charts of time-series
   numeric data (e.g. Swift Charts), including handling of sparse or insufficient data
   points and per-series callouts?

5. How does file export and import work on iOS through the Files app and the system
   share sheet (`UIActivityViewController` / document picker), and what established
   patterns exist for versioned JSON serialization with cross-referenced stable
   identifiers plus merge-vs-replace import semantics?

6. How does biometric authentication (`LocalAuthentication`, Face ID / Touch ID) with a
   passcode fallback integrate as an app-launch gate, and how does iOS Data Protection
   provide encryption-at-rest for on-device storage?

7. How does EventKit support programmatically creating and updating events in the iOS
   system calendar — including permission flows, writing to calendars backed by
   third-party accounts (e.g. Google), one-way push of app-managed events, and
   representing recurring events (recurrence rules)?

8. What development tooling exists for building, testing, and running iOS apps from a
   command-line / agent-driven environment — specifically: current MCP servers for
   Xcode and the iOS Simulator (e.g. XcodeBuildMCP, ios-simulator-mcp — verify names,
   status, and capabilities), the `xcodebuild` / `xcrun simctl` CLI workflow, and
   spec-driven Xcode project generation tools (XcodeGen, Tuist)? See
   `tooling-notes.md` in this directory for candidates already identified.
