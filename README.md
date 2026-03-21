<div align="center">

# ⚡ Claude 2× Tracker

**A beautiful desktop widget that tells you exactly when you can go brrrr with Claude.**

*Because manually checking the clock at 5:29 PM is not the vibe.*

<br/>

![macOS Widget](https://img.shields.io/badge/macOS_Widget-13%2B-black?style=flat-square&logo=apple)
![Tray App](https://img.shields.io/badge/System_Tray-Windows_%7C_macOS_%7C_Linux-6366f1?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen?style=flat-square)

<br/>

> 🟢 **2× ACTIVE** — smash those prompts
> 🔴 **BLOCKED** — go touch grass
> ⚫ **WEEKEND** — close the laptop, it's over

</div>

---

## What is this?

Claude Pro has a **2× usage promotion** — your rate limits are doubled during certain hours on weekdays. The problem? You have to mentally track the window yourself, which you will absolutely forget to do.

This project gives you two flavors of the same widget:

| | macOS Widget | System Tray App |
|---|---|---|
| **Lives** | On your desktop wallpaper | In your system tray / menu bar |
| **Covers** | macOS only | Windows + macOS + Linux (all distros) |
| **Feel** | Always visible, sits behind your apps | Click tray icon → popup appears |
| **Status** | ✅ Available now | 🚧 Coming soon |

Both have the exact same UI, the same dark glass look, the same live bar.

---

## What it shows

```
┌──────────────────────────────────────────┐
│ ● 2× ACTIVE              Active for 3h 22m │
│                                          │
│  10:24                                   │
│    │                                     │
│  ████████████████│░░░░░░░░░░│███         │
│  12 AM         5:30 PM  11:30 PM   12 AM │
│                                          │
│  21  22  23  24  25  26  27  28          │
│   ●   ●   ●  [●]  ●   ○   ○   ●         │
└──────────────────────────────────────────┘
  Green = 2× active    Red = blocked    ○ = weekend
  [●] = today          │ = right now
```

- ✅ Whether 2× is active **right now**
- 📊 A live bar showing the full day's window — past portion dimmed, future bright
- ⏱ How much active time you have left (or when it comes back)
- 📅 An 8-day calendar strip to plan ahead

No API calls. No internet. Just math and your system clock.

---

## The Promotion Schedule (default)

| Day | Hours (your configured timezone) | Status |
|---|---|---|
| Mon – Fri | 12:00 AM → 5:30 PM | 🟢 2× ACTIVE |
| Mon – Fri | 5:30 PM → 11:30 PM | 🔴 Blocked |
| Mon – Fri | 11:30 PM → 12:00 AM | 🟢 2× ACTIVE |
| Sat – Sun | All day | ⚫ No promotion |

> **Your schedule might be different.** Edit `config.json` to set your own hours and timezone. See [Configuration](#configuration).

---

## Installation

### macOS Widget

The native widget. Sits on your desktop wallpaper, behind all your apps. Draggable, remembers its position, no Dock icon, no menu bar icon.

**Requirements:** macOS 13 (Ventura) or later · Xcode 15+

```bash
# 1. Clone the repo
git clone https://github.com/Xczer/claude-2x-tracker.git
cd claude-2x-tracker

# 2. Configure your schedule
#    edit config.json (see Configuration section)

# 3. Open in Xcode and run
open macOS/Claude2xWidget/Claude2xWidget.xcodeproj
# Press Cmd+R to build and run
```

The widget appears in the **top-right corner** of your screen. Drag it anywhere you like.

**To auto-launch on login:**
```bash
# Build release version first:
# Xcode → Product → Archive → Distribute App → Copy App
# Then move to /Applications, then:
# System Settings → General → Login Items → add Claude2xWidget.app
```

**If macOS blocks the app ("unidentified developer"):**
```bash
xattr -cr /Applications/Claude2xWidget.app
```
Or: right-click the app → Open → Open anyway.

---

### System Tray App (Windows / macOS / Linux)

> 🚧 **Work in progress.** See [Contributing](#contributing) if you want to help build this.

The system tray version will be a single binary you download and run. No dependencies, no Python, no Node. Just:

1. Download the binary for your OS from [Releases](https://github.com/Xczer/claude-2x-tracker/releases)
2. Drop `config.json` next to it
3. Run it

Click the tray icon → the same glass widget pops up.

**Platform coverage:**

| OS | Tray location | Status |
|---|---|---|
| Windows 10 / 11 | Bottom-right taskbar | 🚧 Planned |
| macOS | Top-right menu bar | 🚧 Planned |
| Ubuntu / Debian | Top-right (GNOME) | 🚧 Planned |
| Fedora | Top-right (GNOME) | 🚧 Planned |
| Arch / Manjaro | KDE, GNOME, XFCE | 🚧 Planned |
| KDE Plasma (any distro) | System tray panel | 🚧 Planned |
| XFCE | Panel tray | 🚧 Planned |
| i3 / Sway | Bar tray block | 🚧 Planned |
| Hyprland | Waybar tray module | 🚧 Planned |

---

## Configuration

One file. Edit before running.

**`config.json`** (at the root of the repo, next to the binary on other platforms):

```json
{
  "timezone": "Asia/Kolkata",
  "active_days": ["monday", "tuesday", "wednesday", "thursday", "friday"],
  "blocked_window": {
    "start": "17:30",
    "end": "23:30"
  },
  "calendar_range": {
    "start": "2026-03-21",
    "end": "2026-03-28"
  }
}
```

### Your timezone

| Location | Timezone ID |
|---|---|
| India (IST) | `Asia/Kolkata` |
| US Eastern | `America/New_York` |
| US Pacific | `America/Los_Angeles` |
| UK | `Europe/London` |
| Germany | `Europe/Berlin` |
| Japan | `Asia/Tokyo` |
| Singapore | `Asia/Singapore` |
| Australia (Sydney) | `Australia/Sydney` |
| Brazil (São Paulo) | `America/Sao_Paulo` |
| UAE / Gulf | `Asia/Dubai` |

Full list: [iana.org/time-zones](https://www.iana.org/time-zones)

> **macOS note:** The macOS widget currently reads the config baked into `Config.swift`. Reading `config.json` at runtime is a planned improvement.

---

## How the status logic works

```
IF today is Saturday or Sunday
  → ⚫ WEEKEND

ELSE IF current time (in your timezone) is between blocked.start and blocked.end
  → 🔴 BLOCKED

ELSE
  → 🟢 2× ACTIVE
```

That's the entire algorithm. 15 lines of code. Everything else is just making it look good.

---

## Project Structure

```
claude-2x-tracker/
│
├── config.json                 ← Your schedule + timezone (edit this)
├── README.md                   ← You are here
├── Learn.md                    ← Deep dive: how the macOS widget was built from scratch
│
├── macOS/
│   └── Claude2xWidget/         ← Xcode project (Swift + SwiftUI + AppKit)
│       └── Claude2xWidget/
│           ├── Claude2xWidgetApp.swift    ← App entry point
│           ├── AppDelegate.swift          ← Window creation
│           ├── FloatingWindow.swift       ← Desktop window (drag, snap, level)
│           ├── StatusEngine.swift         ← All time logic (IST, 2x rules)
│           ├── ContentView.swift          ← The UI (3 rows: status, bar, calendar)
│           └── Views/
│               └── GlassContainer.swift  ← Background, glass cards, color helpers
│
└── tray/                       ← 🚧 System tray app (coming soon)
    ├── src/                    ← Tauri (Rust + HTML/CSS)
    └── ...
```

---

## Contributing

PRs are very welcome. Most useful things right now:

### 🔥 Build the system tray app

This is the big one. The plan is [Tauri](https://tauri.app) (Rust + HTML/CSS) because:
- Ships as a native binary (~10MB) — not a website, not an Electron app
- Single codebase runs on Windows, macOS, and Linux
- The glass dark UI replicates perfectly in HTML/CSS
- First-class system tray support built in

If you know Rust or are willing to learn, this is the highest-impact contribution.

### 🌱 Good first issues

- Add your timezone to the examples table
- Make the macOS widget read `config.json` at runtime instead of `Config.swift`
- Improve the `calendar_range` to auto-calculate the current week instead of hardcoding dates
- Add a screenshot of the widget running on your machine to the README
- Report bugs, suggest ideas

### How the macOS widget is architected

Read [`Learn.md`](./Learn.md) — it's a complete walkthrough of every file, every decision, and every bug that was hit during development. Written for someone completely new to Swift.

---

## FAQ

**Does this use the Claude API?**
No. Pure local time math. No API key needed, no internet connection, no cost.

**Why IST by default?**
That's where this project started. Set `timezone` in `config.json` to yours.

**My 2× window is different from the default.**
Edit `blocked_window.start` and `blocked_window.end` in `config.json`.

**Can I use this for something other than Claude?**
Absolutely. It's just a configurable "am I inside or outside a time window" tracker. Works for anything.

**Will it drain my battery?**
macOS widget: ~0.1% CPU. One timer fires per second, the glow animation runs at 60fps. Negligible.

**The widget is behind my wallpaper and I can't see it.**
This shouldn't happen but if it does: relaunch the app. It will reappear at the top-right of your screen.

---

## License

MIT. Take it, fork it, build on it.

If this saved you from missing a 2× window, a ⭐ is appreciated.

---

<div align="center">

**macOS widget** · **System tray coming soon**

*Made because staring at the clock is not a productivity strategy.*

</div>
