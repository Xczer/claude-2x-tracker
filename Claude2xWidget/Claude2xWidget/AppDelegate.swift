// AppDelegate.swift

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    var window: FloatingWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // no dock icon, no menu bar icon
        let w = FloatingWindow(contentView: ContentView())
        w.orderFrontRegardless()
        window = w
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
