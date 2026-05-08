# Accessibility Review — Radcap

**Requested by:** Scott Fegette
**Date:** 2026-05-08

---

## Review 1 — Codex

### Critical (blocks compliance)

1. **Missing accessible names on icon-only controls** (`ContentView.swift` — `controlsSection`)
   - Buttons rely on icon glyphs and `.help` only; `.accessibilityLabel` is not set.
   - WCAG 2.1/2.2 1.1.1, 4.1.2; EN 301 549 9.1.1.1, 9.4.1.2
   - Impact: Screen reader users may hear only "button" with no indication of purpose.

2. **Hidden picker labels without accessibility labels** (`ContentView.swift` — `cameraPicker`, `microphonePicker`, `recordingMode` picker, `cropMode` picker)
   - `.labelsHidden()` removes visible labels with no compensating `.accessibilityLabel`.
   - WCAG 3.3.2, 4.1.2; EN 301 549 9.3.3.2
   - Impact: VoiceOver users cannot identify the control's purpose.

3. **Reduce Motion not respected in animated overlays**
   - Files: `CountdownOverlayView.swift` (animateIn/tick), `SpeedChangeOverlayController.swift` (popIn), `TeleprompterPillView` (scrolling).
   - Spring/opacity animations do not branch on `accessibilityReduceMotion`. WCAG 2.3.3; Apple HIG.
   - Impact: Users with motion sensitivity may experience discomfort.

4. **Reduce Transparency not respected where materials are used**
   - Files: `ContentView.swift` (`.ultraThinMaterial`, `.regularMaterial`), `TeleprompterPillView.swift` (Capsule with material).
   - No fallback for `accessibilityReduceTransparency`. WCAG 1.4.3/1.4.11.
   - Impact: Low-contrast backgrounds can hinder readability.

### Major (significant barrier to users)

5. **No VoiceOver announcements for state changes**
   - Files: `ContentView.swift` (start/stop recording), `SpeedChangeOverlayController.swift` (speed changed), `RecordingHUDController.swift` (HUD shown/hidden).
   - No `AccessibilityNotification` or `NSAccessibility.post` for significant transitions. WCAG 4.1.3; EN 301 549 9.4.1.3.

6. **`.help()` tooltips are not substitutes for accessible names**
   - Files: icon-only buttons in `ContentView.swift`; sliders in `SettingsView.swift`.
   - `.help` does not reliably reach VoiceOver. WCAG 1.3.1, 4.1.2.

7. **`EditableValueLabel` TextField lacks an associated label**
   - File: `SettingsView.swift`
   - Inline TextField has an empty placeholder (`TextField("", ...)`); VoiceOver cannot identify its purpose. WCAG 1.3.1, 3.3.2.

### Minor (improvements recommended)

8. **Keyboard shortcut parity** — Add `Cmd+,` for Settings; add shortcut for teleprompter toggle.
9. **Focus restoration after Settings sheet** — Focus should return to the Record button after `SettingsView` is dismissed.
10. **Contrast on translucent backgrounds** — Recording badge and teleprompter text on material backgrounds may not meet WCAG AA (4.5:1).
11. **Internationalization** — User-facing and accessibility strings are hard-coded; not localizable.

### Passed
- Keyboard navigation through standard SwiftUI controls (pickers, sliders, buttons) appears supported by default.
- `NSAlert` for microphone permissions provides clear actions and is read by VoiceOver.
- Teleprompter font size and visible lines are user-configurable, aiding low-vision users.

### Recommended fixes (prioritised)

1. Add `.accessibilityLabel` to icon-only buttons and `.labelsHidden()` pickers (`ContentView.swift`):
   ```swift
   // Teleprompter toggle
   .accessibilityLabel(teleprompterScrolling ? "Pause teleprompter" : "Start teleprompter scroll")
   // Settings button
   .accessibilityLabel("Open Settings")
   // Pickers
   cameraPicker.accessibilityLabel("Camera")
   microphonePicker.accessibilityLabel("Microphone")
   Picker(…).accessibilityLabel("Recording Mode")
   Picker(…).accessibilityLabel("Crop Mode")
   ```

2. Add `@Environment(\.accessibilityReduceMotion)` guard to all `withAnimation` calls in `CountdownOverlayView.swift` and `SpeedChangeOverlayController.swift`.

3. Add `@Environment(\.accessibilityReduceTransparency)` fallback in `ContentView.swift` and `TeleprompterPillView.swift` — substitute an opaque fill when enabled.

4. Post `AccessibilityNotification.announcement` on recording start/stop from `RecordingCoordinator` or `CaptureManager`.

5. Add `.accessibilityLabel` to each `EditableValueLabel` instance, derived from the enclosing `LabeledContent` label string.

6. Add `Cmd+,` keyboard shortcut to the Settings button.

---

## Review 2 — Claude (second opinion)

