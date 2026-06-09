<img src="docs/radcap-wordmark.png" alt="radcap" width="312" />

A macOS menubar app for recording webcam video and audio with a built-in voice-activated teleprompter.

> **Requires macOS 26.0 or later.**

---

## Download

Grab the latest build from the [Releases](https://github.com/sfegette/radcap/releases) page.

1. Download `Radcap-<version>.dmg` from the latest release.
2. Open the DMG and drag **Radcap.app** to your `/Applications` folder.
3. Double-click to launch — the Radcap icon will appear in the menu bar.

**First launch:** macOS will ask for Camera and Microphone access. Both are required. If a permission prompt doesn't appear, open **System Settings → Privacy & Security** and grant access there.

> Radcap is notarized and Developer ID-signed. macOS will verify it automatically on first launch — no Gatekeeper workarounds needed.

---

## What's New in 1.0.3

- **Video format picker** — Choose between MOV and MP4 in **Settings → Output**. Both use H.264; MP4 improves compatibility with YouTube, Instagram, LinkedIn, and non-Apple players. MOV remains the default.

## What's New in 1.0.2

- **Clean recording start** — Fixed a ~1.5-second frozen-frame glitch at the beginning of every recording. The teleprompter HUD preview layer now initializes during the countdown, not at the moment recording begins, so the first frame is sharp.
- **Menubar recording indicator** — The menu bar icon switches to a red recording dot (⏺) while recording is active. Click it once to stop; no menu required.
- **Smarter recording start** — Duplicate Record clicks during the countdown are now ignored. If the writer can't create the output file for any reason, an alert explains what went wrong instead of failing silently.
- **Capture performance** — Cropped recordings reuse the pixel buffer pool instead of allocating a new buffer every frame. Voice-activity detection no longer runs when Radcap is idle.
- **Accessibility** — Reduce Transparency and Reduce Motion settings are now respected in the teleprompter HUD.

---

## Features

- **Menubar recorder** — lives quietly in the menu bar until you need it; no dock icon
- **Liquid Glass setup window** — borderless macOS 26 glass panel for camera and script setup
- **3-2-1 countdown** — full-screen overlay with audio ticks before recording starts so you can compose yourself
- **Voice-activated teleprompter** — script scrolls while it detects your voice, pauses when you go silent, resumes when you speak; halts automatically when the script ends
- **Teleprompter formatting** — bold/italic toggles, left/center alignment, and a font size slider — all adjustable in the formatting pop-up beneath the prompter; live preview reflects the recording HUD exactly
- **Camera preview** — semi-transparent preview beneath the teleprompter; opacity adjustable via scroll wheel or Settings
- **Global hotkey** — ⌘⌥R starts and stops recording from any app
- **Live speed control** — ↑/↓ arrows tune teleprompter speed in 5 % steps during recording, with a full-screen indicator
- **Live device refresh** — camera and microphone lists update instantly when you plug in or remove a device, even while the picker is open; the selection falls back gracefully if a device disappears mid-session
- **Camera lifecycle** — camera only activates when the setup window is open or a recording is live
- **Multiple output formats** — `.mov` or `.mp4` for video (H.264, selectable in Settings); `.m4a` (AAC) or `.wav` (lossless) for audio-only recordings
- **Crop modes** — Full Frame, Square (1:1), or Vertical (9:16)
- **Accessibility** — full VoiceOver support, keyboard navigation, reduce-motion and reduce-transparency fallbacks

---

## Usage

1. Click the menu bar icon to open the setup window.
2. Choose your camera, microphone, recording mode, and crop mode.
3. Use the **edit** button beneath the prompter to paste or edit your script, and the formatting pop-up to set text size, bold/italic, and alignment.
4. Open **Settings** (⚙) to choose your audio format and adjust scroll speed, scrolling delay, and preview opacity.
5. Click **Record** or press **⌘⌥R**. A 3-second countdown appears, then the setup window hides.
6. The teleprompter pill and camera preview appear at the top of your screen. The script starts scrolling the moment you speak, and stops automatically when it reaches the end.
7. Press **⌘⌥R** again, click the red recording dot in the menu bar, or choose **■ Stop Recording** from the right-click menu to stop. The recording saves automatically.

## Keyboard Shortcuts

| Shortcut | When | Action |
|---|---|---|
| ⌘⌥R | Any time | Start / stop recording |
| ↑ | During recording | Teleprompter speed +5 % |
| ↓ | During recording | Teleprompter speed −5 % |

## Output

Recordings are saved to the Desktop by default (`Radcap_YYYY-MM-DD_HHmmss.mov`). The output directory can be changed in Settings.

---

## FAQ

**Where are my recordings saved?**
To the Desktop by default, named `Radcap_YYYY-MM-DD_HHmmss.mov`. You can change the output folder in **Settings → Output Directory**.

**macOS says "Radcap can't be opened because it's from an unidentified developer."**
Radcap is notarized and Developer ID-signed, so this shouldn't happen. If it does, right-click the app and choose **Open** — macOS will remember your choice going forward.

**Camera or microphone access was denied. How do I fix it?**
Open **System Settings → Privacy & Security**, find Camera and Microphone, and make sure Radcap is enabled. You may need to quit and relaunch the app after granting access.

**The teleprompter isn't scrolling.**
The teleprompter is voice-activated — it only scrolls while it detects audio. Check that the correct microphone is selected in the setup window and that macOS microphone access is granted. If speech detection feels off, try adjusting **Pre-scroll Pause** in **Settings → Teleprompter**.

**I plugged in a new microphone (or camera) but it isn't showing up.**
Radcap's device lists refresh live — plug in or unplug a device and the picker updates immediately, even while it's open. If you're not seeing it, make sure macOS itself recognizes the device (check Audio MIDI Setup or System Information) and that Radcap has microphone/camera permission in System Settings → Privacy & Security.

**Can I use Radcap with a virtual camera (OBS, Camo, etc.)?**
Yes — any camera that appears in macOS's camera picker will show up in Radcap's device list. Virtual cameras appear and disappear live alongside physical ones.

**What's the difference between the output formats?**
For video, choose **MOV** or **MP4** in **Settings → Video Format** — both use H.264; MP4 is better for social platforms and non-Apple players. For audio-only recordings, choose **M4A** (AAC) or **WAV** (lossless) in **Settings → Audio Format**.

**Is Radcap on the Mac App Store?**
Not yet. Download from the [Releases](https://github.com/sfegette/radcap/releases) page.

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
