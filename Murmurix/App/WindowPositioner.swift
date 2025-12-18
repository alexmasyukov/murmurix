//
//  WindowPositioner.swift
//  Murmurix
//

import Cocoa

/// Utility for consistent window positioning across the app
enum WindowPositioner {
    /// Position window at top center of screen with optional offset from top
    static func positionTopCenter(_ window: NSWindow, topOffset: CGFloat = 10) {
        guard let screen = NSScreen.main else { return }

        window.layoutIfNeeded()

        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame

        let x = screenFrame.midX - windowFrame.width / 2
        let y = screenFrame.maxY - windowFrame.height - topOffset

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// Center window on screen
    static func center(_ window: NSWindow) {
        window.center()
    }

    /// Position window at center and activate app
    static func centerAndActivate(_ window: NSWindow) {
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
