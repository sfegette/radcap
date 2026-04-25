# Radcap

A macOS menubar app for recording webcam video and audio with a built-in voice-activated teleprompter.

## Features

- **Menubar recorder** — lives quietly in the menu bar until you need it
- **Liquid Glass setup window** — borderless macOS 26 glass panel for camera and script setup
- **3-2-1 countdown** — full-screen overlay before recording starts so you can compose yourself
- **Voice-activated teleprompter** — script scrolls automatically while it detects your voice, pauses when you're silent, resumes when you speak again
- **Camera preview** — semi-transparent video preview beneath the teleprompter during recording; opacity adjustable via scroll wheel or the Settings slider
- **Global hotkey** — ⌘⌥R starts and stops recording from any app
- **Live speed control** — ↑/↓ arrows adjust teleprompter scroll speed in 5 % steps during recording, with a full-screen speed indicator
- **Camera session lifecycle** — camera only activates when the setup window is open or a recording is live; no background camera drain
- **Multiple output formats** — `.mov` (video + audio), `.m4a`, or `.wav` (audio only)
- **Crop modes** — Full Frame, Square (1:1), or Vertical (9:16)

## Requirements

- macOS 26.0 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- A valid Apple Developer account (for signing — required to access camera and microphone)

## Building

```bash
brew install xcodegen
git clone https://github.com/sfegette/radcap.git
cd radcap
xcodegen
open Radcap.xcodeproj
```

Select the **Radcap** scheme, choose your Mac as the run destination, and press ⌘R. On first launch macOS will prompt for camera and microphone access — both are required.

Set your Development Team in Xcode's Signing & Capabilities panel (or add `DEVELOPMENT_TEAM` to `project.yml`) if the build fails with a signing error.

## Usage

1. Launch Radcap — a camera icon appears in the menu bar.
2. Click the icon to open the setup window.
3. Choose your camera, microphone, crop mode, and output format.
4. Open **Settings** (⚙) to paste in your teleprompter script and adjust font size, scroll speed, and recording preview opacity.
5. Click **Record** or press **⌘⌥R**. A 3-second countdown appears, then the setup window hides.
6. The teleprompter pill and camera preview appear at the top of your screen. The script starts scrolling the moment you speak.
7. Press **⌘⌥R** again, or choose **■ Stop Recording** from the menu bar icon, to stop. The recording is saved and the setup window reappears.

## Keyboard Shortcuts

| Shortcut | When | Action |
|---|---|---|
| ⌘⌥R | Any time | Start / stop recording |
| ↑ | During recording | Teleprompter speed +5 % |
| ↓ | During recording | Teleprompter speed −5 % |

## Output

Recordings are saved to the Desktop by default (`Radcap_YYYY-MM-DD_HHmmss.mov`). The output directory can be changed in Settings.

## License

MIT
