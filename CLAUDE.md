# CLAUDE.md — radcap

This file provides guidance to Claude Code when working with code in this repository.

> **Note to radcap agent:** This CLAUDE.md was bootstrapped by the bmw-dev-stack meta-agent as part of agent network v0.1 (2026-06-09). Please flesh out the Build, Architecture, and Key Patterns sections based on the actual codebase in your next session.

---

## Agent Role

**Role:** Apple platform leaf node

radcap is a leaf node in the Brilliant Mindworks five-repo agent network. It owns the radcap iOS/macOS app and its build/release pipeline.

| | |
|---|---|
| **Hierarchy** | Leaf |
| **Reports to** | Scott Fegette |
| **Visibility** | Public repo — role-filter all cross-repo files |

**Local subagents** (callable by peer agents via `agent-dispatch` label on this repo):

| Subagent | Status | What it does |
|---|---|---|
| `format-release-notes` | stub | Format release notes from commits/changelog |
| `report-pipeline-status` | ✅ live | Ping tracker with current build/pipeline state |

**Incoming routes:** cross-repo requests from bmw-dev-stack  
**Outgoing routes:** infra/backend work → sfegette/bmw-dev-stack; public pages → sfegette/brilliant-web

**Role-filter rule (public repo):** Before writing anything to a cross-repo file, ask: "Would this be fine on a public GitHub page?" If no → route to bmw-dev-stack.

**Canonical reference:** [Roles Manifest](https://github.com/sfegette/bmw-dev-stack/blob/main/docs/agent-roles-manifest.md)

---

## Build & Run

**Project:** `Radcap.xcodeproj` (generated via XcodeGen from `project.yml`)  
**Scheme:** `Radcap`  
**Platform:** macOS 14.0+  
**Bundle ID:** `com.sfegette.radcap`

Regenerate the Xcode project after editing `project.yml`:
```
xcodegen generate
```

**Release builds** use `scripts/release.sh` — never invoke `xcodebuild` directly for releases:
```
./scripts/release.sh --local-test   # Dev-signed build for local verification
./scripts/release.sh --ndd          # Notarize + tag + GitHub Release
./scripts/release.sh --ndd --no-tag # Notarize + GitHub Release, skip tag push
./scripts/release.sh                # Full: NDD + App Store exports
```

No automated test target exists yet. Manual verification is the current QA path.

---

## Architecture

radcap is a macOS menubar app (`.accessory` activation policy — no Dock icon). SwiftUI is used for views; AppKit for window/controller lifecycle.

**Entry point:** `RadcapApp.swift` → `@NSApplicationDelegateAdaptor(AppDelegate.self)`

**Core objects and wiring (all owned by `AppDelegate`):**

| Class | Role |
|---|---|
| `CaptureManager` | AVFoundation session owner — camera, mic, `AVAssetWriter` recording |
| `RecordingCoordinator` | Orchestrates the record flow: countdown → start → HUD → stop |
| `StatusBarController` | Menubar icon + menu; global hotkey toggle entry point |
| `FloatingWindowController` | Camera preview window (shown at rest, hidden during recording) |
| `RecordingHUDController` | Transparent overlay shown during active recording |
| `CountdownWindowController` | 3-2-1 countdown overlay before recording starts |
| `GlobalHotkeyManager` | Carbon-based global hotkey (⌥⌘R) to start/stop from anywhere |
| `AppSettings` | `@AppStorage`-backed user preferences (format, resolution, etc.) |

**Key design decisions:**
- `CaptureManager` calls `prepareForRecording()` + `hudController.prebuild()` before the countdown starts to lock camera focus/exposure and pre-attach the HUD preview layer — prevents frozen frames at recording start (fix for GH #29)
- No SwiftUI `WindowGroup` for the main window; window lifecycle is fully AppKit-managed via `FloatingWindowController`
- Settings UI lives in a sheet on `FloatingWindowController`, not a separate `Settings` scene (`Settings { EmptyView() }` suppresses the default Preferences menu item)

---

## HITL Thresholds

See [roles manifest](https://github.com/sfegette/bmw-dev-stack/blob/main/docs/agent-roles-manifest.md#hitl-thresholds). Key rules: open PR → HITL; merge PR → always HITL; push release/tag → always HITL; file issues / ping tracker → autonomous.
