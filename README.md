<img src="docs/radcap-wordmark.png" alt="radcap" width="312" />

A macOS menubar app for recording webcam video and audio with a built-in voice-activated teleprompter.

> **Requires macOS 26.0 or later.**

---

## Download

Grab the latest build from the [Releases](https://github.com/sfegette/radcap/releases) page.

1. Download `Radcap-<version>.dmg` from the latest release.
2. Open the DMG and drag **Radcap.app** to your `/Applications` folder.
3. Double-click to launch — a camera icon will appear in the menu bar.

**First launch:** macOS will ask for Camera and Microphone access. Both are required. If a permission prompt doesn't appear, open **System Settings → Privacy & Security** and grant access there.

> Radcap is notarized and Developer ID-signed. macOS will verify it automatically on first launch — no Gatekeeper workarounds needed.

---

## Features

- **Menubar recorder** — lives quietly in the menu bar until you need it
- **Liquid Glass setup window** — borderless macOS 26 glass panel for camera and script setup
- **3-2-1 countdown** — full-screen overlay before recording starts so you can compose yourself
- **Voice-activated teleprompter** — script scrolls while it detects your voice, pauses when you're silent, resumes when you speak
- **Camera preview** — semi-transparent preview beneath the teleprompter; opacity adjustable via scroll wheel or the Settings slider
- **Global hotkey** — ⌘⌥R starts and stops recording from any app
- **Live speed control** — ↑/↓ arrows tune teleprompter speed in 5 % steps during recording, with a full-screen indicator
- **Camera lifecycle** — camera only activates when the setup window is open or a recording is live
- **Multiple output formats** — `.mov` (video + audio), `.m4a`, or `.wav` (audio only)
- **Crop modes** — Full Frame, Square (1:1), or Vertical (9:16)

---

## Usage

1. Click the menu bar icon to open the setup window.
2. Choose your camera, microphone, crop mode, and output format.
3. Open **Settings** (⚙) to paste your teleprompter script and adjust font size, scroll speed, and preview opacity.
4. Click **Record** or press **⌘⌥R**. A 3-second countdown appears, then the setup window hides.
5. The teleprompter pill and camera preview appear at the top of your screen. The script starts scrolling the moment you speak.
6. Press **⌘⌥R** again, or choose **■ Stop Recording** from the menu bar icon, to stop. The recording saves automatically.

## Keyboard Shortcuts

| Shortcut | When | Action |
|---|---|---|
| ⌘⌥R | Any time | Start / stop recording |
| ↑ | During recording | Teleprompter speed +5 % |
| ↓ | During recording | Teleprompter speed −5 % |

## Output

Recordings are saved to the Desktop by default (`Radcap_YYYY-MM-DD_HHmmss.mov`). The output directory can be changed in Settings.

---

## Building from Source

**Requirements:** macOS 26 SDK, Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen), Apple Developer account

```bash
brew install xcodegen
git clone https://github.com/sfegette/radcap.git
cd radcap
xcodegen
open Radcap.xcodeproj
```

Select the **Radcap** scheme, choose your Mac as the run destination, and press ⌘R.

If the build fails with a signing error, open **Signing & Capabilities** in the Radcap target and set your Development Team, or add `DEVELOPMENT_TEAM: YOUR_TEAM_ID` under `settings:` in `project.yml` and re-run `xcodegen`.

---

## Reporting Bugs

Found something broken? Please [open an issue](https://github.com/sfegette/radcap/issues/new) and include:

- macOS version
- Steps to reproduce
- What you expected vs. what happened
- Any relevant output from Console.app (filter by "Radcap")

---

## License

MIT
