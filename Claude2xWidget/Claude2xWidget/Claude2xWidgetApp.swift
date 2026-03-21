// Claude2xWidgetApp.swift
// App entry point — uses AppDelegate for NSWindow management

import SwiftUI

@main
struct Claude2xWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // We manage windows manually via AppDelegate + FloatingWindow
        // This empty Settings scene satisfies the @main requirement
        Settings {
            EmptyView()
        }
    }
}
