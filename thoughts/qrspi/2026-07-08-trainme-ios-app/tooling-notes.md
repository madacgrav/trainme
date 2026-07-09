# Development Tooling Assessment (Claude environment)

Preliminary scan done during the Question phase (2026-07-08) of which Claude Code
skills, agents, plugins, and MCP servers can help build this iOS/SwiftUI app.
Research question 8 in `questions.md` asks the Research phase to verify/extend the
ecosystem items below.

## Directly useful — already available in this session

**QRSPI plan toolkit agents** (used by phases 2–7):
- `codebase-locator`, `codebase-analyzer`, `codebase-pattern-finder` — limited value
  until code exists; increasingly useful as the app grows.
- `web-search-researcher` — key for phase 2 here, since most research questions are
  about iOS platform APIs (SwiftData, UNUserNotificationCenter, EventKit, Swift
  Charts, LocalAuthentication), not existing code.

**Skills:**
- `engineering:architecture` / `engineering:system-design` — useful in the Design
  phase (ADR for persistence choice, repository-protocol layering, export schema).
- `engineering:testing-strategy` — test plan for the data layer / export round-trip.
- `code-review` / `simplify` / `security-review` — per-slice review during
  implementation; `security-review` relevant given PII + biometric-lock requirements.
- `verify` / `run` — post-change verification; on iOS this depends on driving the
  simulator (see MCP gap below).

**MCP servers connected to this session:**
- **computer-use** — can drive Xcode and the iOS Simulator GUI (screenshots, clicks)
  for manual-style verification. Caveat: IDEs are click-tier only (no typing), so
  it's for observation/launching, not editing.
- **Claude in Chrome / Claude Preview** — web-oriented; not applicable to a native
  iOS app.
- **Microsoft Learn MCP** — Microsoft/Azure docs only; not applicable.
- Gmail/Calendar/ADO/productivity connectors — not applicable to building the app.

## Gaps + ecosystem candidates (verify in Research phase)

- The claude.ai MCP connector registry returned **zero results** for
  xcode/ios/swift/simulator/apple keywords — no first-party connector exists.
- Known community MCP servers (from training data; verify current names/status):
  - **XcodeBuildMCP** (cameroncooke/XcodeBuildMCP) — build/run/test Xcode projects,
    manage simulators, read build errors, capture simulator screenshots. Would be the
    single highest-value addition; installable per-project via `claude mcp add`.
  - **ios-simulator-mcp** — simulator UI interaction/inspection.
- Without an Xcode MCP, the fallback is plain Bash: `xcodebuild`, `xcrun simctl`
  (boot simulator, install app, `simctl launch`, screenshots), and
  `xcodebuild test` — all workable from the Bash tool on this macOS host.
- Project generation without Xcode GUI: `xcodegen` or `tuist` (spec-file-driven
  `.xcodeproj` generation) — worth researching, since Claude cannot click through
  Xcode's "New Project" wizard (except via computer-use).

## Not useful for this project

Web/preview tooling, Azure DevOps suite, productivity/comms connectors (Slack,
Notion, Linear, etc.) — unrelated to a local-only native iOS build.
