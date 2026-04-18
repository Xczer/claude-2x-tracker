# Learn.md — Claude 2× Widget: A Swift Beginner's Complete Guide

This document walks through the entire `Claude2xWidget` macOS app from scratch.
You built this project, so every decision here reflects real code you can open and read.

---

## Table of Contents

1. [What Is This App?](#1-what-is-this-app)
2. [The Big Picture — How a macOS App Starts](#2-the-big-picture--how-a-macos-app-starts)
3. [File-by-File Deep Dive](#3-file-by-file-deep-dive)
   - [Claude2xWidgetApp.swift — The Entry Point](#31-claude2xwidgetappswift--the-entry-point)
   - [AppDelegate.swift — Lifecycle Control](#32-appdelegateswift--lifecycle-control)
   - [FloatingWindow.swift — The Custom Window](#33-floatingwindowswift--the-custom-window)
   - [StatusEngine.swift — The Brain](#34-statusengineswift--the-brain)
   - [ContentView.swift — The Main Screen](#35-contentviewswift--the-main-screen)
   - [GlassContainer.swift — Visual Magic](#36-glasscontainerswift--visual-magic)
   - [ClockView.swift — The Live Clock](#37-clockviewswift--the-live-clock)
   - [DailyWindowBar.swift — The 24-Hour Bar](#38-dailywindowbarswift--the-24-hour-bar)
   - [CalendarStrip.swift — The 8-Day Calendar](#39-calendarstripswift--the-8-day-calendar)
   - [StatusCard.swift — The Orb & Badge](#310-statuscardswift--the-orb--badge)
   - [LayoutVariants.swift — Design Exploration](#311-layoutvariantsswift--design-exploration)
4. [Key Swift Concepts Explained](#4-key-swift-concepts-explained)
5. [Key Libraries & Frameworks Explained](#5-key-libraries--frameworks-explained)
6. [How State Flows Through the App](#6-how-state-flows-through-the-app)
7. [Animations: How They Work](#7-animations-how-they-work)
8. [The Timezone Problem](#8-the-timezone-problem)
9. [Design Decisions — Why Each Thing Was Done](#9-design-decisions--why-each-thing-was-done)
10. [Architecture Summary](#10-architecture-summary)

---

## 1. What Is This App?

Claude 2× Widget is a floating macOS desktop widget that shows you when Claude's "2× promotion"
(faster/discounted usage) is active. The promotion follows a fixed schedule based on
Eastern Time (ET): it is **blocked** (unavailable) during 8:00 AM – 2:00 PM ET on weekdays.
Outside that window — evenings, nights, weekends — it is **active**.

The widget:
- Floats on your desktop below all app windows
- Shows a colored status (green = active, red = blocked, gray = weekend)
- Shows a 24-hour timeline bar with a "now" cursor
- Shows an 8-day mini calendar
- Counts down to the next status change
- Remembers its position between launches

---

## 2. The Big Picture — How a macOS App Starts

When you double-click the app, macOS follows this exact sequence:

```
1. macOS reads Info.plist → finds the app bundle configuration
2. The @main entry point is found → Claude2xWidgetApp.swift
3. SwiftUI calls the App's body → which installs AppDelegate
4. AppDelegate.applicationDidFinishLaunching() runs
5. AppDelegate creates a FloatingWindow
6. FloatingWindow creates a SwiftUI ContentView inside an NSWindow
7. ContentView creates a StatusEngine (the data brain)
8. StatusEngine starts a 1-second timer
9. The widget appears on screen
```

Think of it like a factory startup sequence. `@main` is the power switch, `AppDelegate` is
the factory manager, `FloatingWindow` is the physical building, `ContentView` is the
assembly line, and `StatusEngine` is the inventory/logic computer that everything reads from.

---

## 3. File-by-File Deep Dive

### 3.1 Claude2xWidgetApp.swift — The Entry Point

```swift
@main
struct Claude2xWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings { EmptyView() }
    }
}
```

**What it does:** This is the absolute first code that runs. Every Swift app needs exactly
one struct marked `@main`. On macOS, SwiftUI apps inherit from the `App` protocol.

**Why `@NSApplicationDelegateAdaptor`?**
SwiftUI normally manages windows automatically. But you needed a *custom floating window*
that sits below other apps, has no title bar, and remembers its position. SwiftUI's default
window system cannot do those things. So you "inject" an `AppDelegate` (the traditional
AppKit/Objective-C style of controlling an app) back into SwiftUI using this adaptor.
Think of it as telling SwiftUI: "I'll handle windows myself, thank you."

**Why `Settings { EmptyView() }`?**
SwiftUI requires at least one `Scene` in the `body`. Since there is no real settings window,
`EmptyView()` is used as a placeholder — it satisfies the compiler without showing anything.

**Framework used:** `SwiftUI` — Apple's declarative UI framework (introduced 2019).

---

### 3.2 AppDelegate.swift — Lifecycle Control

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: FloatingWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        window = FloatingWindow()
        window?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
```

**What it does:** This class is the traditional macOS app lifecycle manager. It creates the
window as soon as the app launches.

**Why `.accessory` activation policy?**
macOS has three policies for apps:
- `.regular` — shows in Dock and menu bar (like Xcode, Safari)
- `.accessory` — hides from Dock, shows no menu bar entry (like some utilities)
- `.prohibited` — never appears at all

You chose `.accessory` so the widget has no Dock icon and no menu bar app icon — it just
floats invisibly on the desktop without cluttering your taskbar.

**Why `applicationShouldTerminateAfterLastWindowClosed` returns `false`?**
By default on macOS, closing the last window quits the app. Since the widget *is* the app,
you never want this behavior. Returning `false` keeps the app alive even if the window is
somehow hidden.

**Framework used:** `AppKit` — Apple's older (pre-SwiftUI) UI framework. It gives low-level
control over windows, menus, and the application object (`NSApp`).

---

### 3.3 FloatingWindow.swift — The Custom Window

This is the most complex file for setup. It builds the actual window that appears on screen.

#### What NSWindow Is

`NSWindow` is AppKit's class representing a system window. By default it has a title bar,
close/minimize/zoom buttons, and an opaque white background. You override all of this.

#### The Core Window Setup

```swift
init() {
    super.init(
        contentRect: NSRect(x: 0, y: 0, width: 340, height: 148),
        styleMask: [.borderless],          // no title bar, no buttons
        backing: .buffered,
        defer: false
    )
    self.isOpaque = false                  // allow transparency
    self.backgroundColor = .clear          // window itself is invisible
    self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.normalWindow)) - 1)
    self.isMovableByWindowBackground = true
}
```

**Why `styleMask: [.borderless]`?**
This removes the standard macOS window chrome (title bar, traffic light buttons). Without
this, your widget would look like a normal app window.

**Why `isOpaque = false` and `backgroundColor = .clear`?**
Windows on macOS are opaque by default for performance. Setting these to false/clear tells
the compositor: "this window has transparent pixels — show whatever is behind them."

**Why `level = normalWindow - 1`?**
Window levels control which windows appear on top. The system has many levels:
- Desktop background: lowest
- Normal windows (Finder, Safari): `kCGNormalWindowLevel` (value ≈ 0)
- Floating panels: higher
- Status bar: higher still
- Dock: very high
- Screensaver: highest

By setting the level to `normalWindow - 1`, the widget sits *above* the desktop wallpaper
but *below* every normal app window. This is the classic "desktop widget" behavior — it
never covers your work.

#### Position Memory

```swift
func savePosition() {
    UserDefaults.standard.set(NSStringFromRect(frame), forKey: "claude2x.window.frame")
}

func restorePosition() {
    if let saved = UserDefaults.standard.string(forKey: "claude2x.window.frame") {
        setFrame(NSRectFromString(saved), display: true)
    }
}
```

**What is UserDefaults?**
`UserDefaults` is macOS/iOS's built-in key-value store for small pieces of data. It
persists between app launches (stored in `~/Library/Preferences/`). Here it saves the
window's position as a string like `"{{100, 200}, {340, 148}}"` and restores it on relaunch.
This is why the widget remembers where you dragged it.

#### Drag & Snap

The window has two drag systems:
1. `isMovableByWindowBackground = true` — AppKit's built-in drag (works most of the time)
2. Manual `NSEvent` tracking as a fallback — overrides `mouseDragged` to manually
   reposition the window and snap it to screen edges within 14pt

**Framework used:** `AppKit` (NSWindow, NSEvent, UserDefaults).

---

### 3.4 StatusEngine.swift — The Brain

This is the most important file. Everything the UI shows comes from here.

#### ObservableObject Pattern

```swift
@MainActor
class StatusEngine: ObservableObject {
    @Published var currentStatus: PromotionStatus = .active
    @Published var nextWindowText: String = ""
    @Published var currentTime: Date = Date()
    // ...
}
```

**What is `ObservableObject`?**
It is a protocol from the `Combine` framework. When a class conforms to it, SwiftUI can
"watch" it for changes. Any `@Published` property that changes causes every SwiftUI view
observing this object to automatically re-render. This is the core of SwiftUI's reactive
system — you change data, the UI updates itself.

Think of it like a spreadsheet: `StatusEngine` is the spreadsheet, `@Published` properties
are the cells, and SwiftUI views are formulas that auto-update when cells change.

**What is `@MainActor`?**
macOS apps can run code on multiple threads simultaneously (concurrency). UI updates must
happen on the "main thread" only — doing them on a background thread causes crashes.
`@MainActor` is a compiler guarantee that says: "all code in this class runs on the main
thread." It is Swift's modern way of solving thread-safety for UI-related objects.

#### Status Enum

```swift
enum PromotionStatus {
    case active    // 2× is available right now
    case blocked   // peak hours — 2× is paused
    case weekend   // Saturday or Sunday — no 2×
}
```

**What is an enum?**
An enum (short for enumeration) is a Swift type that can be exactly one of a fixed list of
values. Here it models the three possible states of the Claude 2× promotion. Enums make
code safe because the compiler forces you to handle every case — you can never forget
the `weekend` state.

#### The Timer

```swift
private func startTimer() {
    Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
        self?.currentTime = Date()
        self?.updateAll()
    }
}
```

This creates a repeating 1-second timer. Every second: grab the current time, recompute
all `@Published` properties, SwiftUI sees the changes, and re-renders the UI. This is how
the countdown text ticks down and the "now" cursor on the bar moves in real-time.

**Why `[weak self]`?**
This is a memory management pattern. Without `weak self`, the timer closure would hold a
strong reference to the `StatusEngine` object, preventing it from ever being deallocated
(a memory leak). `weak self` makes the reference optional — if the object is gone, the
closure skips gracefully.

#### Timezone Math

```swift
let etZone = TimeZone(identifier: "America/New_York")!
let calendar = Calendar.current

// Peak hours: 8:00 AM – 2:00 PM Eastern Time
let peakStart = DateComponents(hour: 8, minute: 0)
let peakEnd   = DateComponents(hour: 14, minute: 0)
```

The promotion schedule is defined in ET. To show correct times in your local timezone
(e.g., IST which is UTC+5:30), the engine converts the ET window to local time:
- 8:00 AM ET = 6:30 PM IST
- 2:00 PM ET = 11:30 PM IST

`Foundation`'s `Calendar` and `TimeZone` APIs handle Daylight Saving Time automatically —
when the US clocks spring forward or fall back, the local display times shift accordingly
without any extra code.

#### Remote Config

```swift
func fetchScheduleConfig() {
    let url = URL(string: "https://raw.githubusercontent.com/.../schedule.json")!
    URLSession.shared.dataTask(with: url) { data, _, _ in
        // parse JSON → update peakStart/peakEnd
    }.resume()
}
```

Every 6 hours the app downloads a small JSON file from GitHub that can override the default
peak hours. This means if Anthropic ever changes the 2× schedule, you can update the JSON
file and every running widget will pick up the change within 6 hours — no new app release
needed.

**Frameworks used:** `Foundation` (Timer, Date, Calendar, TimeZone, URLSession, UserDefaults),
`Combine` (ObservableObject, @Published).

---

### 3.5 ContentView.swift — The Main Screen

This is the UI layout that users actually see: "Layout 4 — Timeline Hero."

```
┌─────────────────────────────────────────────────┐
│ ● ACTIVE    next window in 3h 42m               │  ← StatusRow
│ ████████████████░░░░░░░░│░░░░░░░░░░░░░░░░░░░░░ │  ← TimelineBar
│ THU  FRI  SAT  SUN  MON  TUE  WED  THU          │  ← CalendarDotsRow
└─────────────────────────────────────────────────┘
```

#### SwiftUI View Composition

```swift
struct ContentView: View {
    @StateObject private var engine = StatusEngine()

    var body: some View {
        VStack(spacing: 0) {
            StatusRow(engine: engine)
            TimelineBar(engine: engine)
            CalendarDotsRow(engine: engine)
        }
    }
}
```

**What is `@StateObject`?**
When a View creates an `ObservableObject` for the first time, it uses `@StateObject`. This
tells SwiftUI: "I own this object — keep it alive for my entire lifecycle, don't recreate
it when I re-render." If you used `@ObservedObject` instead, SwiftUI might recreate the
engine on every re-render, resetting the timer and all state — a common beginner mistake.

**What is `VStack`?**
`VStack` (Vertical Stack) arranges its child views top-to-bottom. `HStack` goes
left-to-right, `ZStack` stacks layers front-to-back. These three stacks are the building
blocks of almost every SwiftUI layout.

#### The TimelineBar

```swift
GeometryReader { geo in
    HStack(spacing: 0) {
        Rectangle().fill(greenGradient).frame(width: geo.size.width * seg1Fraction)
        Rectangle().fill(redGradient).frame(width: geo.size.width * seg2Fraction)
        Rectangle().fill(greenGradient).frame(width: geo.size.width * seg3Fraction)
    }
}
```

**What is `GeometryReader`?**
In SwiftUI, views don't know their own size by default (they are sized by their parent).
`GeometryReader` is a special view that receives its parent's size as `geo.size` and passes
it to its children. This is how the segments get proportional widths — each segment is
a fraction of the total bar width.

`seg1Fraction`, `seg2Fraction`, `seg3Fraction` are computed by `StatusEngine` as fractions
(0.0–1.0) based on the proportion of 24 hours each segment covers. For example, if the
block is 6 hours (8 AM – 2 PM ET), then `seg2Fraction = 6/24 = 0.25`.

#### Staggered Entrance Animation

```swift
.opacity(appeared ? 1 : 0)
.offset(y: appeared ? 0 : 8)
.animation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.05), value: appeared)
```

When `ContentView` first appears, `appeared` is `false`. In `.onAppear`, it is set to
`true`. The `.animation` modifier sees the change and smoothly animates opacity from 0→1
and vertical offset from 8→0. The `.delay(0.05)` for the first row, `.delay(0.12)` for
the second, and `.delay(0.20)` for the third creates a staggered cascade effect.

**Framework used:** `SwiftUI` entirely.

---

### 3.6 GlassContainer.swift — Visual Magic

This file creates the "glass morphism" look — a dark frosted card aesthetic.

#### Why Not Use NSVisualEffectView (Real Blur)?

macOS has a built-in blur/frosted-glass API: `NSVisualEffectView`. It sounds perfect for
a glass widget. However, it has a problem: on certain wallpapers and color schemes, the
blur shows wallpaper colors bleeding through in ugly ways. The widget would look different
on every machine.

Instead, a **fake glass** effect was constructed using 3 stacked layers:

```
Layer 1: Solid dark base (#1A1714 at 82% opacity)
         → prevents wallpaper bleed, always looks dark and readable

Layer 2: Warm orange tint (#C96442 at 4% opacity)
         → matches Claude's brand color subtly

Layer 3: Gradient highlight (white at top-left, fading out)
         → creates the "shiny glass" illusion
```

Plus:
- A gradient border (0.8pt, semi-transparent)
- Two drop shadows (large soft outer + small sharp inner)
- A noise grain overlay (tiny random dots for texture)

This combination looks like glass on *any* wallpaper on *any* machine.

#### NSViewRepresentable — Bridging AppKit into SwiftUI

```swift
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}
```

`NSViewRepresentable` is the bridge between SwiftUI and AppKit. SwiftUI doesn't have a blur
view built-in, but AppKit does (`NSVisualEffectView`). This wrapper lets you use AppKit
views inside SwiftUI's declarative tree. The `makeNSView` function creates the AppKit view
once, and `updateNSView` is called whenever SwiftUI wants to sync state changes into it.

#### The Animated Background

```swift
struct AnimatedGradientBackground: View {
    @State private var phase: Double = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/60)) { context in
            // draw two radial gradient blobs that move in sine/cosine patterns
        }
    }
}
```

**What is `TimelineView`?**
`TimelineView` is a SwiftUI view that redraws on a schedule. `.animation(minimumInterval: 1/60)`
means it redraws at up to 60 times per second (matching the display refresh rate). This is
how smooth continuous animations are made in SwiftUI — instead of a `Timer`, you use
`TimelineView` so the system can optimize battery/performance.

Inside, `sin(phase)` and `cos(phase)` make the gradient blobs move in smooth circular
patterns — sine and cosine are mathematical functions that oscillate smoothly between -1
and +1, perfect for looping motion.

#### The Color(hex:) Extension

```swift
extension Color {
    init(hex: String) { /* parses "#C96442" into RGB components */ }
}
```

Design tools (Figma, Sketch) give colors as hex codes like `#C96442`. Swift's `Color`
type doesn't accept hex strings by default. This extension adds that ability.
`Int(hex: 16)` converts a hexadecimal string to an integer, then bit-shifting (`>> 16`,
`>> 8`, `& 0xFF`) extracts the red, green, and blue components separately.

**Frameworks used:** `SwiftUI`, `AppKit` (NSViewRepresentable bridge).

---

### 3.7 ClockView.swift — The Live Clock

Displays the current India Standard Time (IST) with smooth digit transitions.

```swift
struct ClockView: View {
    @State private var time = Date()

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 2) {
            ClockSegment(value: hours)
            ClockColon()
            ClockSegment(value: minutes)
            ClockColon()
            ClockSegment(value: seconds)
        }
        .onReceive(timer) { newTime in
            time = newTime
        }
    }
}
```

**What is `Timer.publish`?**
This is a `Combine` framework timer that publishes (emits) a value every second on the main
thread. `.autoconnect()` starts it immediately. `.onReceive` is how a SwiftUI view
"subscribes" to any Combine publisher — every emission triggers the closure.

This is an alternative to `Timer.scheduledTimer` — it fits more naturally into SwiftUI's
declarative style.

#### Smooth Digit Transitions

```swift
struct ClockSegment: View {
    var value: String  // e.g., "09"
    var body: some View {
        Text(value)
            .contentTransition(.numericText())
    }
}
```

`.contentTransition(.numericText())` is a SwiftUI modifier (added in macOS 14) that
animates number changes smoothly — digits slide or fade in/out rather than snapping.
Without it, "08" → "09" would be an instant replacement. With it, the digits animate
beautifully.

**Frameworks used:** `SwiftUI`, `Combine` (Timer.publish).

---

### 3.8 DailyWindowBar.swift — The 24-Hour Bar

A 28pt-tall horizontal bar representing the full 24-hour day with colored segments.

The bar is split into three segments matching the IST schedule:
- 00:00–17:30: Active (green)
- 17:30–23:30: Blocked (red)
- 23:30–24:00: Active (green)

The widths are proportional: 17.5/24, 6/24, 0.5/24.

#### The "Now" Cursor

```swift
// Position the cursor at the current fraction of the day
let nowFraction = (elapsedSeconds / 86400.0)

Rectangle()
    .frame(width: 1.5, height: barHeight)
    .offset(x: geo.size.width * nowFraction - geo.size.width / 2)
    .shadow(color: statusColor.opacity(0.8), radius: 4)
```

`elapsedSeconds` is the number of seconds since midnight in the user's local timezone.
Dividing by 86400 (seconds in a day) gives a fraction 0.0–1.0 representing "how far
through the day are we?" Multiplying by the bar's pixel width gives the cursor's x position.

The white 1.5pt line with a colored glow shadow is the "now" cursor.

#### Dimming the Past

```swift
// Dim everything to the left of "now"
Rectangle()
    .fill(Color.black.opacity(0.28))
    .frame(width: geo.size.width * nowFraction)
```

A semi-transparent black overlay is laid over the bar from left up to the "now" cursor
position. This visually communicates "this time has passed" without changing the actual
segment colors.

**Framework used:** `SwiftUI` entirely.

---

### 3.9 CalendarStrip.swift — The 8-Day Calendar

Shows 8 days starting today as scrollable tiles.

```swift
struct CalendarStrip: View {
    let days: [CalendarDay]  // provided by StatusEngine

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(days) { day in
                    CalendarDayTile(day: day)
                }
            }
        }
    }
}
```

**What is `ForEach`?**
`ForEach` in SwiftUI is like a loop that creates views. For each element in the `days`
array, it creates one `CalendarDayTile`. The `id: \.id` parameter (or `Identifiable`
protocol) tells SwiftUI how to uniquely identify each tile so it can animate additions
and removals correctly.

**What is `ScrollView`?**
`ScrollView` makes its content scrollable. `.horizontal` makes it scroll left-right.
`showsIndicators: false` hides the scroll bar for a cleaner look.

#### The Hover Effect

```swift
.scaleEffect(isHovered ? 1.05 : 1.0)
.shadow(radius: isHovered ? 8 : 3)
.onHover { hovering in
    withAnimation(.spring(response: 0.3)) {
        isHovered = hovering
    }
}
```

`.onHover` fires when the mouse cursor enters or leaves the view. It toggles `isHovered`
(a `@State` variable), and `withAnimation` wraps the state change so SwiftUI smoothly
animates the scale and shadow changes.

**Framework used:** `SwiftUI` entirely.

---

### 3.10 StatusCard.swift — The Orb & Badge

The animated glowing orb that immediately communicates status.

#### The Pulse Rings

```swift
ForEach(0..<2) { i in
    Circle()
        .stroke(statusColor.opacity(0.3), lineWidth: 1.5)
        .scaleEffect(pulsing ? 2.2 : 1.0)
        .opacity(pulsing ? 0 : 0.8)
        .animation(
            .easeOut(duration: 1.8)
            .repeatForever(autoreverses: false)
            .delay(Double(i) * 0.6),
            value: pulsing
        )
}
```

Two concentric circles start at the orb's size (scale 1.0, opacity 0.8) and expand outward
to 2.2× while fading to invisible — this mimics a radar/sonar ping. The second ring starts
0.6 seconds behind the first. `.repeatForever(autoreverses: false)` keeps them looping
forever in the same direction (expand, jump back, expand again) without reversing.

This animation only runs when status is `.active` — on blocked/weekend, the orb is still
(`.animation(nil)`).

#### Text Gradients

```swift
Text("ACTIVE")
    .foregroundStyle(
        LinearGradient(
            colors: [Color(hex: "#4ADE80"), Color(hex: "#A3E635")],
            startPoint: .leading,
            endPoint: .trailing
        )
    )
```

`.foregroundStyle` with a `LinearGradient` fills the text with a gradient color.
`startPoint: .leading` and `endPoint: .trailing` means the gradient goes left to right.

**Framework used:** `SwiftUI` entirely.

---

### 3.11 LayoutVariants.swift — Design Exploration

This file contains 5 complete UI designs for the same widget. It exists because when
building a new product, you often don't know which visual design is best until you can
see them side by side.

The 5 layouts explored:
1. **Left Accent** — vertical colored strip on the left edge
2. **Mono Card** — glowing animated border around the whole card
3. **Two Panel** — large orb on the left, calendar list on the right
4. **Timeline Hero** — the chosen design (also in ContentView.swift)
5. **Compact Pill** — minimal, smallest footprint

A `LayoutComparisonView` at the bottom shows all 5 in a scrollable grid for easy A/B
comparison during development.

In a production codebase you might delete the unchosen layouts. Here they are kept as
documentation of the design process.

---

## 4. Key Swift Concepts Explained

### 4.1 `@State` — Local View Memory

```swift
@State private var appeared = false
```

`@State` stores a value *inside* a SwiftUI view. When it changes, SwiftUI re-renders the
view. Use `@State` for things that only one view cares about (toggle states, animation
booleans, local UI state).

### 4.2 `@Published` + `ObservableObject` — Shared Data

```swift
class StatusEngine: ObservableObject {
    @Published var currentStatus: PromotionStatus = .active
}
```

`@Published` is for values that many views share. When it changes, all observing views
re-render automatically.

### 4.3 `@StateObject` vs `@ObservedObject`

- `@StateObject` — the view **owns** the object. Swift creates it once and keeps it alive.
  Use when the view is the *creator* of the object.
- `@ObservedObject` — the view **watches** an object created elsewhere.
  Use when the object is *passed in* from a parent view.

### 4.4 Structs vs Classes

In Swift, `struct` and `class` are both ways to define types.

- **Structs** — value types (copied when passed around). SwiftUI `View` types are structs.
  Lightweight, safe. 99% of SwiftUI views are structs.
- **Classes** — reference types (shared when passed around). `StatusEngine` is a class
  because it needs to be shared across many views and mutate its own state over time.

### 4.5 Protocols — Contracts for Types

```swift
class AppDelegate: NSObject, NSApplicationDelegate { }
```

A protocol defines requirements (functions, properties) that a type must implement.
`NSApplicationDelegate` is a protocol that says "I will handle app lifecycle events."
`AppDelegate` adopts it and implements `applicationDidFinishLaunching`.

### 4.6 Optionals — Safe Nullability

```swift
var window: FloatingWindow?   // this is an Optional — can be nil
window?.makeKeyAndOrderFront(nil)  // safe unwrap with ?
```

Swift does not allow nil (null) by default. Adding `?` makes a type optional — it can
hold a value *or* be nil. `?.` is "optional chaining" — if `window` is nil, the whole
expression is skipped silently instead of crashing.

---

## 5. Key Libraries & Frameworks Explained

### SwiftUI
Apple's declarative UI framework (2019+). You describe *what* the UI should look like given
the current state, and SwiftUI figures out *how* to render and update it. Views are structs
with a `body` computed property. Used for **all visible UI** in this project.

**Why chosen:** SwiftUI is the modern standard for Apple platform UI. It handles animations,
layout, dark mode, accessibility automatically. Writing the same UI in AppKit (the older
framework) would require 3–5× more code.

### AppKit
Apple's older macOS UI framework (1988+). Written in Objective-C, wrapped in Swift.
Used in this project specifically for:
- `NSWindow` — custom floating window below all apps
- `NSEvent` — raw mouse events for drag handling
- `NSApp` — app-level control (activation policy, quit)
- `NSVisualEffectView` — blur effects (prepared but not used in final design)

**Why chosen:** SwiftUI's `WindowGroup` (the normal window) cannot be positioned at
`kCGNormalWindowLevel - 1` or made borderless without a title bar. AppKit gives the
raw control needed for the desktop widget behavior.

### Foundation
Apple's base-layer framework. Not a UI framework — it provides:
- `Date`, `Calendar`, `TimeZone` — date and time computation
- `Timer` — repeating actions
- `URLSession` — network requests
- `UserDefaults` — key-value persistent storage
- `String`, `Array`, `Dictionary` — standard data types

**Why chosen:** It's the unavoidable foundation (hence the name) of every Swift app.
You cannot write real software on Apple platforms without it.

### Combine
Apple's reactive programming framework. Provides:
- `ObservableObject` / `@Published` — reactive data binding
- `Timer.publish` — combine-native timer
- `sink`, `assign`, `map` — data pipeline operators

**Why chosen:** SwiftUI is deeply integrated with Combine. The `@Published` + `ObservableObject`
pattern is the standard way to share data between a data-model class and multiple SwiftUI
views.

---

## 6. How State Flows Through the App

Understanding data flow is the key to understanding any SwiftUI app.

```
StatusEngine (class, @MainActor)
│
│  @Published properties:
│  ├── currentStatus      → drives StatusRow dot color, TimelineBar colors
│  ├── nextWindowText     → drives StatusRow countdown label
│  ├── currentTime        → drives ClockView
│  ├── calendarDays       → drives CalendarDotsRow tiles
│  ├── seg1/2/3Fraction   → drives TimelineBar segment widths
│  └── localBlockStart/EndLabel → drives TimelineBar axis labels
│
├── ContentView (@StateObject engine) — owns the engine
│   ├── StatusRow(engine: engine)
│   ├── TimelineBar(engine: engine)
│   └── CalendarDotsRow(engine: engine)
│
└── Timer (every 1 second)
    └── updateAll()
        ├── currentStatus = computeStatus(now)
        ├── nextWindowText = computeNextWindow(now)
        └── ... all @Published properties updated
```

Every second: timer fires → engine recomputes → `@Published` properties change →
SwiftUI re-renders only the affected views → user sees updated countdown, cursor position, etc.

---

## 7. Animations: How They Work

SwiftUI has two kinds of animations:

### Implicit Animations (`.animation` modifier)
```swift
Circle()
    .scaleEffect(pulsing ? 2.2 : 1.0)
    .animation(.easeOut(duration: 1.8).repeatForever(), value: pulsing)
```
When `pulsing` changes, the scale animates automatically. SwiftUI interpolates between
old and new values over the animation duration.

### Explicit Animations (`withAnimation`)
```swift
withAnimation(.spring(response: 0.3)) {
    isHovered = true
}
```
Wrapping a state change in `withAnimation` tells SwiftUI to animate all changes caused
by that state mutation.

### Animation Types Used

| Type | Behavior | Used For |
|------|----------|----------|
| `.spring(response:dampingFraction:)` | Natural bounce | Entrance animations, hover effects |
| `.easeOut(duration:)` | Fast start, slow end | Pulse rings expanding |
| `.linear(duration:)` | Constant speed | Now cursor movement |
| `.repeatForever(autoreverses:)` | Loops indefinitely | Pulse rings, breathing glow |

**Spring animation parameters:**
- `response`: how quickly it reaches the target (lower = faster)
- `dampingFraction`: how much it bounces (1.0 = no bounce, 0.5 = springy)

---

## 8. The Timezone Problem

This widget has a subtle challenge: the 2× schedule is defined in ET (Eastern Time, US),
but users are all over the world. A user in India (IST, UTC+5:30) sees completely different
local times for the same window.

**The solution has two parts:**

#### Part 1: Status Computation in ET
```swift
var etCalendar = Calendar.current
etCalendar.timeZone = TimeZone(identifier: "America/New_York")!

let etHour = etCalendar.component(.hour, from: now)
let etMinute = etCalendar.component(.minute, from: now)

// Peak hours: 8:00 AM – 14:00 (2 PM) in ET
let isPeakTime = (etHour > 8 || (etHour == 8 && etMinute >= 0))
             && (etHour < 14)
```
Status is always computed in ET, regardless of where the user is.

#### Part 2: Display in Local Time
The ET peak window (8 AM – 2 PM ET) is converted to local time for labels:
- IST: 6:30 PM – 11:30 PM
- PST: 5:00 AM – 11:00 AM
- CET: 2:00 PM – 8:00 PM

`Foundation`'s `Calendar` handles Daylight Saving Time automatically. If the US clocks
shift, the conversion automatically accounts for it — no manual DST handling needed.

**The elegant part:** `Date` objects in Swift are always UTC internally. Timezone is only
applied when *displaying* or *comparing* date components. This means all the hard timezone
math is just a one-line `etCalendar.timeZone = ...` change.

---

## 9. Design Decisions — Why Each Thing Was Done

### Why no menu bar icon?
`.accessory` activation policy + `LSUIElement = true` in Info.plist together make the app
completely invisible to the system UI (no Dock badge, no menu bar, no app switcher).
This is intentional — it behaves like a desktop decoration, not an "app" you switch to.

### Why fake glass instead of real NSVisualEffectView blur?
Real blur adapts to the wallpaper — on a bright wallpaper the card looks light, on a dark
wallpaper it looks dark. This inconsistency makes text hard to read. The 3-layer fake glass
is always dark and always readable, trading adaptability for reliability.

### Why fixed height (148pt)?
The widget's content doesn't change in quantity — it always shows one status row, one bar,
and 8 calendar days. Fixed height prevents layout shifts and makes position memory reliable.

### Why store position in UserDefaults instead of a file?
UserDefaults is designed for small preference data exactly like window positions. A file
would work but requires manual file path management, error handling, and permissions.
UserDefaults handles all that transparently.

### Why fetch schedule.json from GitHub?
Hard-coding the peak hours (8 AM – 2 PM ET) in the app means a schedule change requires
rebuilding and redistributing the app. By fetching from GitHub, the schedule can be updated
in seconds without any user action. The 6-hour cache interval balances freshness against
battery/network usage.

### Why 5 layout variants?
UI design decisions are easier to make by comparison than by imagination. Instead of
picking one design and hoping it looks good, all 5 were built simultaneously and evaluated
side by side in `LayoutComparisonView`. This is a common professional practice called
"design sprinting."

### Why `kCGNormalWindowLevel - 1` instead of desktop level?
The true desktop level (`kCGDesktopWindowLevel`) would place the widget *below* Finder
windows but visible on empty desktop. However, on macOS with "Show Desktop" (hot corner),
windows below `kCGNormalWindowLevel` are revealed — the widget would be covered when apps
are open but visible on the clean desktop. Level `normalWindow - 1` was chosen as the
sweet spot: always visible but never in the way.

---

## 10. Architecture Summary

```
Claude2xWidget/
│
├── Entry & Lifecycle (AppKit + SwiftUI bridge)
│   ├── Claude2xWidgetApp.swift    @main, installs AppDelegate
│   ├── AppDelegate.swift          Creates FloatingWindow on launch
│   └── FloatingWindow.swift       Custom NSWindow: transparent, draggable, persistent
│
├── Data & Logic (Foundation + Combine)
│   └── StatusEngine.swift         ObservableObject: timers, timezone math, remote config
│
├── UI: Main Layout (SwiftUI)
│   └── ContentView.swift          VStack: StatusRow + TimelineBar + CalendarDotsRow
│
├── UI: Reusable View Components (SwiftUI)
│   ├── GlassContainer.swift       Fake glass card, animated background, noise grain
│   ├── ClockView.swift            IST clock with smooth digit transitions
│   ├── DailyWindowBar.swift       24-hour bar with now cursor and past dimming
│   ├── CalendarStrip.swift        8-day scrollable calendar tiles
│   └── StatusCard.swift           Pulsing orb + status badge + countdown
│
└── Design Exploration (SwiftUI)
    └── LayoutVariants.swift       5 layout candidates for A/B comparison
```

### The Three-Layer Architecture

```
Layer 1: Platform (AppKit)
  → Controls how the window exists in macOS
  → NSWindow level, transparency, drag, position memory

Layer 2: Data (Foundation + Combine)
  → StatusEngine computes what is true right now
  → Published properties push changes upward

Layer 3: UI (SwiftUI)
  → Views read from StatusEngine and render
  → Views never write back to StatusEngine (one-way data flow)
  → Animations are driven by state changes, not imperative commands
```

This clean separation means:
- You can test StatusEngine without any UI (it has no SwiftUI imports)
- You can redesign any view without touching StatusEngine
- Adding a new view is just adding another `@ObservedObject var engine: StatusEngine`

---

*This document was written specifically for someone learning Swift through this project.
Every file, every pattern, every framework choice has a concrete reason — now you know them all.*