*Read the full source after Codex's review. Confirming all four Codex criticals and adding findings below.*

### Confirmed

All four Codex criticals are verified against the source. Items 1 and 2 (missing labels) are the highest-value quick fixes — a handful of modifier lines each.

### Additional findings

**A. Close button is completely unlabelled** (`ContentView.swift` lines 38–53) — **Critical**
The window chrome close button is a bare red `Circle`. No `.help()`, no `.accessibilityLabel`, no `.accessibilityHint`. VoiceOver announces it as "button" with zero context. Worse than the icon buttons Codex flagged — those at least have recognisable SF Symbol names that VoiceOver can fall back on. Fix:
```swift
.accessibilityLabel("Close Radcap")
.help("Close")
```

**B. `ScrollingTextNSView` is invisible to the accessibility tree** (`TeleprompterPillView.swift`) — **Critical**
The teleprompter text is drawn via `NSAttributedString.draw()` inside a raw `NSView.draw(_:)` override. Custom AppKit drawing bypasses the accessibility tree entirely — VoiceOver cannot read the script content at all. The view needs either `accessibilityLabel()` returning the full script text, or `accessibilityRole(.staticText)` + `accessibilityValue(text)`. This is a meaningful barrier: a user relying on VoiceOver has no way to verify or read the script they're about to present.

**C. Piecewise speed slider reports wrong accessible value** (`SettingsView.swift` lines 79–86) — **Major**
The `Slider(value: speedSliderBinding, in: 0...1)` internally maps 0–1 to 0.25–2.0x. VoiceOver will announce the slider's position as a percentage of 0–1 (e.g., "50%") when the meaningful value is "1.0x". Add:
```swift
Slider(value: speedSliderBinding, in: 0...1)
    .accessibilityValue(String(format: "%.2fx", settings.teleprompterSpeed))
```

**D. Recording badge live timer should not be announced every second** (`ContentView.swift` lines 94–107) — **Major**
The `durationString` in `recordingBadge` updates every second. If VoiceOver reads live regions or the user navigates to it, they'd get spammed with timer updates. The badge should be marked `.accessibilityHidden(true)` (the recording state change announcement from item 4 above handles the important notification) or given `.accessibilitySortPriority` below interactive controls so VoiceOver doesn't land on it in normal traversal.

**E. `NonKeyPanel` intentionally excludes the HUD from keyboard interaction** (`RecordingHUDController.swift` lines 119–122) — **Minor / intentional**
`canBecomeKey: false` means VoiceOver cursor cannot move into the teleprompter pill panel during recording. This is likely intentional (don't steal focus during a take), but it should be documented as a deliberate tradeoff. If accessibility is a priority path, a VoiceOver-specific mode that does allow key focus could be considered.

**F. `CountdownOverlayView` is silent to VoiceOver** (`CountdownOverlayView.swift`) — **Major**
The countdown (3, 2, 1…) is displayed visually and with audio (Tink/Pop), but no `NSAccessibility.post(notification: .announcementRequested, element: ..., userInfo: ...)` is posted for each count change. A VoiceOver user has no warning that recording is starting. Should post an announcement on each `current` change and on `isDone`.

### Summary of new items by severity

| # | Finding | Severity | File | Lines |
|---|---------|----------|------|-------|
| A | Close button has no a11y label or tooltip | Critical | ContentView.swift | 38–53 |
| B | ScrollingTextNSView invisible to accessibility tree | Critical | TeleprompterPillView.swift | 14–80 |
| C | Speed slider reports wrong accessible value (0–1 vs 0.25–2.0x) | Major | SettingsView.swift | 79–86 |
| D | Recording badge timer announced every second | Major | ContentView.swift | 94–107 |
| E | NonKeyPanel excludes HUD from VoiceOver keyboard nav (intentional?) | Minor | RecordingHUDController.swift | 119–122 |
| F | Countdown changes not announced to VoiceOver | Major | CountdownOverlayView.swift | 48–73 |

### Combined priority order (both reviews)

1. Add `.accessibilityLabel` to all icon buttons and `.labelsHidden()` pickers (Codex #1, #2; Claude #A) — quick wins, high compliance value
2. Make `ScrollingTextNSView` readable by VoiceOver (Claude #B) — core content access
3. Announce countdown to VoiceOver (Claude #F) — safety/usability for recording flow
4. Announce recording state changes (Codex #5) — paired with #3
5. Fix speed slider accessible value (Claude #C)
6. Guard all animations on `accessibilityReduceMotion` (Codex #3)
7. Guard all materials on `accessibilityReduceTransparency` (Codex #4)
8. Fix `EditableValueLabel` label association (Codex #7 / Claude #C)
9. Hide/suppress recording badge timer from VoiceOver (Claude #D)
10. Add `Cmd+,` shortcut for Settings (Codex #8)
