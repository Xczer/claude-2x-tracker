// FloatingWindow.swift
// Desktop widget window: sits behind all normal app windows, fully draggable.

import AppKit
import SwiftUI

final class FloatingWindow: NSWindow, NSWindowDelegate {

    init(contentView: some View) {
        let size = NSSize(width: 340, height: 185)
        let rect = Self.restoredFrame(defaultSize: size)

        super.init(
            contentRect: rect,
            styleMask: [.borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // ── Appearance ──────────────────────────────────────────────
        isOpaque        = false
        backgroundColor = .clear
        hasShadow       = true

        // Level explanation:
        //   kCGNormalWindowLevel (0)  → all normal app windows
        //   -1                        → OUR widget (below every app, above Finder's desktop)
        //   kCGDesktopWindowLevel     → wallpaper / Finder desktop background
        //
        // At level -1 the widget:
        //   • Is covered by every open app window              ✓
        //   • Receives mouse events reliably (Finder doesn't intercept) ✓
        //   • Is visible whenever no app windows overlap it    ✓
        //
        // NOTE: true "Show Desktop" reveal (level = desktopWindow+1) sounds nice but
        // Finder intercepts ALL clicks at that layer, making drag impossible without
        // Accessibility permissions. Level -1 is the practical sweet spot.
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.normalWindow)) - 1)

        // Stay on every Space, don't show in Mission Control, skip Cmd+Tab
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        // AppKit-native drag: any click-drag on non-control areas moves the window.
        isMovableByWindowBackground = true

        // ── Content ─────────────────────────────────────────────────
        // WidgetHostingView overrides acceptsFirstMouse so the first click
        // immediately starts a drag without needing a prior "activation" click.
        let host = WidgetHostingView(rootView: contentView)
        host.wantsLayer       = true
        host.layer?.cornerRadius  = 22
        host.layer?.masksToBounds = true
        self.contentView = host

        minSize = NSSize(width: 280, height: 160)
        maxSize = NSSize(width: 500, height: 320)

        delegate = self
    }

    // REQUIRED: must be true so the window receives mouse events.
    // false = Finder intercepts the click; drag never starts.
    override var canBecomeKey:  Bool { true  }
    override var canBecomeMain: Bool { false }

    // MARK: - Manual drag fallback
    // isMovableByWindowBackground handles most cases; this catches the rest
    // (e.g. clicks that land on a SwiftUI view that absorbs the event).

    private var dragStartMouse:  NSPoint = .zero
    private var dragStartOrigin: NSPoint = .zero
    private var isDragging = false

    override func mouseDown(with event: NSEvent) {
        dragStartMouse  = NSEvent.mouseLocation
        dragStartOrigin = frame.origin
        isDragging      = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let now = NSEvent.mouseLocation
        let dx  = now.x - dragStartMouse.x
        let dy  = now.y - dragStartMouse.y
        setFrameOrigin(NSPoint(x: dragStartOrigin.x + dx, y: dragStartOrigin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false
        applySnapAndSave()
    }

    // MARK: - NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        applySnapAndSave()
    }

    func windowDidResize(_ notification: Notification) {
        contentView?.layer?.cornerRadius = 22
        saveFrame()
    }

    // MARK: - Snap to screen edges (14 pt threshold)

    private func applySnapAndSave() {
        guard let screen = screen else { saveFrame(); return }
        let snapped = snapToEdges(origin: frame.origin, screen: screen)
        if snapped != frame.origin { setFrameOrigin(snapped) }
        saveFrame()
    }

    private func snapToEdges(origin: CGPoint, screen: NSScreen) -> CGPoint {
        let snap = CGFloat(14)
        let sv   = screen.visibleFrame
        var x    = origin.x
        var y    = origin.y
        if abs(x - sv.minX)               < snap { x = sv.minX }
        if abs(x + frame.width - sv.maxX) < snap { x = sv.maxX - frame.width }
        if abs(y + frame.height - sv.maxY) < snap { y = sv.maxY - frame.height }
        if abs(y - sv.minY)               < snap { y = sv.minY }
        return CGPoint(x: x, y: y)
    }

    // MARK: - Position persistence

    private static let frameKey = "claude2x.window.frame"

    private static func restoredFrame(defaultSize: NSSize) -> NSRect {
        if let saved = UserDefaults.standard.string(forKey: frameKey) {
            let r = NSRectFromString(saved)
            if r.width > 0 { return r }
        }
        // Default: top-right, 20 pt inset
        let sv = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSRect(x: sv.maxX - defaultSize.width - 20,
                      y: sv.maxY - defaultSize.height - 20,
                      width: defaultSize.width, height: defaultSize.height)
    }

    private func saveFrame() {
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: Self.frameKey)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
        contentView?.layer?.cornerRadius = 22
    }
}

// MARK: - Custom hosting view

/// Subclass of NSHostingView that accepts the first mouse-down immediately,
/// so click-to-drag works without a prior "activation" click on the widget.
private final class WidgetHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
